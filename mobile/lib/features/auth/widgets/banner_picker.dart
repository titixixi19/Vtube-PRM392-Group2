import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/app_network_image.dart';

/// Ô chọn ảnh bìa kênh (màn Chỉnh sửa hồ sơ): khung ngang, nút máy ảnh ở góc.
/// Ưu tiên ảnh vừa chọn ([imageBytes]), rồi tới ảnh đang dùng ([imageUrl]); không có ảnh -> nền xám.
class BannerPicker extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imageUrl;

  /// null -> không bấm được (đang lưu).
  final VoidCallback? onTap;

  const BannerPicker({super.key, this.imageBytes, this.imageUrl, this.onTap});

  /// Tỉ lệ ảnh bìa trên điện thoại (giống Trang kênh).
  static const aspectRatio = 16 / 5;

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    final url = imageUrl;
    return Semantics(
      button: true,
      label: 'Chọn ảnh bìa kênh',
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Material(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(fit: StackFit.expand, children: [
              if (bytes != null)
                Image.memory(bytes, key: const ValueKey('banner-preview'), fit: BoxFit.cover, gaplessPlayback: true)
              else if (url != null)
                AppNetworkImage(key: const ValueKey('banner-current'), url: url)
              else
                const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.panorama_outlined, size: 28, color: AppColors.textSecondary),
                    SizedBox(height: 4),
                    Text('Thêm ảnh bìa kênh', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: Color(0xB3000000), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_camera, size: 16, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
