import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/features/auth/auth_validators.dart';

import 'auth_test_helpers.dart';

/// MÀN 3 · ĐĂNG KÝ · kiểm thử logic nghiệp vụ.
/// Chạy: cd mobile && flutter test test/features/auth/register_screen_logic_test.dart
void main() {
  group('Quy tắc kiểm tra dữ liệu', () {
    test('Họ tên: bắt buộc, 2–50 ký tự (không tính khoảng trắng hai đầu)', () {
      expect(AuthValidators.displayName(''), 'Vui lòng nhập họ tên');
      expect(AuthValidators.displayName('   '), 'Vui lòng nhập họ tên');
      expect(AuthValidators.displayName('A'), 'Họ tên phải từ 2 đến 50 ký tự');
      expect(AuthValidators.displayName(' A '), 'Họ tên phải từ 2 đến 50 ký tự');
      expect(AuthValidators.displayName('a' * 51), 'Họ tên phải từ 2 đến 50 ký tự');
      expect(AuthValidators.displayName('An'), isNull);
      expect(AuthValidators.displayName('a' * 50), isNull);
    });

    test('Tên kênh: bắt buộc, 2–50 ký tự', () {
      expect(AuthValidators.channelName(''), 'Vui lòng nhập tên kênh');
      expect(AuthValidators.channelName('K'), 'Tên kênh phải từ 2 đến 50 ký tự');
      expect(AuthValidators.channelName('Kênh Bình'), isNull);
    });

    test('Handle: 3–30 ký tự, chỉ chữ thường, số, "." và "_"', () {
      expect(AuthValidators.handle(''), 'Vui lòng nhập handle');
      for (final bad in ['ab', 'a' * 31, 'Binh', 'binh tran', 'binh-tran', 'bình', '@binh']) {
        expect(AuthValidators.handle(bad), isNotNull, reason: bad);
      }
      for (final ok in ['abc', 'a' * 30, 'binh.tran_99', '_x.']) {
        expect(AuthValidators.handle(ok), isNull, reason: ok);
      }
    });

    test('Mật khẩu đăng ký: từ 8 ký tự, có cả chữ và số', () {
      expect(AuthValidators.registerPassword(''), 'Vui lòng nhập mật khẩu');
      expect(AuthValidators.registerPassword('abc1234'), 'Mật khẩu phải có ít nhất 8 ký tự');
      expect(AuthValidators.registerPassword('abcdefgh'), 'Mật khẩu phải có cả chữ và số');
      expect(AuthValidators.registerPassword('12345678'), 'Mật khẩu phải có cả chữ và số');
      expect(AuthValidators.registerPassword('matkhau1'), isNull);
    });

    test('Xác nhận mật khẩu phải trùng mật khẩu', () {
      expect(AuthValidators.confirmPassword('', 'matkhau1'), 'Vui lòng nhập lại mật khẩu');
      expect(AuthValidators.confirmPassword('matkhau2', 'matkhau1'), 'Mật khẩu xác nhận không khớp');
      expect(AuthValidators.confirmPassword('matkhau1', 'matkhau1'), isNull);
    });

    test('Độ mạnh mật khẩu: chưa đạt yêu cầu là Yếu, đạt là Trung bình, thêm 2 điểm cộng là Mạnh', () {
      expect(AuthValidators.passwordStrength(''), PasswordStrength.none);
      expect(AuthValidators.passwordStrength('abc'), PasswordStrength.weak);
      expect(AuthValidators.passwordStrength('Abcdefgh!@#xyz'), PasswordStrength.weak, reason: 'Không có số');
      expect(AuthValidators.passwordStrength('matkhau1'), PasswordStrength.medium);
      expect(AuthValidators.passwordStrength('Matkhau1'), PasswordStrength.medium, reason: 'Mới 1 điểm cộng');
      expect(AuthValidators.passwordStrength('Matkhau1!'), PasswordStrength.strong);
      expect(AuthValidators.passwordStrength('matkhau123456!'), PasswordStrength.strong);
    });
  });

  group('AuthProvider.register', () {
    late AuthTestEnv env;

    setUp(() => env = AuthTestEnv());

    test('thành công: đăng nhập luôn, lưu token', () async {
      await env.auth.register(displayName: 'Bình', handle: 'binhtran', email: 'binh@vtube.vn', password: 'matkhau1');

      expect(env.auth.isLoggedIn, isTrue);
      expect(env.auth.user!.email, 'binh@vtube.vn');
      expect((await SharedPreferences.getInstance()).getString('auth_token'), newUserToken);
    });

    test('email trùng (409): ném ApiException, vẫn là khách', () async {
      await expectLater(
        env.auth.register(displayName: 'Bình', handle: 'binhtran', email: demoEmail, password: 'matkhau1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
      expect(env.auth.isLoggedIn, isFalse);
      expect(env.tokens.token, isNull);
    });
  });

  group('Luồng màn Đăng ký', () {
    late AuthTestEnv env;

    setUp(() => env = AuthTestEnv());

    testWidgets('Tên kênh tự điền theo Họ tên cho tới khi người dùng tự sửa', (tester) async {
      await pumpRegisterScreen(tester, env);
      final name = authField('Họ và tên');
      final channel = authField('Tên kênh');

      await tester.enterText(name, 'Trần Bình');
      expect(fieldText(tester, channel), 'Trần Bình');

      await tester.enterText(channel, 'Bình Vlog');
      await tester.enterText(name, 'Trần Văn Bình');
      expect(fieldText(tester, channel), 'Bình Vlog', reason: 'Đã sửa tay thì không ghi đè');

      await tester.enterText(channel, '');
      await tester.enterText(name, 'Bình Trần');
      expect(fieldText(tester, channel), 'Bình Trần', reason: 'Xóa trắng thì tự điền lại');
    });

    testWidgets('kiểm tra handle sau khi ngừng gõ 500 ms, chỉ gọi 1 lần cho chữ cuối', (tester) async {
      await pumpRegisterScreen(tester, env);
      final handle = authField('Handle');

      await tester.enterText(handle, 'vte');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(handle, 'vtech');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(handle, takenHandle);
      await tester.pump(const Duration(milliseconds: 499));
      expect(env.service.handleChecks, isEmpty, reason: 'Chưa đủ 500 ms kể từ lần gõ cuối');

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(env.service.handleChecks, [takenHandle]);
    });

    testWidgets('handle chưa đúng định dạng thì không gọi API kiểm tra', (tester) async {
      await pumpRegisterScreen(tester, env);

      await enterHandle(tester, 'ab');

      expect(env.service.handleChecks, isEmpty);
    });

    testWidgets('form chưa hợp lệ: không upload, không gọi đăng ký', (tester) async {
      await pumpRegisterScreen(tester, env);
      await fillRegisterForm(tester, password: 'matkhau1', confirm: 'matkhau2');

      await tapVisible(tester, registerButton());
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
      expect(env.service.registerCalls, isEmpty);
      expect(env.upload.uploads, isEmpty);
    });

    testWidgets('handle đã có người dùng: chặn đăng ký, không gọi API', (tester) async {
      await pumpRegisterScreen(tester, env);
      await fillRegisterForm(tester, handle: takenHandle);

      await tapVisible(tester, registerButton());
      await tester.pumpAndSettle();

      expect(env.service.registerCalls, isEmpty);
      expect(find.text('Đã có người sử dụng'), findsOneWidget);
    });

    testWidgets('đăng ký thành công không có ảnh: gửi dữ liệu đã cắt khoảng trắng, vào Trang chủ', (tester) async {
      await pumpRegisterScreen(tester, env);
      await fillRegisterForm(tester, name: '  Trần Văn Bình ', email: ' binh@vtube.vn ');

      await tapVisible(tester, registerButton());
      await tester.pumpAndSettle();

      final call = env.service.registerCalls.single;
      expect(call.displayName, 'Trần Văn Bình');
      expect(call.channelName, 'Trần Văn Bình');
      expect(call.handle, 'binhtran');
      expect(call.email, 'binh@vtube.vn');
      expect(call.password, 'matkhau123');
      expect(call.avatarUrl, isNull);
      expect(env.upload.uploads, isEmpty);
      expect(env.auth.isLoggedIn, isTrue);
      expect(find.text('Tạo tài khoản thành công'), findsOneWidget);
      expect(find.text(homeLabel), findsOneWidget);
    });

    testWidgets('có ảnh đại diện: upload ảnh trước rồi gửi url khi đăng ký', (tester) async {
      await pumpRegisterScreen(tester, env);
      await tester.tap(find.bySemanticsLabel('Chọn ảnh đại diện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chụp ảnh'));
      await tester.pumpAndSettle();
      expect(env.pickedSources, [ImageSource.camera]);

      await fillRegisterForm(tester);
      await tapVisible(tester, registerButton());
      await tester.pumpAndSettle();

      expect(env.upload.uploads, [('avatar.png', 'image')]);
      expect(env.service.registerCalls.single.avatarUrl, uploadedAvatarUrl);
      expect(env.auth.user!.avatarUrl, uploadedAvatarUrl);
    });

    testWidgets('hủy chọn ảnh: giữ nguyên trạng thái chưa có ảnh', (tester) async {
      env.pickResult = null;
      await pumpRegisterScreen(tester, env);

      await tester.tap(find.bySemanticsLabel('Chọn ảnh đại diện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      expect(env.pickedSources, [ImageSource.gallery]);
      expect(find.text('Chạm để tải ảnh đại diện'), findsOneWidget);
    });

    testWidgets('email trùng (409): lỗi dưới ô Email, sửa thì hết lỗi, gửi lại không upload ảnh lần 2', (tester) async {
      await pumpRegisterScreen(tester, env);
      await tester.tap(find.bySemanticsLabel('Chọn ảnh đại diện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();
      await fillRegisterForm(tester, email: demoEmail);

      await tapVisible(tester, registerButton());
      await tester.pumpAndSettle();

      expect(find.text('Email đã được sử dụng'), findsOneWidget);
      expect(env.auth.isLoggedIn, isFalse);
      expect(find.text('Tạo tài khoản'), findsOneWidget, reason: 'Vẫn ở màn Đăng ký');

      await tester.enterText(authField('Địa chỉ Email'), 'binh@vtube.vn');
      await tester.pump();
      expect(find.text('Email đã được sử dụng'), findsNothing);

      await tapVisible(tester, registerButton());
      await tester.pumpAndSettle();
      expect(env.service.registerCalls, hasLength(2));
      expect(env.upload.uploads, hasLength(1), reason: 'Ảnh đã upload ở lần trước');
      expect(env.auth.isLoggedIn, isTrue);
    });

    testWidgets('không kiểm tra được handle (mất mạng): vẫn cho gửi, server báo trùng thì lỗi dưới ô Handle',
        (tester) async {
      env.service.handleCheckFails = true;
      await pumpRegisterScreen(tester, env);
      await fillRegisterForm(tester, handle: takenHandle);
      expect(find.text('Đã có người sử dụng'), findsNothing);

      await tapVisible(tester, registerButton());
      await tester.pumpAndSettle();

      expect(env.service.registerCalls, hasLength(1));
      expect(errorUnder('Handle', 'Handle @$takenHandle đã có người sử dụng'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing, reason: 'Lỗi 409 hiện dưới ô, không phải SnackBar');
      expect(env.auth.isLoggedIn, isFalse);
    });

    testWidgets('đang gửi thì Back không rời màn (tránh tạo tài khoản ngầm), gửi xong vào Trang chủ', (tester) async {
      env.service.hold = Completer<void>();
      await pumpRegisterScreen(tester, env, fromPreviousScreen: true);
      await fillRegisterForm(tester);
      await tapVisible(tester, registerButton());
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(find.text('Hủy đăng ký?'), findsNothing, reason: 'Không hỏi hủy khi đang gửi');
      expect(find.text('Tạo tài khoản'), findsOneWidget);

      env.service.hold!.complete();
      await tester.pumpAndSettle();
      expect(env.auth.isLoggedIn, isTrue);
      expect(find.text(homeLabel), findsOneWidget);
    });

    testWidgets('đọc file ảnh lỗi (không phải lỗi API): báo SnackBar, không gọi đăng ký', (tester) async {
      env.upload.error = UnsupportedError('Không đọc được file');
      await pumpRegisterScreen(tester, env);
      await tester.tap(find.bySemanticsLabel('Chọn ảnh đại diện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();
      await fillRegisterForm(tester);

      await tapVisible(tester, registerButton());
      await tester.pumpAndSettle();

      expect(find.text('Không tải được ảnh đại diện, hãy chọn ảnh khác'), findsOneWidget);
      expect(env.service.registerCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Đã có tài khoản? Đăng nhập" khi đã nhập dở: hỏi lại rồi quay về màn Đăng nhập', (tester) async {
      await pumpLoginScreen(tester, env);
      await tester.tap(find.text('Đăng ký ngay'));
      await tester.pumpAndSettle();
      await tester.enterText(authField('Họ và tên'), 'Bình');
      await tester.pump(); // vẽ lại để PopScope nhận trạng thái "đã nhập dở"

      await tapVisible(tester, find.widgetWithText(TextButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy đăng ký?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Hủy đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('để tiếp tục với VTube'), findsOneWidget);
    });
  });
}
