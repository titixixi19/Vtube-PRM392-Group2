import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Logo VTube dạng ô vuông bo góc (nút play đỏ) ở đầu màn Đăng nhập, Đăng ký.
class AuthLogo extends StatelessWidget {
  final double size;

  const AuthLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(color: theme.shadowColor.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Container(
        width: size * 0.69,
        height: size * 0.5,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(size * 0.19)),
        child: Icon(Icons.play_arrow_rounded, color: theme.colorScheme.onPrimary, size: size * 0.4),
      ),
    );
  }
}
