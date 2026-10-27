import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/network/api_exception.dart';
import '../../data/services/video_service.dart';

/// MÀN 1 · SPLASH · Người 1
/// Thiết kế: design/stitch/1._splash_screen/ (bản đã sửa: không có app bar).
///
/// 1. Gọi thử một API công khai nhẹ (GET /api/categories) để biết có kết nối được backend không.
///    (AuthProvider.restoreSession bỏ qua lỗi mạng và không gọi mạng khi chưa có token, nên không dùng để kiểm tra.)
/// 2. Kết nối được -> AuthProvider.restoreSession() -> Trang chủ (đã đăng nhập hoặc khách).
///    Backend trả lỗi (5xx...) vẫn vào Trang chủ theo đặc tả.
/// 3. Mất mạng -> "Không có kết nối mạng" + nút "Thử lại" thay cho vòng quay.
/// Lần mở đầu giữ splash tối thiểu 1,5 giây để hiệu ứng logo (600 ms) chạy xong.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const minDuration = Duration(milliseconds: 1500);

  /// Mỗi lần bấm "Thử lại" hiện vòng quay ít nhất chừng này: mất mạng hẳn thì lỗi về ngay,
  /// nếu báo lại tức thì người dùng tưởng nút không ăn.
  static const retryMinDuration = Duration(milliseconds: 800);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  /// Khớp `version` trong pubspec.yaml.
  static const _version = 'v1.0.0';

  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutBack));
    _start(minDuration: SplashScreen.minDuration);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _start({required Duration minDuration}) async {
    final results = await Future.wait([_connect(), Future<bool>.delayed(minDuration, () => true)]);
    if (!mounted) return;
    if (results.first) {
      context.go(AppRoutes.home);
    } else {
      setState(() => _offline = true);
    }
  }

  void _retry() {
    setState(() => _offline = false);
    _start(minDuration: SplashScreen.retryMinDuration);
  }

  /// true: kết nối được backend (kể cả khi backend trả lỗi). false: mất mạng.
  Future<bool> _connect() async {
    final videos = context.read<VideoService>();
    final auth = context.read<AuthProvider>();
    try {
      await videos.categories();
    } on ApiException catch (e) {
      if (e.isNetworkError) return false;
      // Lỗi server: vẫn vào Trang chủ.
    } catch (_) {
      // Dữ liệu trả về lạ: backend vẫn trả lời được, coi như có kết nối.
    }
    try {
      await auth.restoreSession();
    } catch (_) {
      // Không xác nhận được phiên: vào Trang chủ ở chế độ khách thay vì kẹt ở splash.
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: _Glow()),
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 5),
            FadeTransition(
              key: const ValueKey('splash-fade'),
              opacity: _fade,
              child: Column(children: [
                ScaleTransition(key: const ValueKey('splash-scale'), scale: _scale, child: const _SplashLogo()),
                const SizedBox(height: 28),
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'V'),
                    TextSpan(text: 'Tube', style: TextStyle(color: AppColors.accentSoft)),
                  ]),
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                const Text(
                  'WATCH • CREATE • CONNECT',
                  style: TextStyle(fontSize: 13, letterSpacing: 3, color: AppColors.textSecondary),
                ),
              ]),
            ),
            const Spacer(flex: 6),
            SizedBox(
              height: 96,
              child: Center(
                child: _offline
                    ? _OfflineView(onRetry: _retry)
                    : const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(_version, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

/// Logo chữ nhật bo góc đỏ, tam giác play trắng, có quầng sáng.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(AppColors.accent, AppColors.accentSoft, 0.3)!, AppColors.accent],
        ),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 40, spreadRadius: 2)],
      ),
      child: Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 52),
    );
  }
}

/// Nền tối với quầng sáng đỏ phía trên và xanh mờ quanh logo.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1.1),
                radius: 0.9,
                colors: [AppColors.accent.withValues(alpha: 0.16), AppColors.accent.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 0.6,
                colors: [AppColors.link.withValues(alpha: 0.07), AppColors.link.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _OfflineView extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.textSecondary),
        SizedBox(width: 8),
        Text('Không có kết nối mạng', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      ]),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Thử lại'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.surfaceHighest),
          shape: const StadiumBorder(),
        ),
      ),
    ]);
  }
}
