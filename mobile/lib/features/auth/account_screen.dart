import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/widgets/screen_placeholder.dart';
import '../../shared/widgets/top_bar.dart';

/// MÀN 4 · TRANG "BẠN" · Người 1 (tab thứ 5 của bottom nav)
/// API:
///   - context.watch<AuthProvider>().user           (thông tin tài khoản, kênh)
///   - HistoryService.list(size: 10)                (hàng "Nhật ký xem")
///   - PlaylistService.mine() / create(...)         (hàng "Danh sách phát", nút +)
///   - AuthProvider.logout()                        (Đăng xuất)
/// Điều hướng: AppRoutes.history, AppRoutes.playlist(id), AppRoutes.channel(user.channel.id)
/// Chi tiết: docs/tasks/NGUOI-1.md
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(actions: topBarActions(context)),
      body: ScreenPlaceholder(
        number: '4',
        title: 'Trang "Bạn"',
        owner: 'Người 1',
        actions: [
          if (auth.isLoggedIn) ...[
            Text('Đang đăng nhập: ${auth.user!.displayName}'),
            TextButton(onPressed: () => context.push(AppRoutes.history), child: const Text('Nhật ký xem (màn 13)')),
            TextButton(onPressed: () => context.push(AppRoutes.playlist(1)), child: const Text('Video đã thích (màn 14)')),
            TextButton(onPressed: () => auth.logout(), child: const Text('Đăng xuất')),
          ] else
            TextButton(onPressed: () => context.push(AppRoutes.login), child: const Text('Đăng nhập')),
        ],
      ),
    );
  }
}
