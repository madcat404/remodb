import 'package:flutter/material.dart';

class QueryEditorTab extends StatelessWidget {
  final TextEditingController queryController;
  final bool isQueryVisible;
  final bool isHistoryLoading;
  final List<dynamic> queryHistory;
  final String searchTerm;
  final VoidCallback onRunQuery;
  final Function(String, Color) shortcutBuilder;
  final Function(Map<String, dynamic>) historyCardBuilder;

  const QueryEditorTab({
    super.key,
    required this.queryController,
    required this.isQueryVisible,
    required this.isHistoryLoading,
    required this.queryHistory,
    required this.searchTerm,
    required this.onRunQuery,
    required this.shortcutBuilder,
    required this.historyCardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 쿼리 에디터 영역
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: isQueryVisible ? null : 0,
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      shortcutBuilder("SELECT", Colors.blue),
                      shortcutBuilder("UPDATE", Colors.orange),
                      shortcutBuilder("DELETE", Colors.red),
                      shortcutBuilder("INSERT", Colors.green),
                      shortcutBuilder("COUNT", Colors.purple),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: queryController,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    labelText: "SQL Editor",
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => queryController.clear(), child: const Text("CLEAR")),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: onRunQuery,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF87588E), foregroundColor: Colors.white),
                      child: const Text("RUN QUERY"),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // 히스토리 영역
        Expanded(
          child: isHistoryLoading && queryHistory.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : queryHistory.isEmpty
              ? const Center(child: Text("저장된 쿼리 이력이 없습니다."))
              : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: queryHistory.length,
            itemBuilder: (context, index) {
              final item = queryHistory[index];
              if (searchTerm.isNotEmpty && !item['query_text'].toString().toLowerCase().contains(searchTerm.toLowerCase())) {
                return const SizedBox.shrink();
              }
              return historyCardBuilder(item);
            },
          ),
        ),
      ],
    );
  }
}