import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/app/routes.dart';
import 'package:vtube/app/theme.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/auth_service.dart';
import 'package:vtube/data/services/video_service.dart';
import 'package:vtube/features/auth/splash_screen.dart';

import 'auth_test_helpers.dart';

/// Hàm và lớp giả cho test màn Splash (tách riêng khỏi auth_test_helpers để các nhánh màn khác không xung đột).

/// Lỗi giống ApiClient ném ra khi không kết nối được backend (không có statusCode).
const networkError = ApiException('Không kết nối được máy chủ. Kiểm tra mạng hoặc backend.');

/// AuthService giả cho phần khôi phục phiên (GET /api/me).
class FakeSessionService extends AuthService {
  FakeSessionService(super.api);

  int meCalls = 0;

  /// Gán để /api/me lỗi (vd. 401 token hết hạn).
  ApiException? meError;

  @override
  Future<Me> me() async {
    meCalls++;
    if (meError != null) throw meError!;
    return fakeUser();
  }
}

/// VideoService giả: chỉ dùng categories() để Splash kiểm tra kết nối.
class FakeVideoService extends VideoService {
  FakeVideoService(super.api);

  int categoriesCalls = 0;

  /// Gán [networkError] để giả lập mất mạng, hoặc ApiException có statusCode để giả lập lỗi server.
  Object? error;

  @override
  Future<List<Category>> categories() async {
    categoriesCalls++;
    if (error != null) throw error!;
    return const [Category(id: 1, name: 'Âm nhạc', slug: 'music')];
  }
}

class SplashTestEnv {
  final TokenStorage tokens;
  final FakeSessionService session;
  final FakeVideoService videos;
  final AuthProvider auth;

  SplashTestEnv._(this.tokens, this.session, this.videos, this.auth);

  /// [savedToken]: token đã lưu từ lần mở app trước (null = chưa từng đăng nhập).
  factory SplashTestEnv({String? savedToken}) {
    SharedPreferences.setMockInitialValues(savedToken == null ? {} : {'auth_token': savedToken});
    final tokens = TokenStorage();
    final api = ApiClient(tokens);
    final session = FakeSessionService(api);
    return SplashTestEnv._(tokens, session, FakeVideoService(api), AuthProvider(session, tokens, api));
  }
}

/// Mở app tại Splash. Chỉ pump 1 khung hình (vòng quay chạy mãi nên không dùng pumpAndSettle).
Future<void> pumpSplash(WidgetTester tester, SplashTestEnv env) async {
  tester.view.physicalSize = const Size(480 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, __) => const Scaffold(body: Text(homeLabel))),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<VideoService>.value(value: env.videos),
        ChangeNotifierProvider<AuthProvider>.value(value: env.auth),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
}

/// Chờ hết thời gian giữ splash tối thiểu (1,5 giây) và cho các Future xong.
Future<void> passMinDuration(WidgetTester tester) async {
  await tester.pump(SplashScreen.minDuration);
  await tester.pump();
  await tester.pump();
}

Finder retryButton() => find.text('Thử lại');
