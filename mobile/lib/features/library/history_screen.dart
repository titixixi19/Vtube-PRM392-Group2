import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 13 · LỊCH SỬ XEM · Người 4
/// API: HistoryService.list(type:, q:, page:), delete(videoId), clear()
///      AuthService.setHistoryPaused(true/false) rồi AuthProvider.refreshMe()
/// Nhóm theo ngày từ item.watchedAt (Hôm nay, Hôm qua, Tuần này, ...); thanh đỏ = item.progress
/// Chi tiết: docs/tasks/NGUOI-4.md
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký xem')),
      body: const ScreenPlaceholder(number: '13', title: 'Lịch sử xem', owner: 'Người 4'),
    );
  }
}
