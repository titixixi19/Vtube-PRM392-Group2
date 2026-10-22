import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Màn tạm để app chạy được trước khi từng người code xong.
/// XÓA widget này khỏi màn của bạn khi bắt đầu làm.
class ScreenPlaceholder extends StatelessWidget {
  final String number;
  final String title;
  final String owner;
  final List<Widget> actions;

  const ScreenPlaceholder({super.key, required this.number, required this.title, required this.owner, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.construction, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('Màn $number · $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('$owner đang làm · xem docs/tasks', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ...actions,
        ]),
      ),
    );
  }
}
