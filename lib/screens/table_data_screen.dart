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

  const TableDataScreen({
    super.key,
    required this.info,
    required this.database,
    required this.tableName
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
    // [대괄호 제거] 기본 쿼리 설정
    _queryController = TextEditingController(
        text: "SELECT TOP 1000 * FROM ${widget.tableName}"
    );
    _filterController = TextEditingController();
    _runQuery();
  }

  // 쿼리 템플릿 숏컷 기능
  void _setQueryTemplate(String type) {
    String query = "";
    final table = widget.tableName;

    switch (type) {
      case 'SELECT':
        query = "SELECT TOP 1000 * FROM $table";
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

  Future<void> _runQuery() async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();

    final result = await ApiService.executeQuery(
        widget.info,
        widget.database,
        _queryController.text
    );

    stopwatch.stop();

    if (result['success'] == true) {
      setState(() {
        _columns = List<String>.from(result['columns'] ?? []);
        _allRows = result['rows'] ?? [];
        _filteredRows = _allRows;
        _filterController.clear();
        _rowSource = _RowSource(_filteredRows, _columns);

        // 실행 시간 초(s) 단위 계산
        double seconds = stopwatch.elapsedMilliseconds / 1000.0;
        _executionTime = "${seconds.toStringAsFixed(2)}s";
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "조회 실패"))
      );
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
        backgroundColor: const Color(0xFF34495E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tableName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              "${_filteredRows.length} rows ($_executionTime)",
              style: const TextStyle(fontSize: 12, color: Colors.white70),
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
          // [2] 쿼리 에디터 영역 (템플릿 버튼 포함)
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
                    maxLines: 5,
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                        labelText: "SQL Editor"
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => _queryController.clear(), child: const Text("CLEAR")),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _runQuery,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF34495E), foregroundColor: Colors.white),
                          child: const Text("RUN QUERY")
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // [3] 검색창 영역
          AnimatedVisibility(
            visible: _isSearchVisible,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.blueGrey[50],
              child: TextField(
                controller: _filterController,
                autofocus: true,
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

          // [4] 데이터 결과 테이블
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_columns.isEmpty || _rowSource == null)
                ? const Center(child: Text("No data found."))
                : ScrollConfiguration(
              behavior: MyCustomScrollBehavior(),
              child: SingleChildScrollView(
                child: PaginatedDataTable(
                  header: null, // 테이블 타이틀 삭제하여 공간 확보
                  rowsPerPage: 10,
                  availableRowsPerPage: const [10, 20, 50, 100],
                  columns: _columns
                      .map((col) => DataColumn(label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold))))
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

  // 숏컷 버튼 위젯 빌더
  Widget _queryShortcutButton(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: color.withOpacity(0.8),
        onPressed: () => _setQueryTemplate(label),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

// 애니메이션 헬퍼 위젯
class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;
  const AnimatedVisibility({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: Container(),
      secondChild: child,
      crossFadeState: visible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 250),
    );
  }
}

// 데이터 소스 클래스
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