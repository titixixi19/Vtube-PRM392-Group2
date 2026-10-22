import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 10 · KẾT QUẢ TÌM KIẾM · Người 3
/// API: SearchService.search(query, filters: SearchFilters(...), page:)
/// Widget có sẵn: ChipBar, VideoCardCompact, ShortsShelf, SubscribeButton
/// Chi tiết: docs/tasks/NGUOI-3.md
class SearchResultsScreen extends StatelessWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(query)),
      body: ScreenPlaceholder(number: '10', title: 'Kết quả "$query"', owner: 'Người 3'),
    );
  }
}
