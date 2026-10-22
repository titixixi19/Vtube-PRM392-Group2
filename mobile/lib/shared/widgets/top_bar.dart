import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../data/services/notification_service.dart';

/// Logo VTube: icon play đỏ + chữ "VTube" (chỉ 1 chữ).
class VtubeLogo extends StatelessWidget {
  const VtubeLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 30,
        height: 21,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 6),
      const Text('VTube', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
    ]);
  }
}

/// Các nút bên phải app bar ở Trang chủ / Kênh đăng ký / Bạn: Cast, Chuông (có badge), Tìm kiếm.
List<Widget> topBarActions(BuildContext context) => [
      IconButton(icon: const Icon(Icons.cast), onPressed: () {}),
      const NotificationBell(),
      IconButton(icon: const Icon(Icons.search), onPressed: () => context.push(AppRoutes.search)),
    ];

/// Chuông thông báo + badge số chưa đọc (chỉ khi đã đăng nhập).
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  bool? _lastLoggedIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loggedIn = Provider.of<AuthProvider>(context).isLoggedIn;
    if (loggedIn != _lastLoggedIn) {
      _lastLoggedIn = loggedIn;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!context.read<AuthProvider>().isLoggedIn) {
      if (mounted) setState(() => _unread = 0);
      return;
    }
    try {
      final n = await context.read<NotificationService>().unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {
      // Bỏ qua: badge không quan trọng
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 9 ? '9+' : '$_unread'),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.notifications_none),
      ),
      onPressed: () async {
        await context.push(AppRoutes.notifications);
        _refresh();
      },
    );
  }
}
