import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Nút "Đăng ký" (nền trắng) / "Đã đăng ký" (nền xám + chuông). Chỉ là giao diện;
/// màn hình tự gọi ChannelService.subscribe / unsubscribe trong [onPressed].
class SubscribeButton extends StatelessWidget {
  final bool subscribed;
  final VoidCallback? onPressed;

  /// Kiểu đỏ dùng trên Shorts.
  final bool red;

  const SubscribeButton({super.key, required this.subscribed, this.onPressed, this.red = false});

  @override
  Widget build(BuildContext context) {
    if (subscribed) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceHighest,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.notifications_none, size: 18),
        label: const Text('Đã đăng ký'),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: red ? AppColors.accent : AppColors.chipSelectedBg,
        foregroundColor: red ? Colors.white : AppColors.chipSelectedFg,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: const Text('Đăng ký'),
    );
  }
}
