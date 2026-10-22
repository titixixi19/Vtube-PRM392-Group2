import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 16 · THÔNG BÁO · Người 4
/// API: NotificationService.list(type: all | mention, page:), markRead(id), markAllRead(), delete(id)
/// Bấm thông báo -> điều hướng theo item.type (bảng trong docs/API.md mục Thông báo)
/// Chi tiết: docs/tasks/NGUOI-4.md
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: const ScreenPlaceholder(number: '16', title: 'Thông báo', owner: 'Người 4'),
    );
  }
}
