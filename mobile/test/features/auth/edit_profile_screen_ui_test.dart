import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/features/auth/widgets/avatar_picker.dart';

import 'edit_profile_test_helpers.dart';

/// MÀN 17 (mở rộng) · CHỈNH SỬA HỒ SƠ · kiểm thử giao diện.
/// Chạy: cd mobile && flutter test test/features/auth/edit_profile_screen_ui_test.dart
void main() {
  late EditProfileTestEnv env;

  setUp(() => env = EditProfileTestEnv());

  group('Hiển thị', () {
    testWidgets('đủ các thành phần, các ô điền sẵn thông tin hiện tại', (tester) async {
      await pumpEditProfile(tester, env);

      expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
      expect(find.text('Thêm ảnh bìa kênh'), findsOneWidget);
      expect(find.text('Chạm để tải ảnh đại diện'), findsOneWidget);
      expect(fieldText(tester, 'Tên hiển thị'), profileName);
      expect(fieldText(tester, 'Tên kênh'), profileChannelName);
      expect(fieldText(tester, 'Mô tả kênh'), profileDescription);
      expect(saveButton(), findsOneWidget);
    });

    testWidgets('handle và email chỉ hiển thị, có biểu tượng khóa và lý do', (tester) async {
      await pumpEditProfile(tester, env);

      expect(find.text('@$profileHandle'), findsOneWidget);
      expect(find.text(profileEmail), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(find.textContaining('không thể thay đổi'), findsOneWidget);
      // Không có ô nhập cho handle / email.
      expect(profileField('Handle'), findsNothing);
      expect(profileField('Email'), findsNothing);
    });

    testWidgets('ô Mô tả nhiều dòng, có bộ đếm ký tự tối đa 1000', (tester) async {
      await pumpEditProfile(tester, env);

      final input =
          tester.widget<TextField>(find.descendant(of: profileField('Mô tả kênh'), matching: find.byType(TextField)));
      expect(input.maxLines, greaterThan(1));
      expect(input.maxLength, 1000);
      expect(find.text('${profileDescription.length}/1000'), findsOneWidget);
    });
  });

  group('Trạng thái tải', () {
    testWidgets('đang tải thông tin kênh: hiện vòng quay, chưa có form', (tester) async {
      env.channels.getHold = Completer<void>();
      await pumpEditProfile(tester, env, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(profileField('Tên hiển thị'), findsNothing);

      env.channels.getHold!.complete();
      await tester.pumpAndSettle();
      expect(profileField('Tên hiển thị'), findsOneWidget);
    });

    testWidgets('tải lỗi: báo lỗi + "Thử lại"; bấm Thử lại thì hiện form', (tester) async {
      env.channels.getError = networkError;
      await pumpEditProfile(tester, env);

      expect(find.text('Đã xảy ra lỗi'), findsOneWidget);
      expect(find.text(networkError.message), findsOneWidget);
      expect(profileField('Tên hiển thị'), findsNothing);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(env.channels.getCalls, [profileChannelId, profileChannelId]);
      expect(fieldText(tester, 'Tên hiển thị'), profileName);
    });

    testWidgets('phiên đăng nhập hết khi đang ở màn: mời đăng nhập lại', (tester) async {
      await pumpEditProfile(tester, env);

      await env.auth.logout();
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa đăng nhập'), findsOneWidget);
      expect(saveButton(), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text(loginLabel), findsOneWidget);
    });
  });

  group('Nút Lưu', () {
    testWidgets('chưa đổi gì thì mờ; sửa thì bật; sửa về như cũ thì mờ lại', (tester) async {
      await pumpEditProfile(tester, env);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(profileField('Tên hiển thị'), 'Tên mới');
      await tester.pump();
      expect(saveEnabled(tester), isTrue);

      await tester.enterText(profileField('Tên hiển thị'), profileName);
      await tester.pump();
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('chỉ thêm khoảng trắng hai đầu: không tính là thay đổi', (tester) async {
      await pumpEditProfile(tester, env);

      await tester.enterText(profileField('Tên kênh'), '  $profileChannelName  ');
      await tester.pump();
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('đang lưu: vòng quay thay nút Lưu, các ô bị khóa', (tester) async {
      env.authService.hold = Completer<void>();
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên hiển thị'), 'Tên mới');
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pump();

      expect(saveButton(), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<TextFormField>(profileField('Tên hiển thị')).enabled, isFalse);

      env.authService.hold!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('Ảnh', () {
    testWidgets('chọn ảnh đại diện: xem trước ngay, chữ đổi thành "Chạm để đổi"', (tester) async {
      await pumpEditProfile(tester, env);

      await chooseImage(tester, banner: false);

      expect(find.byKey(const ValueKey('avatar-preview')), findsOneWidget);
      expect(find.text('Chạm để đổi ảnh đại diện'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('chọn ảnh bìa: xem trước ngay', (tester) async {
      await pumpEditProfile(tester, env);

      await chooseImage(tester, banner: true);

      expect(find.byKey(const ValueKey('banner-preview')), findsOneWidget);
      expect(find.text('Thêm ảnh bìa kênh'), findsNothing);
    });

    testWidgets('"Dùng lại ảnh cũ" chỉ có khi đã chọn ảnh mới, bấm thì bỏ ảnh vừa chọn', (tester) async {
      await pumpEditProfile(tester, env);

      await tapVisible(tester, find.descendant(of: find.byType(AvatarPicker), matching: find.byType(InkWell)));
      expect(find.text('Dùng lại ảnh cũ'), findsNothing);
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      await chooseImage(tester, banner: false, option: 'Dùng lại ảnh cũ');

      expect(find.byKey(const ValueKey('avatar-preview')), findsNothing);
      expect(saveEnabled(tester), isFalse);
    });
  });

  group('Rời màn', () {
    testWidgets('chưa đổi gì: Back về màn trước ngay, không hỏi', (tester) async {
      await pumpEditProfile(tester, env);

      await tester.tap(backButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(previousLabel), findsOneWidget);
    });

    testWidgets('có thay đổi: Back hỏi "Bỏ thay đổi?"; Tiếp tục sửa thì ở lại, Bỏ thay đổi thì về', (tester) async {
      await pumpEditProfile(tester, env);
      await tester.enterText(profileField('Tên hiển thị'), 'Tên mới');
      await tester.pump();

      await tester.tap(backButton());
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsOneWidget);

      await tester.tap(find.text('Tiếp tục sửa'));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Tên hiển thị'), 'Tên mới');

      await tester.tap(backButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Bỏ thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text(previousLabel), findsOneWidget);
      expect(env.authService.updateCalls, isEmpty);
    });
  });
}
