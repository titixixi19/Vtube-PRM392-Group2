import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/features/auth/auth_validators.dart';

import 'edit_profile_test_helpers.dart';

/// MÀN 17 (mở rộng) · CHỈNH SỬA HỒ SƠ · kiểm thử logic nghiệp vụ.
/// Chạy: cd mobile && flutter test test/features/auth/edit_profile_screen_logic_test.dart
void main() {
  group('Quy tắc kiểm tra dữ liệu', () {
    test('Mô tả kênh: không bắt buộc, tối đa 1000 ký tự (không tính khoảng trắng hai đầu)', () {
      expect(AuthValidators.channelDescription(''), isNull);
      expect(AuthValidators.channelDescription(null), isNull);
      expect(AuthValidators.channelDescription('a' * 1000), isNull);
      expect(AuthValidators.channelDescription('  ${'a' * 1000}  '), isNull);
      expect(AuthValidators.channelDescription('a' * 1001), 'Mô tả tối đa 1000 ký tự');
    });
  });

  group('Tải dữ liệu', () {
    late EditProfileTestEnv env;
    setUp(() => env = EditProfileTestEnv());

    testWidgets('mở màn: tải đúng kênh của tài khoản đang đăng nhập', (tester) async {
      await pumpEditProfile(tester, env);

      expect(env.channels.getCalls, [profileChannelId]);
    });

    testWidgets('đổi tài khoản lúc đang tải: tải lại cho tài khoản mới, kết quả muộn của tài khoản cũ bị bỏ qua',
        (tester) async {
      final firstLoad = env.channels.getHold = Completer<void>();
      await pumpEditProfile(tester, env, settle: false);

      // Tài khoản cũ hết phiên, đăng nhập tài khoản khác khi lần tải đầu còn chưa xong.
      await env.auth.logout();
      env.channels.getHold = null;
      env.authService
        ..userId = 2
        ..displayName = 'Người dùng B';
      await env.auth.login('b@vtube.vn', '123456');
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Tên hiển thị'), 'Người dùng B');

      firstLoad.complete();
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Tên hiển thị'), 'Người dùng B');
      expect(env.channels.getCalls, hasLength(2));
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('kênh chưa có mô tả: ô Mô tả để trống', (tester) async {
      env.channels.description = null;
      await pumpEditProfile(tester, env);

      expect(fieldText(tester, 'Mô tả kênh'), '');
      expect(saveEnabled(tester), isFalse);
    });
  });

  group('Lưu: chỉ gửi phần đã đổi', () {
    late EditProfileTestEnv env;
    setUp(() => env = EditProfileTestEnv());

    testWidgets('chỉ đổi tên hiển thị: gọi updateMe, không gọi updateMine, không upload', (tester) async {
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên hiển thị'), '  Trần Văn Bình  ');
      await tester.pump();

      await save(tester);

      expect(env.authService.updateCalls, [(displayName: 'Trần Văn Bình', avatarUrl: null)]);
      expect(env.channels.updateCalls, isEmpty);
      expect(env.upload.uploads, isEmpty);
    });

    testWidgets('lưu xong: tải lại tài khoản, báo "Đã lưu thay đổi", về màn trước', (tester) async {
      await pumpEditProfile(tester, env);
      final meCallsBefore = env.authService.meCalls;
      await tester.enterText(profileField('Tên hiển thị'), 'Trần Văn Bình');
      await tester.pump();

      await save(tester);

      expect(env.authService.meCalls, meCallsBefore + 1);
      expect(env.auth.user!.displayName, 'Trần Văn Bình');
      expect(find.text('Đã lưu thay đổi'), findsOneWidget);
      expect(find.text(previousLabel), findsOneWidget);
    });

    testWidgets('chỉ đổi tên kênh và mô tả: gọi updateMine, không gọi updateMe', (tester) async {
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên kênh'), 'Kênh Flutter');
      await tester.enterText(profileField('Mô tả kênh'), 'Mô tả mới');
      await tester.pump();

      await save(tester);

      expect(env.authService.updateCalls, isEmpty);
      expect(env.channels.updateCalls,
          [(name: 'Kênh Flutter', description: 'Mô tả mới', avatarUrl: null, bannerUrl: null)]);
    });

    testWidgets('chỉ đổi mô tả: tên kênh gửi null (giữ nguyên)', (tester) async {
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Mô tả kênh'), 'Mô tả mới');
      await tester.pump();

      await save(tester);

      expect(env.channels.updateCalls.single.name, isNull);
      expect(env.channels.updateCalls.single.description, 'Mô tả mới');
    });

    testWidgets('xóa trắng mô tả: gửi chuỗi rỗng để xóa (khác null là giữ nguyên)', (tester) async {
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Mô tả kênh'), '   ');
      await tester.pump();

      await save(tester);

      expect(env.channels.updateCalls.single.description, '');
      expect(env.channels.description, '');
    });

    testWidgets('đổi ảnh đại diện: upload 1 lần (type image) rồi gửi url qua updateMe', (tester) async {
      await pumpEditProfile(tester, env);
      await chooseImage(tester, banner: false);

      await save(tester);

      expect(env.picks, [(false, ImageSource.gallery)]);
      expect(env.upload.uploads, [('photo.png', 'image')]);
      expect(env.authService.updateCalls, [(displayName: null, avatarUrl: '/uploads/img-1.png')]);
      expect(env.channels.updateCalls, isEmpty, reason: 'Avatar tự đồng bộ sang kênh ở backend');
      expect(env.auth.user!.avatarUrl, '/uploads/img-1.png');
    });

    testWidgets('đổi ảnh bìa bằng camera: upload rồi gửi bannerUrl qua updateMine', (tester) async {
      await pumpEditProfile(tester, env);
      await chooseImage(tester, banner: true, option: 'Chụp ảnh');

      await save(tester);

      expect(env.picks, [(true, ImageSource.camera)]);
      expect(env.channels.updateCalls,
          [(name: null, description: null, avatarUrl: null, bannerUrl: '/uploads/img-1.png')]);
      expect(env.authService.updateCalls, isEmpty);
    });
  });

  group('Kiểm tra trước khi lưu', () {
    late EditProfileTestEnv env;
    setUp(() => env = EditProfileTestEnv());

    testWidgets('tên hiển thị quá ngắn: báo lỗi dưới ô, không gọi API', (tester) async {
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên hiển thị'), 'A');
      await tester.pump();

      await save(tester);

      expect(errorUnder('Tên hiển thị', 'Họ tên phải từ 2 đến 50 ký tự'), findsOneWidget);
      expect(env.authService.updateCalls, isEmpty);
      expect(env.channels.updateCalls, isEmpty);
    });

    testWidgets('xóa trắng tên kênh: báo lỗi dưới ô, không gọi API', (tester) async {
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên kênh'), '');
      await tester.pump();

      await save(tester);

      expect(errorUnder('Tên kênh', 'Vui lòng nhập tên kênh'), findsOneWidget);
      expect(env.channels.updateCalls, isEmpty);
    });
  });

  group('Lỗi khi lưu', () {
    late EditProfileTestEnv env;
    setUp(() => env = EditProfileTestEnv());

    testWidgets('upload ảnh lỗi (đọc file hỏng): báo gọn, chưa đổi gì trên server, ở lại màn', (tester) async {
      env.upload.error = const FileSystemLikeError();
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên hiển thị'), 'Tên mới');
      await chooseImage(tester, banner: false);

      await save(tester);

      expect(find.text('Không tải được ảnh đại diện, hãy chọn ảnh khác'), findsOneWidget);
      expect(env.authService.updateCalls, isEmpty, reason: 'Upload trước, lỗi thì chưa gửi gì');
      expect(fieldText(tester, 'Tên hiển thị'), 'Tên mới');
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('lỗi API: hiện đúng thông báo của server, giữ nguyên dữ liệu đã nhập', (tester) async {
      env.authService.updateError = const ApiException('Tên hiển thị không hợp lệ', statusCode: 400);
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên hiển thị'), 'Tên mới');
      await tester.pump();

      await save(tester);

      expect(find.text('Tên hiển thị không hợp lệ'), findsOneWidget);
      expect(fieldText(tester, 'Tên hiển thị'), 'Tên mới');
      expect(find.text(previousLabel), findsNothing);
    });

    testWidgets('hồ sơ lưu được, kênh lỗi: bấm Lưu lại chỉ gửi phần kênh, không upload lại ảnh', (tester) async {
      env.channels.updateError = networkError;
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên hiển thị'), 'Tên mới');
      await chooseImage(tester, banner: true);

      await save(tester);
      expect(find.text(networkError.message), findsOneWidget);
      expect(env.authService.updateCalls, hasLength(1));
      expect(env.auth.user!.displayName, 'Tên mới', reason: 'Phần đã lưu được cập nhật ngay');
      expect(saveEnabled(tester), isTrue, reason: 'Ảnh bìa vẫn chưa lưu');

      await save(tester);
      expect(env.authService.updateCalls, hasLength(1), reason: 'Tên đã lưu, không gửi lại');
      expect(env.upload.uploads, hasLength(1), reason: 'Dùng lại url đã upload');
      expect(env.channels.updateCalls.last.bannerUrl, '/uploads/img-1.png');
      expect(find.text(previousLabel), findsOneWidget);
    });

    testWidgets('không mở được camera: báo lỗi, không đổi ảnh', (tester) async {
      env.pickFails = true;
      await pumpEditProfile(tester, env);

      await chooseImage(tester, banner: false, option: 'Chụp ảnh');

      expect(find.text('Không mở được camera'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('hủy chọn ảnh: không có gì thay đổi', (tester) async {
      env.pickResult = null;
      await pumpEditProfile(tester, env);

      await chooseImage(tester, banner: true);

      expect(find.byKey(const ValueKey('banner-preview')), findsNothing);
      expect(saveEnabled(tester), isFalse);
    });
  });
}

/// Lỗi không phải ApiException (vd. đọc file ảnh hỏng).
class FileSystemLikeError implements Exception {
  const FileSystemLikeError();
}
