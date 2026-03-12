import 'package:flutter/material.dart';
import '../models/connection_info.dart';
import '../services/api_service.dart';
import 'table_data_screen.dart';
import 'tabs/db_objects_tab.dart'; // 분리한 파일 임포트
import 'tabs/query_editor_tab.dart'; // 분리한 파일 임포트

class DatabaseDashboardScreen extends StatefulWidget {
  final ConnectionInfo connectionInfo;
  const DatabaseDashboardScreen({super.key, required this.connectionInfo});

  @override
  State<DatabaseDashboardScreen> createState() => _DatabaseDashboardScreenState();
}

class _DatabaseDashboardScreenState extends State<DatabaseDashboardScreen> with SingleTickerProviderStateMixin {
  // 공통 및 상태 변수들은 기존과 동일하게 유지
  bool _isLoading = true;
  late String _currentDbName;
  late TabController _tabController;
  Map<String, dynamic> _dbStats = {'databases': {'count': 0, 'items': []}, 'tables': {'count': 0, 'items': []}};

  bool _isListSearchVisible = false;
  final TextEditingController _listFilterController = TextEditingController();
  String _listSearchTerm = "";

  late TextEditingController _tabQueryController;
  final TextEditingController _tabSearchController = TextEditingController();
  bool _isTabQueryVisible = true;
  bool _isTabSearchVisible = false;
  String _tabSearchTerm = "";

  String _tabExecutionTime = "0.00s";
  int _tabRowCount = 0;
  List<dynamic> _queryHistoryRows = [];
  bool _isHistoryLoading = false;

  bool get _isMSSQL => widget.connectionInfo.port == 1433 || widget.connectionInfo.port == "1433";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _loadQueryHistory();
      setState(() {});
    });
    _currentDbName = widget.connectionInfo.dbName;
    _tabQueryController = TextEditingController(text: _isMSSQL ? "SELECT TOP 100 * FROM " : "SELECT * FROM  LIMIT 100");
    _loadDatabaseInfo();
    _loadQueryHistory();
  }

  // 로직 함수들 (_handleDatabaseChange, _loadDatabaseInfo, _runTabQuery 등) 기존 코드 유지
  // ... (생략된 로직 함수들은 기존과 동일하게 작성) ...

  Future<void> _loadQueryHistory() async {
    setState(() => _isHistoryLoading = true);
    final result = await ApiService.fetchQueryHistory(widget.connectionInfo, _currentDbName);
    if (result['success'] == true) setState(() => _queryHistoryRows = result['rows'] ?? []);
    setState(() => _isHistoryLoading = false);
  }

  Future<void> _loadDatabaseInfo() async {
    setState(() => _isLoading = true);
    final result = await ApiService.fetchDatabaseInfo(widget.connectionInfo, _currentDbName);
    if (result['success'] == true) setState(() => _dbStats = result['data']);
    setState(() => _isLoading = false);
  }

  Future<void> _runTabQuery() async {
    final sql = _tabQueryController.text.trim();
    if (sql.isEmpty) return;
    setState(() => _isHistoryLoading = true);
    final stopwatch = Stopwatch()..start();
    try {
      final result = await ApiService.executeQuery(widget.connectionInfo, _currentDbName, sql);
      stopwatch.stop();
      if (result['success'] == true) {
        await ApiService.saveQueryHistory(widget.connectionInfo, _currentDbName, sql);
        _loadQueryHistory();
        setState(() {
          _tabRowCount = (result['rows'] as List).length;
          _tabExecutionTime = "${(stopwatch.elapsedMilliseconds / 1000.0).toStringAsFixed(2)}s";
        });
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => TableDataScreen(info: widget.connectionInfo, database: _currentDbName, tableName: "Query Result", initialRows: result['rows'], initialColumns: List<String>.from(result['columns'] ?? []), executionTime: _tabExecutionTime)));
      } else {
        _showErrorDialog(result['message'] ?? "실패");
      }
    } finally {
      setState(() => _isHistoryLoading = false);
    }
  }

  void _showErrorDialog(String m) { /* 기존과 동일 */ }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF87588E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.connectionInfo.ip, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_tabController.index == 0 ? "$_currentDbName.dbo" : "$_currentDbName.dbo - $_tabRowCount rows ($_tabExecutionTime)", style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
        actions: [
          if (_tabController.index == 0) IconButton(icon: Icon(_isListSearchVisible ? Icons.search_off : Icons.search), onPressed: () => setState(() => _isListSearchVisible = !_isListSearchVisible)),
          if (_tabController.index == 1) ...[
            IconButton(icon: Icon(_isTabSearchVisible ? Icons.search_off : Icons.search), onPressed: () => setState(() { _isTabSearchVisible = !_isTabSearchVisible; if (_isTabSearchVisible) _isTabQueryVisible = false; })),
            IconButton(icon: Icon(_isTabQueryVisible ? Icons.keyboard_arrow_up : Icons.code), onPressed: () => setState(() => _isTabQueryVisible = !_isTabQueryVisible)),
          ]
        ],
        bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,       // 현재 선택된 탭 아래의 바(선) 색상
            indicatorWeight: 3.0,              // 하단 바의 두께
            labelColor: Colors.white,          // 선택된 탭의 아이콘 및 글자 색상
            unselectedLabelColor: Colors.white.withOpacity(0.5), // 선택되지 않은 탭의 아이콘 색상 (반투명 흰색)
            tabs: const [
              Tab(icon: Icon(Icons.table_view, color: Colors.white)),       // 아이콘 색상을 직접 흰색으로 지정
              Tab(icon: Icon(Icons.manage_search, color: Colors.white))     // 아이콘 색상을 직접 흰색으로 지정
            ]
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 탭 1 위젯 호출
          Column(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 250), height: _isListSearchVisible ? 60 : 0, child: SingleChildScrollView(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.blueGrey[50], child: TextField(controller: _listFilterController, onChanged: (v) => setState(() => _listSearchTerm = v), decoration: InputDecoration(hintText: "Search...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))))),
            Expanded(
              child: DbObjectsTab(
                isLoading: _isLoading,
                dbStats: _dbStats,
                currentDbName: _currentDbName,
                filter: _listSearchTerm,
                connectionInfo: widget.connectionInfo,
                onDatabaseChange: (n) => setState(() { _currentDbName = n; _loadDatabaseInfo(); }),
                onRefresh: _loadDatabaseInfo,
              ),
            ),
          ]),

          // 탭 2 위젯 호출
          Column(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 250), height: _isTabSearchVisible ? 60 : 0, child: SingleChildScrollView(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.blueGrey[50], child: TextField(controller: _tabSearchController, onChanged: (v) => setState(() => _tabSearchTerm = v), decoration: InputDecoration(hintText: "Search in history...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))))),
            Expanded(
              child: QueryEditorTab(
                queryController: _tabQueryController,
                isQueryVisible: _isTabQueryVisible,
                isHistoryLoading: _isHistoryLoading,
                queryHistory: _queryHistoryRows,
                searchTerm: _tabSearchTerm,
                onRunQuery: _runTabQuery,
                shortcutBuilder: _shortcutChip,
                historyCardBuilder: _buildHistoryCard,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // 숏컷과 히스토리 카드는 메인에서 위젯 빌더 형태로 넘겨줌
  Widget _shortcutChip(String label, Color color) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: color,
      onPressed: () {
        setState(() {
          if (label == 'SELECT') _tabQueryController.text = _isMSSQL ? "SELECT TOP 100 * FROM " : "SELECT * FROM LIMIT 100";
          else _tabQueryController.text = "$label ";
          _isTabQueryVisible = true;
        });
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    return ListTile(
      title: Text(item['query_text'], maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(item['execution_date']),
      onTap: () => setState(() { _tabQueryController.text = item['query_text']; _isTabQueryVisible = true; }),
    );
  }
}