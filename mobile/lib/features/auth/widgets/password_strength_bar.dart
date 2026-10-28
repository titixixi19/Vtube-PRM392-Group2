import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../auth_validators.dart';

/// Thanh độ mạnh mật khẩu 3 nấc (Yếu / Trung bình / Mạnh) dưới ô Mật khẩu. Ẩn khi chưa nhập.
class PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthBar({super.key, required this.strength});

  @override
  Widget build(BuildContext context) {
    if (strength == PasswordStrength.none) return const SizedBox.shrink();
    final color = switch (strength) {
      PasswordStrength.strong => AppColors.link,
      PasswordStrength.medium => AppColors.accentSoft,
      _ => AppColors.accent,
    };
    final filled = strength.index; // weak = 1, medium = 2, strong = 3

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: i < filled ? color : AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          'Độ mạnh: ${strength.label}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ]),
    );
  }
}
