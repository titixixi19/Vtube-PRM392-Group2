import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_helpers.dart';

/// MÀN 2 · ĐĂNG NHẬP · kiểm thử giao diện.
/// Chạy: cd mobile && flutter test test/features/auth/login_screen_ui_test.dart
void main() {
  late AuthTestEnv env;

  setUp(() => env = AuthTestEnv());

  testWidgets('hiển thị đủ các thành phần theo thiết kế', (tester) async {
    await pumpLoginScreen(tester, env);

    expect(find.text('Đăng nhập'), findsNWidgets(2)); // tiêu đề + nút
    expect(find.text('để tiếp tục với VTube'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(loginButton(), findsOneWidget);
    expect(find.text('HOẶC'), findsOneWidget);
    expect(googleButton(), findsOneWidget);
    expect(find.text('Chưa có tài khoản?'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsOneWidget);
  });

  testWidgets('không có 2 khối thừa của Stitch', (tester) async {
    await pumpLoginScreen(tester, env);

    expect(find.textContaining('Bảo mật tài khoản'), findsNothing);
    expect(find.textContaining('Mã hóa SSL'), findsNothing);
  });

  testWidgets('nút Đăng nhập mờ khi form chưa hợp lệ, rõ khi hợp lệ', (tester) async {
    await pumpLoginScreen(tester, env);
    double opacity() => tester
        .widget<AnimatedOpacity>(find.ancestor(of: loginButton(), matching: find.byType(AnimatedOpacity)))
        .opacity;

    expect(opacity(), 0.5);

    await tester.enterText(emailField(), demoEmail);
    await tester.pump();
    expect(opacity(), 0.5, reason: 'Mới có email, chưa có mật khẩu');

    await tester.enterText(passwordField(), demoPassword);
    await tester.pump();
    expect(opacity(), 1);
  });

  testWidgets('bấm Đăng nhập khi để trống: lỗi hiện dưới từng ô', (tester) async {
    await pumpLoginScreen(tester, env);

    await tester.tap(loginButton());
    await tester.pump();

    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
  });

  testWidgets('email sai định dạng và mật khẩu ngắn: hiện đúng câu lỗi', (tester) async {
    await pumpLoginScreen(tester, env);

    await tester.enterText(emailField(), 'demo@');
    await tester.enterText(passwordField(), '123');
    await tester.tap(loginButton());
    await tester.pump();

    expect(find.text('Email không đúng định dạng'), findsOneWidget);
    expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
  });

  testWidgets('lỗi email hiện ngay khi rời ô', (tester) async {
    await pumpLoginScreen(tester, env);

    await tester.enterText(emailField(), 'abc');
    await tester.pump();
    expect(find.text('Email không đúng định dạng'), findsNothing, reason: 'Đang gõ thì chưa báo lỗi');

    await tester.tap(passwordField()); // chuyển focus sang ô khác
    await tester.pump();
    expect(find.text('Email không đúng định dạng'), findsOneWidget);
  });

  testWidgets('mật khẩu bị ẩn mặc định, bấm con mắt để hiện/ẩn', (tester) async {
    await pumpLoginScreen(tester, env);
    expect(editableOf(tester, passwordField()).obscureText, isTrue);

    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    expect(editableOf(tester, passwordField()).obscureText, isFalse);

    await tester.tap(find.byTooltip('Ẩn mật khẩu'));
    await tester.pump();
    expect(editableOf(tester, passwordField()).obscureText, isTrue);
  });

  testWidgets('Enter ở ô Email chuyển focus sang ô Mật khẩu', (tester) async {
    await pumpLoginScreen(tester, env);

    await tester.enterText(emailField(), demoEmail);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    expect(editableOf(tester, passwordField()).focusNode.hasFocus, isTrue);
  });

  testWidgets('đang gửi: hiện vòng quay, khóa các ô và nút', (tester) async {
    env.service.hold = Completer<void>();
    await pumpLoginScreen(tester, env);

    await tester.enterText(emailField(), demoEmail);
    await tester.enterText(passwordField(), demoPassword);
    await tester.tap(loginButton());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextFormField>(emailField()).enabled, isFalse);
    expect(tester.widget<TextFormField>(passwordField()).enabled, isFalse);
    final google = find.ancestor(of: googleButton(), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(tester.widget<ButtonStyleButton>(google).enabled, isFalse);

    env.service.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Quên mật khẩu: dialog có sẵn email đã nhập, kiểm tra định dạng, gửi xong báo SnackBar', (tester) async {
    await pumpLoginScreen(tester, env);
    await tester.enterText(emailField(), 'abc');

    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    final dialogField = find.descendant(of: dialog, matching: find.byType(TextFormField));
    expect(dialog, findsOneWidget);
    expect(fieldText(tester, dialogField), 'abc');

    await tester.tap(find.text('Gửi'));
    await tester.pump();
    expect(find.descendant(of: dialog, matching: find.text('Email không đúng định dạng')), findsOneWidget);

    await tester.enterText(dialogField, demoEmail);
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(find.text('Đã gửi hướng dẫn tới email'), findsOneWidget);
  });

  testWidgets('Quên mật khẩu: bấm Hủy thì đóng dialog, không báo gì', (tester) async {
    await pumpLoginScreen(tester, env);

    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('bấm "Đăng ký ngay" mở màn Đăng ký', (tester) async {
    await pumpLoginScreen(tester, env);

    await tester.tap(find.text('Đăng ký ngay'));
    await tester.pumpAndSettle();

    expect(find.text(registerLabel), findsOneWidget);
  });

  testWidgets('mở từ dialog requireLogin: có nút X; bấm X quay lại, requireLogin trả về false', (tester) async {
    await pumpLoginScreen(tester, env, entry: LoginEntry.requireLoginDialog);
    expect(find.byType(CloseButton), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.text(previousScreenLabel), findsOneWidget);
    expect(find.text(requireLoginResult(false)), findsOneWidget);
  });

  testWidgets('mở từ chỗ khác: nút Back thường, không có nút X', (tester) async {
    await pumpLoginScreen(tester, env, entry: LoginEntry.otherScreen);

    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(CloseButton), findsNothing);
  });

  testWidgets('mở thẳng: không có nút Back hay X', (tester) async {
    await pumpLoginScreen(tester, env);

    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(CloseButton), findsNothing);
  });
}
