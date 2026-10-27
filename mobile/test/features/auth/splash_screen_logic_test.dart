import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/network/api_exception.dart';

import 'auth_test_helpers.dart';
import 'splash_test_helpers.dart';

/// MÀN 1 · SPLASH · kiểm thử logic nghiệp vụ.
/// Chạy: cd mobile && flutter test test/features/auth/splash_screen_logic_test.dart
void main() {
  testWidgets('đã đăng nhập (token còn hạn): khôi phục phiên rồi vào Trang chủ', (tester) async {
    final env = SplashTestEnv(savedToken: demoToken);
    await pumpSplash(tester, env);
    await passMinDuration(tester);
    await tester.pumpAndSettle();

    expect(env.session.meCalls, 1);
    expect(env.auth.isLoggedIn, isTrue);
    expect(env.auth.user!.email, demoEmail);
    expect(find.text(homeLabel), findsOneWidget);
  });

  testWidgets('chưa đăng nhập: vào Trang chủ ở chế độ khách, không gọi /api/me', (tester) async {
    final env = SplashTestEnv();
    await pumpSplash(tester, env);
    await passMinDuration(tester);
    await tester.pumpAndSettle();

    expect(env.videos.categoriesCalls, 1, reason: 'Vẫn kiểm tra kết nối dù chưa có token');
    expect(env.session.meCalls, 0);
    expect(env.auth.isLoggedIn, isFalse);
    expect(find.text(homeLabel), findsOneWidget);
  });

  testWidgets('token hết hạn (401): xóa token, vào Trang chủ ở chế độ khách', (tester) async {
    final env = SplashTestEnv(savedToken: 'token-cu')
      ..session.meError = const ApiException('Phiên đăng nhập đã hết hạn', statusCode: 401);
    await pumpSplash(tester, env);
    await passMinDuration(tester);
    await tester.pumpAndSettle();

    expect(env.auth.isLoggedIn, isFalse);
    expect((await SharedPreferences.getInstance()).getString('auth_token'), isNull);
    expect(find.text(homeLabel), findsOneWidget);
  });

  testWidgets('mất mạng: ở lại Splash; có mạng lại + Thử lại thì vào Trang chủ và vẫn đăng nhập', (tester) async {
    final env = SplashTestEnv(savedToken: demoToken)..videos.error = networkError;
    await pumpSplash(tester, env);
    await passMinDuration(tester);

    expect(find.text(homeLabel), findsNothing);
    expect(env.session.meCalls, 0, reason: 'Mất mạng thì chưa khôi phục phiên');
    expect((await SharedPreferences.getInstance()).getString('auth_token'), demoToken, reason: 'Không xóa token');

    env.videos.error = null; // bật lại backend
    await tester.tap(retryButton());
    await tester.pumpAndSettle();

    expect(env.auth.isLoggedIn, isTrue);
    expect(find.text(homeLabel), findsOneWidget);
  });

  testWidgets('backend trả lỗi server (500): vẫn vào Trang chủ', (tester) async {
    final env = SplashTestEnv()..videos.error = const ApiException('Lỗi máy chủ', statusCode: 500);
    await pumpSplash(tester, env);
    await passMinDuration(tester);
    await tester.pumpAndSettle();

    expect(find.text(homeLabel), findsOneWidget);
    expect(find.text('Không có kết nối mạng'), findsNothing);
  });

  testWidgets('dữ liệu trả về lạ (lỗi không phải ApiException): không kẹt ở Splash', (tester) async {
    final env = SplashTestEnv()..videos.error = const FormatException('JSON lạ');
    await pumpSplash(tester, env);
    await passMinDuration(tester);
    await tester.pumpAndSettle();

    expect(find.text(homeLabel), findsOneWidget);
  });

  testWidgets('rời Splash giữa chừng: không lỗi khi các Future xong sau đó', (tester) async {
    final env = SplashTestEnv(savedToken: demoToken);
    await pumpSplash(tester, env);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpWidget(const SizedBox()); // gỡ Splash khỏi cây
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });
}
