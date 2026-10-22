import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/auth/auth_provider.dart';

/// MÀN 1 · SPLASH · Người 1
/// Đặc tả: docs/tasks/NGUOI-1.md và tài liệu đặc tả (Màn 1).
///
/// Đã có sẵn logic tối thiểu để app chạy được: khôi phục phiên rồi vào Trang chủ.
/// TODO(Người 1):
///   - Giao diện theo Stitch: logo + "VTube" + "WATCH • CREATE • CONNECT", vòng quay nhỏ, "v1.0.0"
///   - Hiệu ứng logo scale/fade 600 ms, giữ splash tối thiểu 1,5 giây
///   - Mất mạng: hiện "Không có kết nối mạng" + nút "Thử lại"
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.wait([
      context.read<AuthProvider>().restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('VTube', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
    );
  }
}
