import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/app/theme.dart';

import 'auth_test_helpers.dart';
import 'splash_test_helpers.dart';

/// MÀN 1 · SPLASH · kiểm thử giao diện.
/// Chạy: cd mobile && flutter test test/features/auth/splash_screen_ui_test.dart
void main() {
  testWidgets('hiển thị logo, tên app, khẩu hiệu, vòng quay và phiên bản', (tester) async {
    await pumpSplash(tester, SplashTestEnv());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('VTube', findRichText: true), findsOneWidget);
    expect(find.text('WATCH • CREATE • CONNECT'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing, reason: 'Bản thiết kế đã sửa: không có app bar');

    await passMinDuration(tester);
  });

  testWidgets('logo phóng to và hiện dần trong 600 ms', (tester) async {
    await pumpSplash(tester, SplashTestEnv());
    double opacity() => tester.widget<FadeTransition>(find.byKey(const ValueKey('splash-fade'))).opacity.value;
    double scale() => tester.widget<ScaleTransition>(find.byKey(const ValueKey('splash-scale'))).scale.value;

    expect(opacity(), 0);
    expect(scale(), closeTo(0.8, 0.001));

    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(), 1);
    expect(scale(), closeTo(1, 0.001));

    await passMinDuration(tester);
  });

  testWidgets('giữ splash tối thiểu 1,5 giây dù kết nối xong ngay', (tester) async {
    await pumpSplash(tester, SplashTestEnv());

    await tester.pump(const Duration(milliseconds: 1400));
    // Vẽ thêm vài khung hình (không tăng thời gian) để nếu app đã chuyển màn thì Trang chủ kịp hiện ra.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text(homeLabel), findsNothing);

    await tester.pump(const Duration(milliseconds: 99));

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(homeLabel), findsOneWidget);
  });

  testWidgets('mất mạng: thay vòng quay bằng "Không có kết nối mạng" và nút Thử lại', (tester) async {
    final env = SplashTestEnv()..videos.error = networkError;
    await pumpSplash(tester, env);
    await passMinDuration(tester);

    expect(find.text('Không có kết nối mạng'), findsOneWidget);
    expect(retryButton(), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('VTube', findRichText: true), findsOneWidget, reason: 'Vẫn ở màn Splash');
  });

  testWidgets('bấm Thử lại khi vẫn mất mạng: vòng quay hiện đủ 0,8 giây rồi mới báo lại (không chớp)', (tester) async {
    final env = SplashTestEnv()..videos.error = networkError;
    await pumpSplash(tester, env);
    await passMinDuration(tester);

    await tester.tap(retryButton());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(retryButton(), findsNothing);

    // Lỗi mạng về ngay nhưng vẫn giữ vòng quay để người dùng thấy app đã thử.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(env.videos.categoriesCalls, 2);

    await tester.pump(const Duration(milliseconds: 100)); // đủ 800 ms, ngắn hơn 1,5 giây của lần mở đầu
    await tester.pump();
    expect(find.text('Không có kết nối mạng'), findsOneWidget);
  });

  test('nền khởi động gốc (Android, iOS) cùng màu nền tối của Splash, không chớp trắng', () {
    String read(String path) => File(path).readAsStringSync();
    final hex = AppColors.background.toARGB32().toRadixString(16).toUpperCase();
    expect(
        read('android/app/src/main/res/values/colors.xml'), contains('<color name="splash_background">#$hex</color>'));
    for (final path in [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      expect(read(path), contains('@color/splash_background'), reason: path);
    }
    for (final path in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      expect(read(path), isNot(contains('?android:colorBackground')), reason: path);
    }
    final ios = read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
    expect(ios, isNot(contains('<color key="backgroundColor" red="1" green="1" blue="1"')));
    final c = AppColors.background.r.toStringAsFixed(7); // 0x13 / 255 = 0.0745098
    expect(ios, contains('red="$c'));
  });
}
