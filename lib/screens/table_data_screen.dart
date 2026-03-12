import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/connection_info.dart';
import '../services/api_service.dart';

// [1] 마우스 및 터치 스크롤 지원을 위한 설정
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class TableDataScreen extends StatefulWidget {
  final ConnectionInfo info;
  final String database;
  final String tableName;
  final List<dynamic>? initialRows;
  final List<String>? initialColumns;
  // [추가] 외부에서 계산된 실행 시간을 받기 위한 변수
  final String? executionTime;

  const TableDataScreen({
    super.key,
    required this.info,
    required this.database,
    required this.tableName,
    this.initialRows,
    this.initialColumns,
    this.executionTime, // 파라미터 추가
  });

  @override
  State<TableDataScreen> createState() => _TableDataScreenState();
}

class _TableDataScreenState extends State<TableDataScreen> {
  late TextEditingController _queryController;
  late TextEditingController _filterController;
  List<String> _columns = [];
  List<dynamic> _allRows = [];
  List<dynamic> _filteredRows = [];
  bool _isLoading = false;

  // 상태 관리 변수
  bool _isQueryVisible = false; // 쿼리창 토글
  bool _isSearchVisible = false; // 검색창 토글
  String _executionTime = "0.00s";
  _RowSource? _rowSource;

  @override
  void initState() {
    super.initState();

    // 컨트롤러 먼저 초기화
    _queryController = TextEditingController(
        text: widget.info.port == 1433 || widget.info.port == "1433"
            ? "SELECT TOP 1000 * FROM ${widget.tableName}"
            : "SELECT * FROM ${widget.tableName} LIMIT 1000"
    );
    _filterController = TextEditingController();

    // [수정] 전달받은 데이터가 있는 경우 처리 로직 개선
    if (widget.initialRows != null && widget.initialColumns != null) {
      _columns = widget.initialColumns!;
      _allRows = widget.initialRows!;
      _filteredRows = _allRows;
      _rowSource = _RowSource(_filteredRows, _columns);

      // [수정] 대시보드에서 전달받은 실행 시간이 있으면 사용, 없으면 "0.00s"
      _executionTime = widget.executionTime ?? "0.00s";
    } else {
      // 테이블 클릭으로 들어온 경우에만 자동으로 첫 쿼리 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runQuery();
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  // 쿼리 템플릿 숏컷 기능
  void _setQueryTemplate(String type) {
    String query = "";
    final table = widget.tableName;
    bool isMSSQL = widget.info.port == 1433 || widget.info.port == "1433";

    switch (type) {
      case 'SELECT':
        query = isMSSQL ? "SELECT TOP 1000 * FROM $table" : "SELECT * FROM $table LIMIT 1000";
        break;
      case 'UPDATE':
        String col = _columns.isNotEmpty ? _columns[0] : "column1";
        query = "UPDATE $table SET $col = '' WHERE id = ''";
        break;
      case 'DELETE':
        query = "DELETE FROM $table WHERE id = ''";
        break;
      case 'INSERT':
        String cols = _columns.join(", ");
        query = "INSERT INTO $table ($cols)\nVALUES ()";
        break;
      case 'COUNT':
        query = "SELECT COUNT(*) FROM $table";
        break;
    }

    setState(() {
      _queryController.text = query;
      _isQueryVisible = true;
    });
  }

  // [중요] 직접 쿼리를 실행할 때 소요 시간 계산 로직
  Future<void> _runQuery() async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start(); // 시간 측정 시작

    final result = await ApiService.executeQuery(
        widget.info,
        widget.database,
        _queryController.text
    );

    stopwatch.stop(); // 시간 측정 중지

    if (result['success'] == true) {
      setState(() {
        _columns = List<String>.from(result['columns'] ?? []);
        _allRows = result['rows'] ?? [];
        _filteredRows = _allRows;
        _filterController.clear();
        _rowSource = _RowSource(_filteredRows, _columns);

        // [수정] 밀리초를 초 단위로 변환하여 저장
        double seconds = stopwatch.elapsedMilliseconds / 1000.0;
        _executionTime = "${seconds.toStringAsFixed(2)}s";
      });
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? "조회 실패"), backgroundColor: Colors.red)
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _filterData(String text) {
    setState(() {
      if (text.isEmpty) {
        _filteredRows = _allRows;
      } else {
        _filteredRows = _allRows.where((row) {
          return row.values.any((value) {
            if (value == null) return false;
            return value.toString().toLowerCase().contains(text.toLowerCase());
          });
        }).toList();
      }
      _rowSource = _RowSource(_filteredRows, _columns);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF87588E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tableName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              "${_filteredRows.length} rows ($_executionTime)",
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (_isSearchVisible) _isQueryVisible = false;
              });
            },
          ),
          IconButton(
            icon: Icon(_isQueryVisible ? Icons.keyboard_arrow_up : Icons.code),
            onPressed: () {
              setState(() {
                _isQueryVisible = !_isQueryVisible;
                if (_isQueryVisible) _isSearchVisible = false;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedVisibility(
            visible: _isQueryVisible,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _queryShortcutButton("SELECT", Colors.blue),
                        _queryShortcutButton("UPDATE", Colors.orange),
                        _queryShortcutButton("DELETE", Colors.red),
                        _queryShortcutButton("INSERT", Colors.green),
                        _queryShortcutButton("COUNT", Colors.purple),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _queryController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                        labelText: "SQL Editor",
                        alignLabelWithHint: true
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => _queryController.clear(), child: const Text("CLEAR")),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _isLoading ? null : _runQuery,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF87588E), foregroundColor: Colors.white),
                          child: const Text("RUN QUERY")
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          AnimatedVisibility(
            visible: _isSearchVisible,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.blueGrey[50],
              child: TextField(
                controller: _filterController,
                onChanged: _filterData,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search in results...",
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _filterController.clear();
                      _filterData("");
                    },
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_columns.isEmpty || _rowSource == null)
                ? const Center(child: Text("No data found."))
                : ScrollConfiguration(
              behavior: MyCustomScrollBehavior(),
              child: SingleChildScrollView(
                child: PaginatedDataTable(
                  rowsPerPage: _filteredRows.length < 10 ? (_filteredRows.isEmpty ? 1 : _filteredRows.length) : 10,
                  availableRowsPerPage: const [10, 20, 50, 100],
                  columns: _columns
                      .map((col) => DataColumn(label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))))
                      .toList(),
                  source: _rowSource!,
                  columnSpacing: 20,
                  horizontalMargin: 10,
                  showCheckboxColumn: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _queryShortcutButton(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: color.withOpacity(0.8),
        onPressed: () => _setQueryTemplate(label),
      ),
    );
  }
}

class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;
  const AnimatedVisibility({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: child,
      crossFadeState: visible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 250),
    );
  }
}

class _RowSource extends DataTableSource {
  final List<dynamic> rows;
  final List<String> columns;
  _RowSource(this.rows, this.columns);

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final row = rows[index];
    return DataRow(
      cells: columns.map((col) => DataCell(
          Text(row[col]?.toString() ?? "NULL", style: const TextStyle(fontSize: 12))
      )).toList(),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => rows.length;
  @override
  int get selectedRowCount => 0;
}