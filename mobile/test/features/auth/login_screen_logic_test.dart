import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/features/auth/auth_validators.dart';

import 'auth_test_helpers.dart';

/// MÀN 2 · ĐĂNG NHẬP · kiểm thử logic nghiệp vụ.
/// Chạy: cd mobile && flutter test test/features/auth/login_screen_logic_test.dart
void main() {
  group('AuthValidators.email', () {
    test('báo lỗi khi trống hoặc chỉ có khoảng trắng', () {
      expect(AuthValidators.email(null), 'Vui lòng nhập email');
      expect(AuthValidators.email(''), 'Vui lòng nhập email');
      expect(AuthValidators.email('   '), 'Vui lòng nhập email');
    });

    test('báo lỗi khi sai định dạng', () {
      // Nhóm sau: backend (@Email) từ chối nên app phải chặn trước, tránh lỗi 400 khó hiểu.
      for (final email in [
        'abc',
        'demo@',
        '@vtube.vn',
        'demo@vtube',
        'demo vtube@vtube.vn',
        'demo@@vtube.vn',
        'demo.@vtube.vn',
        '.demo@vtube.vn',
        'de..mo@vtube.vn',
        'demo@vt_ube.vn',
        'demo@-vtube.vn',
        'demo@vtube-.vn',
        'demo@vtube..vn',
      ]) {
        expect(AuthValidators.email(email), 'Email không đúng định dạng', reason: email);
      }
    });

    test('chấp nhận email hợp lệ, bỏ qua khoảng trắng hai đầu', () {
      for (final email in [demoEmail, 'ten.ho+tag@mail.co.uk', 'user_1@sub-domain.vn', '  demo@vtube.vn  ']) {
        expect(AuthValidators.email(email), isNull, reason: email);
      }
    });
  });

  group('AuthValidators.loginPassword', () {
    test('báo lỗi khi trống', () {
      expect(AuthValidators.loginPassword(null), 'Vui lòng nhập mật khẩu');
      expect(AuthValidators.loginPassword(''), 'Vui lòng nhập mật khẩu');
    });

    test('báo lỗi khi dưới 6 ký tự', () {
      expect(AuthValidators.loginPassword('12345'), 'Mật khẩu phải có ít nhất 6 ký tự');
      expect(AuthValidators.loginPassword('sai'), 'Mật khẩu phải có ít nhất 6 ký tự');
    });

    test('chấp nhận từ 6 ký tự', () {
      expect(AuthValidators.loginPassword('123456'), isNull);
      expect(AuthValidators.loginPassword('saimatkhau'), isNull);
    });
  });

  group('AuthProvider.login', () {
    late AuthTestEnv env;

    setUp(() => env = AuthTestEnv());

    test('đúng tài khoản: lưu user và token, báo UI vẽ lại', () async {
      var notified = 0;
      env.auth.addListener(() => notified++);

      await env.auth.login('  $demoEmail  ', demoPassword);

      expect(env.auth.isLoggedIn, isTrue);
      expect(env.auth.user!.email, demoEmail);
      expect(env.service.loginCalls.single, (demoEmail, demoPassword), reason: 'Email phải được cắt khoảng trắng');
      expect(env.tokens.token, demoToken);
      expect((await SharedPreferences.getInstance()).getString('auth_token'), demoToken);
      expect(notified, 1);
    });

    test('sai mật khẩu: ném ApiException, vẫn là khách, không lưu token', () async {
      await expectLater(
        env.auth.login(demoEmail, 'saimatkhau'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email hoặc mật khẩu không đúng')),
      );

      expect(env.auth.isLoggedIn, isFalse);
      expect(env.tokens.token, isNull);
      expect((await SharedPreferences.getInstance()).getString('auth_token'), isNull);
    });
  });

  group('Luồng màn Đăng nhập', () {
    late AuthTestEnv env;

    setUp(() => env = AuthTestEnv());

    testWidgets('đang gửi thì Back không rời màn (tránh đăng nhập ngầm), gửi xong mới quay lại', (tester) async {
      env.service.hold = Completer<void>();
      await pumpLoginScreen(tester, env, fromPreviousScreen: true);
      await tester.enterText(emailField(), demoEmail);
      await tester.enterText(passwordField(), demoPassword);
      await tester.tap(loginButton());
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(find.text('để tiếp tục với VTube'), findsOneWidget, reason: 'Vẫn ở màn Đăng nhập');

      env.service.hold!.complete();
      await tester.pumpAndSettle();
      expect(env.auth.isLoggedIn, isTrue);
      expect(find.text(previousScreenLabel), findsOneWidget);
    });

    testWidgets('form không hợp lệ thì không gọi API', (tester) async {
      await pumpLoginScreen(tester, env);

      await tester.tap(loginButton());
      await tester.enterText(emailField(), 'abc');
      await tester.enterText(passwordField(), '123');
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(env.service.loginCalls, isEmpty);
      expect(env.auth.isLoggedIn, isFalse);
    });

    testWidgets('sai mật khẩu: SnackBar lỗi, giữ email, xóa mật khẩu, ở lại màn', (tester) async {
      await pumpLoginScreen(tester, env);

      await tester.enterText(emailField(), demoEmail);
      await tester.enterText(passwordField(), 'saimatkhau');
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
      expect(fieldText(tester, emailField()), demoEmail);
      expect(fieldText(tester, passwordField()), isEmpty);
      expect(loginButton(), findsOneWidget);
      expect(env.auth.isLoggedIn, isFalse);
    });

    testWidgets('đúng tài khoản khi mở thẳng: vào Trang chủ', (tester) async {
      await pumpLoginScreen(tester, env);

      await tester.enterText(emailField(), demoEmail);
      await tester.enterText(passwordField(), demoPassword);
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(env.auth.isLoggedIn, isTrue);
      expect(find.text(homeLabel), findsOneWidget);
    });

    testWidgets('mở từ màn khác (requireLogin): đăng nhập xong quay lại đúng màn đó', (tester) async {
      await pumpLoginScreen(tester, env, fromPreviousScreen: true);

      await tester.enterText(emailField(), demoEmail);
      await tester.enterText(passwordField(), demoPassword);
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(env.auth.isLoggedIn, isTrue);
      expect(find.text(previousScreenLabel), findsOneWidget);
      expect(find.text(homeLabel), findsNothing);
      expect(loginButton(), findsNothing);
    });

    testWidgets('Enter ở ô Mật khẩu gửi form với đúng dữ liệu đã nhập', (tester) async {
      await pumpLoginScreen(tester, env);

      await tester.enterText(emailField(), demoEmail);
      await tester.enterText(passwordField(), demoPassword);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(env.service.loginCalls.single, (demoEmail, demoPassword));
      expect(find.text(homeLabel), findsOneWidget);
    });

    testWidgets('Tiếp tục với Google (giả lập): đăng nhập tài khoản demo và báo SnackBar', (tester) async {
      await pumpLoginScreen(tester, env);

      await tester.tap(googleButton());
      await tester.pumpAndSettle();

      expect(env.service.loginCalls.single, (demoEmail, demoPassword));
      expect(env.auth.isLoggedIn, isTrue);
      expect(find.text('Đăng nhập Google (giả lập)'), findsOneWidget);
      expect(find.text(homeLabel), findsOneWidget);
    });
  });
}
