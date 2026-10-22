import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 15 · TẢI VIDEO LÊN · Người 4
/// Luồng: chọn video (image_picker: pickVideo) -> UploadService.upload(path, type: 'video', onProgress:)
///        -> (tùy chọn) upload thumbnail type: 'image' -> VideoService.create(title:, videoUrl:, ...)
/// [isShort]: mở từ "Tạo một video Short" -> gửi isShort: true
/// Chi tiết: docs/tasks/NGUOI-4.md
class UploadScreen extends StatelessWidget {
  final bool isShort;

  const UploadScreen({super.key, this.isShort = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm thông tin')),
      body: ScreenPlaceholder(number: '15', title: isShort ? 'Tải Short lên' : 'Tải video lên', owner: 'Người 4'),
    );
  }
}
