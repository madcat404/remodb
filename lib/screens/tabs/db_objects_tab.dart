import 'package:flutter/material.dart';
import '../../models/connection_info.dart';
import '../table_data_screen.dart';

class DbObjectsTab extends StatelessWidget {
  final bool isLoading;
  final Map<String, dynamic> dbStats;
  final String currentDbName;
  final String filter;
  final ConnectionInfo connectionInfo;
  final Function(String) onDatabaseChange;
  final Future<void> Function() onRefresh;

  const DbObjectsTab({
    super.key,
    required this.isLoading,
    required this.dbStats,
    required this.currentDbName,
    required this.filter,
    required this.connectionInfo,
    required this.onDatabaseChange,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          _buildExpandableCard(
            Icons.storage,
            'Databases',
            dbStats['databases'],
            highlightItem: currentDbName,
            filter: filter,
            onItemTap: onDatabaseChange,
          ),
          _buildExpandableCard(
            Icons.table_chart_outlined,
            'Tables',
            dbStats['tables'],
            filter: filter,
            onItemTap: (tableName) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => TableDataScreen(
                    info: connectionInfo,
                    database: currentDbName,
                    tableName: tableName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 데이터베이스 및 테이블 카드를 빌드하는 함수
  Widget _buildExpandableCard(IconData icon, String title, dynamic data,
      {String? highlightItem, String filter = "", void Function(String)? onItemTap}) {
    List<dynamic> items = data != null ? (data['items'] ?? []) : [];
    // 검색 필터 적용
    List<dynamic> filtered = items.where((i) => i.toString().toLowerCase().contains(filter.toLowerCase())).toList();

    return Card(
      color: Colors.white,
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ExpansionTile(
        initiallyExpanded: filter.isNotEmpty,
        leading: Icon(icon, color: Colors.grey[700]),
        title: Text('$title (${filtered.length})'),
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: const Color(0xFFF9F9F9),
            child: filtered.isEmpty
                ? const Padding(padding: EdgeInsets.all(8.0), child: Text('항목이 없습니다.'))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                String name = filtered[index].toString();
                bool isH = highlightItem != null && name == highlightItem;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4.0),
                  decoration: BoxDecoration(
                    color: isH ? const Color(0xFF75BBE1) : Colors.white,
                    borderRadius: BorderRadius.circular(4.0),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1)],
                  ),
                  child: InkWell(
                    onTap: () => onItemTap?.call(name),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // [수정] 아이콘을 제거하고 텍스트가 전체 공간을 차지하도록 변경
                          Expanded(
                              child: Text(
                                  name,
                                  style: TextStyle(
                                      color: isH ? Colors.white : Colors.black87,
                                      fontWeight: isH ? FontWeight.bold : FontWeight.w500
                                  )
                              )
                          ),
                          // 기존의 Icon(Icons.more_vert) 코드를 삭제하였습니다.
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}