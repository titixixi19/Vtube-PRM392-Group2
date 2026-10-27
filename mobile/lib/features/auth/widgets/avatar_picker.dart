import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Ô chọn ảnh đại diện tròn có huy hiệu máy ảnh (màn Đăng ký). Chưa có ảnh -> icon người.
class AvatarPicker extends StatelessWidget {
  final Uint8List? imageBytes;

  /// null -> không bấm được (đang gửi form).
  final VoidCallback? onTap;

  const AvatarPicker({super.key, this.imageBytes, this.onTap});

  static const _size = 104.0;

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        button: true,
        label: 'Chọn ảnh đại diện',
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: _size,
            child: Stack(children: [
              Container(
                width: _size,
                height: _size,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceHigh,
                  border: Border.all(color: AppColors.surfaceHighest, width: 2),
                ),
                child: bytes == null
                    ? const Icon(Icons.person_outline, size: 48, color: AppColors.textSecondary)
                    : Image.memory(bytes,
                        key: const ValueKey('avatar-preview'), fit: BoxFit.cover, gaplessPlayback: true),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 3),
                  ),
                  child: const Icon(Icons.photo_camera, size: 16, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        bytes == null ? 'Chạm để tải ảnh đại diện' : 'Chạm để đổi ảnh đại diện',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ]);
  }
}
