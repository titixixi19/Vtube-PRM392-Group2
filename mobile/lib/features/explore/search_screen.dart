import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 9 · TÌM KIẾM · Người 3
/// API: SearchService.suggestions(q)  (debounce 300 ms; q rỗng -> chỉ trả lịch sử)
///      SearchService.deleteHistory(keyword: k)
/// Tìm -> context.push(AppRoutes.searchResults(q))
/// [initialQuery]: điền sẵn khi bấm vào ô tìm kiếm ở màn 10.
/// Chi tiết: docs/tasks/NGUOI-3.md
class SearchScreen extends StatelessWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: const ScreenPlaceholder(number: '9', title: 'Tìm kiếm', owner: 'Người 3'),
    );
  }
}
