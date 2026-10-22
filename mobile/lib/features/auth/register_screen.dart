import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 3 · ĐĂNG KÝ · Người 1
/// API:
///   - AuthService.isHandleAvailable(handle)   (gọi sau khi ngừng gõ 500 ms)
///   - UploadService.upload(path, type: 'image') -> url avatar (tùy chọn)
///   - AuthProvider.register(displayName:, channelName:, handle:, email:, password:, avatarUrl:)
/// Thành công -> AuthProvider đã lưu token -> context.go(AppRoutes.home)
/// Chi tiết: docs/tasks/NGUOI-1.md
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: const ScreenPlaceholder(number: '3', title: 'Đăng ký', owner: 'Người 1'),
    );
  }
}
