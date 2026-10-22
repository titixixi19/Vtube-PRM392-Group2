import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_provider.dart';
import '../core/auth/require_login.dart';
import '../shared/widgets/channel_avatar.dart';
import 'routes.dart';

/// Khung có Bottom Navigation: Trang chủ, Shorts, (+) Tạo, Kênh đăng ký, Bạn.
/// Mỗi tab giữ trạng thái riêng (cuộn tới đâu vẫn ở đó khi quay lại).
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  // branch: 0 Trang chủ, 1 Shorts, 2 Kênh đăng ký, 3 Bạn  <->  ô trên thanh: 0, 1, 3, 4 (ô 2 là nút Tạo)
  static const _branchToSlot = [0, 1, 3, 4];

  void _onTap(BuildContext context, int slot) {
    if (slot == 2) {
      _showCreateSheet(context);
      return;
    }
    final branch = _branchToSlot.indexOf(slot);
    // Bấm lại tab đang mở -> quay về màn gốc của tab
    navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    if (!await requireLogin(context, title: 'Đăng nhập để tạo nội dung')) return;
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Tạo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            ListTile(
              leading: const Icon(Icons.slow_motion_video),
              title: const Text('Tạo một video Short'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.uploadShort());
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Tải video lên'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.upload);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sensors),
              title: const Text('Phát trực tiếp'),
              onTap: () {
                Navigator.pop(ctx);
                showSnack(context, 'Tính năng đang phát triển');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isShorts = navigationShell.currentIndex == 1;
    return Scaffold(
      body: navigationShell,
      backgroundColor: isShorts ? Colors.black : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _branchToSlot[navigationShell.currentIndex],
        onDestinationSelected: (slot) => _onTap(context, slot),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          const NavigationDestination(
              icon: Icon(Icons.slow_motion_video_outlined), selectedIcon: Icon(Icons.slow_motion_video), label: 'Shorts'),
          const NavigationDestination(icon: Icon(Icons.add_circle_outline, size: 36), label: ''),
          const NavigationDestination(
              icon: Icon(Icons.subscriptions_outlined), selectedIcon: Icon(Icons.subscriptions), label: 'Kênh đăng ký'),
          NavigationDestination(
            icon: user == null
                ? const Icon(Icons.account_circle_outlined)
                : ChannelAvatar(url: user.avatarUrl, size: 26),
            label: 'Bạn',
          ),
        ],
      ),
    );
  }
}
