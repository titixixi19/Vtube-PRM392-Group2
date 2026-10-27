import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_helpers.dart';

/// MÀN 3 · ĐĂNG KÝ · kiểm thử giao diện.
/// Chạy: cd mobile && flutter test test/features/auth/register_screen_ui_test.dart
void main() {
  late AuthTestEnv env;

  setUp(() => env = AuthTestEnv());

  testWidgets('hiển thị đủ các thành phần theo thiết kế', (tester) async {
    await pumpRegisterScreen(tester, env);

    expect(find.text('Tạo tài khoản'), findsOneWidget);
    expect(find.text('Bắt đầu hành trình sáng tạo'), findsOneWidget);
    expect(find.text('Chạm để tải ảnh đại diện'), findsOneWidget);
    for (final label in ['Họ và tên', 'Tên kênh', 'Handle', 'Địa chỉ Email', 'Mật khẩu', 'Xác nhận mật khẩu']) {
      expect(authField(label), findsOneWidget, reason: label);
    }
    expect(find.text('Bắt buộc'), findsOneWidget);
    expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('Điều khoản dịch vụ', findRichText: true), findsOneWidget);
    expect(registerButton(), findsOneWidget);
    expect(find.text('Đã có tài khoản?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Đăng nhập'), findsOneWidget);
  });

  testWidgets('đã bỏ "Bước 1/2" và khối "Đặc quyền tài khoản mới" của Stitch', (tester) async {
    await pumpRegisterScreen(tester, env);

    expect(find.textContaining('Bước 1/2'), findsNothing);
    expect(find.textContaining('Đặc quyền tài khoản mới'), findsNothing);
  });

  testWidgets('Tên kênh và Handle là 2 ô riêng, Handle có tiền tố @', (tester) async {
    await pumpRegisterScreen(tester, env);

    final handleInput = find.descendant(of: authField('Handle'), matching: find.byType(TextField));
    expect(tester.widget<TextField>(handleInput).decoration!.prefixText, '@');
    final channelInput = find.descendant(of: authField('Tên kênh'), matching: find.byType(TextField));
    expect(tester.widget<TextField>(channelInput).decoration!.prefixText, isNull);
  });

  testWidgets('chưa tick điều khoản: nút Đăng ký mờ và không bấm được', (tester) async {
    await pumpRegisterScreen(tester, env);
    double opacity() => tester
        .widget<AnimatedOpacity>(find.ancestor(of: registerButton(), matching: find.byType(AnimatedOpacity)))
        .opacity;
    bool enabled() => tester.widget<FilledButton>(registerButton()).enabled;

    expect(opacity(), 0.5);
    expect(enabled(), isFalse);

    await tapVisible(tester, find.byType(Checkbox));
    await tester.pump();
    expect(opacity(), 1);
    expect(enabled(), isTrue);
  });

  testWidgets('chọn ảnh đại diện: bottom sheet 2 lựa chọn, xem trước ảnh, có thể xóa', (tester) async {
    await pumpRegisterScreen(tester, env);

    await tester.tap(find.bySemanticsLabel('Chọn ảnh đại diện'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn từ thư viện'), findsOneWidget);
    expect(find.text('Xóa ảnh'), findsNothing, reason: 'Chưa có ảnh thì không có Xóa');

    await tester.tap(find.text('Chọn từ thư viện'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar-preview')), findsOneWidget);
    expect(find.text('Chạm để đổi ảnh đại diện'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Chọn ảnh đại diện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa ảnh'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar-preview')), findsNothing);
    expect(find.text('Chạm để tải ảnh đại diện'), findsOneWidget);
  });

  testWidgets('thanh độ mạnh mật khẩu cập nhật theo từng ký tự', (tester) async {
    await pumpRegisterScreen(tester, env);
    expect(find.textContaining('Độ mạnh'), findsNothing);

    await tester.enterText(authField('Mật khẩu'), 'abc');
    await tester.pump();
    expect(find.text('Độ mạnh: Yếu'), findsOneWidget);

    await tester.enterText(authField('Mật khẩu'), 'abc12345');
    await tester.pump();
    expect(find.text('Độ mạnh: Trung bình'), findsOneWidget);

    await tester.enterText(authField('Mật khẩu'), 'Abc12345!xyz');
    await tester.pump();
    expect(find.text('Độ mạnh: Mạnh'), findsOneWidget);
  });

  testWidgets('handle đã có người dùng: báo lỗi đỏ dưới ô', (tester) async {
    await pumpRegisterScreen(tester, env);

    await enterHandle(tester, takenHandle);

    expect(find.text('Đã có người sử dụng'), findsOneWidget);
    expect(find.byKey(const ValueKey('handle-available')), findsNothing);
  });

  testWidgets('handle còn trống: hiện dấu ✓ và "Có thể sử dụng"', (tester) async {
    await pumpRegisterScreen(tester, env);

    await enterHandle(tester, 'kenh.moi_2026');

    expect(find.byKey(const ValueKey('handle-available')), findsOneWidget);
    expect(find.text('Có thể sử dụng'), findsOneWidget);
    expect(find.text('Đã có người sử dụng'), findsNothing);
  });

  testWidgets('ô Handle tự đổi sang chữ thường, bỏ "@" và khoảng trắng', (tester) async {
    await pumpRegisterScreen(tester, env);

    await tester.enterText(authField('Handle'), '@My Kenh');
    await tester.pump();

    expect(fieldText(tester, authField('Handle')), 'mykenh');
  });

  testWidgets('bấm "Điều khoản dịch vụ" mở dialog nội dung', (tester) async {
    await pumpRegisterScreen(tester, env);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tapOnText(find.textRange.ofSubstring('Điều khoản dịch vụ'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, 'Điều khoản dịch vụ'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse, reason: 'Bấm link không tick ô');

    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('bấm sai: cuộn lên ô lỗi đầu tiên', (tester) async {
    await pumpRegisterScreen(tester, env);
    // Điền đủ trừ Họ tên (ô đầu tiên, ở trên cùng).
    await fillRegisterForm(tester, name: '');
    await tester.enterText(authField('Tên kênh'), 'Kênh Bình');

    await tapVisible(tester, registerButton());
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
    final nameTop = tester.getTopLeft(authField('Họ và tên')).dy;
    expect(nameTop, inInclusiveRange(0, 900), reason: 'Ô Họ tên phải nằm trong màn hình');
  });

  testWidgets('đang gửi: hiện vòng quay và khóa các ô', (tester) async {
    env.service.hold = Completer<void>();
    await pumpRegisterScreen(tester, env);
    await fillRegisterForm(tester);

    await tapVisible(tester, registerButton());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextFormField>(authField('Họ và tên')).enabled, isFalse);
    expect(tester.widget<TextFormField>(authField('Địa chỉ Email')).enabled, isFalse);

    env.service.hold!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Back khi đã nhập dở: hỏi "Hủy đăng ký?", chọn Tiếp tục nhập thì ở lại', (tester) async {
    await pumpRegisterScreen(tester, env, fromPreviousScreen: true);
    await tester.enterText(authField('Họ và tên'), 'Bình');
    await tester.pump(); // vẽ lại để PopScope nhận trạng thái "đã nhập dở"

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Hủy đăng ký?'), findsOneWidget);
    expect(find.text('Thông tin đã nhập sẽ bị mất.'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo tài khoản'), findsOneWidget);
    expect(fieldText(tester, authField('Họ và tên')), 'Bình');
  });

  testWidgets('Back khi đã nhập dở: chọn Hủy đăng ký thì rời màn', (tester) async {
    await pumpRegisterScreen(tester, env, fromPreviousScreen: true);
    await tester.enterText(authField('Họ và tên'), 'Bình');
    await tester.pump(); // vẽ lại để PopScope nhận trạng thái "đã nhập dở"

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hủy đăng ký'));
    await tester.pumpAndSettle();

    expect(find.text(previousScreenLabel), findsOneWidget);
  });

  testWidgets('Back khi chưa nhập gì: rời màn ngay, không hỏi', (tester) async {
    await pumpRegisterScreen(tester, env, fromPreviousScreen: true);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Hủy đăng ký?'), findsNothing);
    expect(find.text(previousScreenLabel), findsOneWidget);
  });
}
