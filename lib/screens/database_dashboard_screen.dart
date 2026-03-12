import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/connection_info.dart';
import '../services/api_service.dart';
import 'table_data_screen.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class DatabaseDashboardScreen extends StatefulWidget {
  final ConnectionInfo connectionInfo;
  const DatabaseDashboardScreen({super.key, required this.connectionInfo});

  @override
  State<DatabaseDashboardScreen> createState() => _DatabaseDashboardScreenState();
}

class _DatabaseDashboardScreenState extends State<DatabaseDashboardScreen> with SingleTickerProviderStateMixin {
  // --- 공통 상태 ---
  bool _isLoading = true;
  String _errorMessage = '';
  late String _currentDbName;
  late TabController _tabController;

  Map<String, dynamic> _dbStats = {'databases': {'count': 0, 'items': []}, 'tables': {'count': 0, 'items': []}};

  // --- [탭 1] 상태 ---
  bool _isListSearchVisible = false;
  final TextEditingController _listFilterController = TextEditingController();
  String _listSearchTerm = "";

  // --- [탭 2] 상태 ---
  late TextEditingController _tabQueryController;
  final TextEditingController _tabSearchController = TextEditingController();
  bool _isTabQueryVisible = true;
  bool _isTabSearchVisible = false; // [수정 2] 돋보기 아이콘을 통해 제어될 검색바 상태
  String _tabSearchTerm = "";

  String _tabExecutionTime = "0.00s"; // [수정 1] 걸린 시간
  int _tabRowCount = 0; // [수정 1] 데이터 개수
  List<dynamic> _queryHistoryRows = [];
  bool _isHistoryLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _loadQueryHistory();
      setState(() {});
    });

    _currentDbName = widget.connectionInfo.dbName;
    _tabQueryController = TextEditingController(text: "SELECT TOP 100 * FROM ");
    _loadDatabaseInfo();
    _loadQueryHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _listFilterController.dispose();
    _tabQueryController.dispose();
    _tabSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadQueryHistory() async {
    setState(() => _isHistoryLoading = true);
    final result = await ApiService.fetchQueryHistory(widget.connectionInfo, _currentDbName);
    if (result['success'] == true) {
      setState(() {
        _queryHistoryRows = result['rows'] ?? [];
      });
    }
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

    final result = await ApiService.executeQuery(widget.connectionInfo, _currentDbName, sql);
    stopwatch.stop();

    if (result['success'] == true) {
      await ApiService.saveQueryHistory(widget.connectionInfo, _currentDbName, sql);
      _loadQueryHistory();

      // [수정 1] 데이터 개수 및 시간 업데이트
      setState(() {
        final List<dynamic> rows = result['rows'] ?? [];
        _tabRowCount = rows.length;
        _tabExecutionTime = "${(stopwatch.elapsedMilliseconds / 1000.0).toStringAsFixed(2)}s";
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? "Error")));
    }
    setState(() => _isHistoryLoading = false);
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
            Text(widget.connectionInfo.ip, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            // [수정 1] History List 텍스트 대신 데이터 개수와 시간 표시
            Text(
                _tabController.index == 1
                    ? "$_tabRowCount rows ($_tabExecutionTime)"
                    : '$_currentDbName - dbo',
                style: TextStyle(fontSize: 14, color: Colors.grey[400])
            ),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(icon: Icon(_isListSearchVisible ? Icons.search_off : Icons.search), onPressed: () => setState(() => _isListSearchVisible = !_isListSearchVisible)),
          if (_tabController.index == 1) ...[
            // [수정 2] 돋보기 아이콘 복구
            IconButton(
                icon: Icon(_isTabSearchVisible ? Icons.search_off : Icons.search),
                onPressed: () => setState(() {
                  _isTabSearchVisible = !_isTabSearchVisible;
                  if (_isTabSearchVisible) _isTabQueryVisible = false;
                })
            ),
            IconButton(icon: Icon(_isTabQueryVisible ? Icons.keyboard_arrow_up : Icons.code), onPressed: () => setState(() => _isTabQueryVisible = !_isTabQueryVisible)),
          ]
        ],
        bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3.0,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.5),
            tabs: const [Tab(icon: Icon(Icons.table_view)), Tab(icon: Icon(Icons.manage_search))]
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 탭 1: 목록 (기존 디자인 유지)
          _isLoading ? const Center(child: CircularProgressIndicator()) : Column(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 250), height: _isListSearchVisible ? 60 : 0, child: SingleChildScrollView(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.blueGrey[50], child: TextField(controller: _listFilterController, onChanged: (v) => setState(() => _listSearchTerm = v), decoration: InputDecoration(hintText: "Search...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))))),
            Expanded(child: RefreshIndicator(onRefresh: _loadDatabaseInfo, child: ListView(padding: const EdgeInsets.all(12.0), children: [_buildExpandableCard(Icons.storage, 'Databases', _dbStats['databases'], highlightItem: _currentDbName, filter: _listSearchTerm, onItemTap: (n) { if (_currentDbName != n) { setState(() => _currentDbName = n); _loadDatabaseInfo(); } }), _buildExpandableCard(Icons.table_chart_outlined, 'Tables', _dbStats['tables'], filter: _listSearchTerm, onItemTap: (n) { Navigator.push(context, MaterialPageRoute(builder: (c) => TableDataScreen(info: widget.connectionInfo, database: _currentDbName, tableName: n))); })])))
          ]),

          // 탭 2: Query Screen (과거 디자인 복구)
          Column(children: [
            AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: _isTabQueryVisible ? null : 0,
                child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey[100],
                    child: Column(children: [
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_shortcutChip("SELECT", Colors.blue), _shortcutChip("UPDATE", Colors.orange), _shortcutChip("DELETE", Colors.red), _shortcutChip("INSERT", Colors.green), _shortcutChip("COUNT", Colors.purple)])),
                      const SizedBox(height: 12), // [수정 3] 칩과 에디터 사이 여백
                      TextField(
                          controller: _tabQueryController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                          decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(), labelText: "SQL Editor")
                      ),
                      const SizedBox(height: 12), // [수정 3] 에디터와 버튼 사이 여백 추가
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: () => _tabQueryController.clear(), child: const Text("CLEAR")),
                        const SizedBox(width: 12),
                        ElevatedButton(onPressed: _runTabQuery, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF34495E), foregroundColor: Colors.white), child: const Text("RUN QUERY"))
                      ])
                    ])
                )
            ),

            // [수정 2] 검색바 위치 복구
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _isTabSearchVisible ? 60 : 0,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blueGrey[50],
                  child: TextField(
                    controller: _tabSearchController,
                    onChanged: (v) => setState(() => _tabSearchTerm = v),
                    decoration: InputDecoration(hintText: "Search in history...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                  ),
                ),
              ),
            ),

            const Divider(height: 1),
            Expanded(
              child: _isHistoryLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _queryHistoryRows.isEmpty
                  ? const Center(child: Text("저장된 쿼리 이력이 없습니다."))
                  : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _queryHistoryRows.length,
                itemBuilder: (context, index) {
                  final item = _queryHistoryRows[index];
                  // 검색어 필터링 로직 추가
                  if (_tabSearchTerm.isNotEmpty && !item['query_text'].toString().toLowerCase().contains(_tabSearchTerm.toLowerCase())) {
                    return const SizedBox.shrink();
                  }
                  return _buildHistoryCard(item);
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final queryText = item['query_text'] ?? '';
    final dateStr = item['execution_date'] ?? '';
    final isFav = item['is_favorite'] == 1 || item['is_favorite'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 30, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() { _tabQueryController.text = queryText; _isTabQueryVisible = true; }),
                    child: Text(queryText, style: const TextStyle(fontSize: 15, color: Color(0xFF3487A9), fontWeight: FontWeight.bold, fontFamily: 'monospace'), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
                Icon(isFav ? Icons.star : Icons.more_vert, color: isFav ? Colors.orange : Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _shortcutChip(String label, Color color) {
    return Padding(padding: const EdgeInsets.only(right: 6.0), child: ActionChip(label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), backgroundColor: color.withOpacity(0.8), onPressed: () => setState(() => _tabQueryController.text = label == 'SELECT' ? "SELECT TOP 100 * FROM " : label + " ")));
  }

  Widget _buildExpandableCard(IconData icon, String title, dynamic data, {String? highlightItem, String filter = "", void Function(String)? onItemTap}) {
    List<dynamic> items = data != null ? (data['items'] ?? []) : [];
    List<dynamic> filtered = items.where((i) => i.toString().toLowerCase().contains(filter.toLowerCase())).toList();
    return Card(color: Colors.white, elevation: 0.5, margin: const EdgeInsets.only(bottom: 8.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), child: ExpansionTile(initiallyExpanded: filter.isNotEmpty, leading: Icon(icon, color: Colors.grey[700]), title: Text('$title (${filtered.length})'), children: [Container(padding: const EdgeInsets.all(8.0), color: const Color(0xFFF9F9F9), child: filtered.isEmpty ? const Padding(padding: EdgeInsets.all(8.0), child: Text('항목이 없습니다.')) : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: filtered.length, itemBuilder: (context, index) { String name = filtered[index].toString(); bool isH = highlightItem != null && name == highlightItem; return Container(margin: const EdgeInsets.only(bottom: 4.0), decoration: BoxDecoration(color: isH ? const Color(0xFF75BBE1) : Colors.white, borderRadius: BorderRadius.circular(4.0), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1)]), child: InkWell(onTap: () => onItemTap?.call(name), child: Padding(padding: const EdgeInsets.all(12.0), child: Row(children: [Expanded(child: Text(name, style: TextStyle(color: isH ? Colors.white : Colors.black87, fontWeight: isH ? FontWeight.bold : FontWeight.w500))), const Icon(Icons.more_vert, size: 20)])))); }))]));
  }
}