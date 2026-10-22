import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import 'auth_provider.dart';

/// Dùng trước mọi thao tác cần tài khoản (Like, Đăng ký, Bình luận, Lưu, Tải lên...).
///
///   if (!await requireLogin(context)) return;
///   // ... gọi API
///
/// Khách -> hiện dialog "Đăng nhập để tiếp tục" -> mở màn Đăng nhập.
/// Trả về true nếu sau cùng đã đăng nhập.
Future<bool> requireLogin(BuildContext context, {String title = 'Đăng nhập để tiếp tục'}) async {
  if (context.read<AuthProvider>().isLoggedIn) return true;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: const Text('Bạn cần đăng nhập VTube để sử dụng tính năng này.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng nhập')),
      ],
    ),
  );
  if (go == true && context.mounted) {
    await context.push(AppRoutes.login);
  }
  return context.mounted && context.read<AuthProvider>().isLoggedIn;
}

/// Hiện SnackBar lỗi / thông báo ngắn.
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
