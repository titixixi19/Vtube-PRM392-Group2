import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/app/theme.dart';

import 'account_test_helpers.dart';

/// MÀN 4 · TRANG "BẠN" · kiểm thử giao diện.
/// Chạy: cd mobile && flutter test test/features/auth/account_screen_ui_test.dart
void main() {
  late AccountTestEnv env;

  setUp(() => env = AccountTestEnv());

  group('Khách (chưa đăng nhập)', () {
    testWidgets('màn mời đăng nhập: icon lớn, lời mời, nút Đăng nhập; vẫn có Cài đặt, Trợ giúp', (tester) async {
      await pumpAccount(tester, env, signedIn: false);

      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
      expect(find.text('Tận hưởng các video yêu thích'), findsOneWidget);
      expect(find.text('Đăng nhập để xem video đã thích, lịch sử và hơn thế nữa'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
      expect(find.text('Cài đặt'), findsOneWidget);
      expect(find.text('Trợ giúp & phản hồi'), findsOneWidget);
    });

    testWidgets('khách không thấy phần của tài khoản và không gọi API cá nhân', (tester) async {
      await pumpAccount(tester, env, signedIn: false);

      for (final text in ['Nhật ký xem', 'Danh sách phát', 'Video của bạn', 'Đăng xuất']) {
        expect(find.text(text), findsNothing, reason: text);
      }
      expect(env.history.sizes, isEmpty);
      expect(env.playlists.mineCalls, 0);
    });
  });

  group('Đã đăng nhập', () {
    testWidgets('app bar: logo "VTube" một lần, không có banner Premium của Stitch', (tester) async {
      await pumpAccount(tester, env);

      expect(find.text('VTube'), findsOneWidget);
      expect(find.textContaining('Premium'), findsNothing);
    });

    testWidgets('header: tên, "@handle · Xem kênh", số người đăng ký, 2 chip tài khoản', (tester) async {
      await pumpAccount(tester, env);

      expect(find.text(accountName), findsOneWidget);
      expect(find.text('@$accountHandle · Xem kênh'), findsOneWidget);
      expect(find.text('1,2 N người đăng ký'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Chuyển đổi tài khoản'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Tài khoản Google'), findsOneWidget);
    });

    testWidgets('Nhật ký xem: hàng cuộn ngang, có thanh tiến độ đỏ đúng tỉ lệ đã xem', (tester) async {
      env.history.items = [sampleHistory(1, progress: 150), sampleHistory(2, progress: 600)]; // video dài 600 giây
      await pumpAccount(tester, env);

      expect(find.text('Nhật ký xem'), findsOneWidget);
      expect(find.text('Xem tất cả'), findsOneWidget);
      expect(find.text('Video số 1'), findsOneWidget);
      final bars = tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).toList();
      expect(bars.map((b) => b.value), [0.25, 1.0]);
      expect(bars.first.color, AppColors.accent);
      final row = find.ancestor(of: find.text('Video số 1'), matching: find.byType(SingleChildScrollView)).first;
      expect(tester.widget<SingleChildScrollView>(row).scrollDirection, Axis.horizontal);
    });

    testWidgets('Danh sách phát: thẻ có tên, "n video · chế độ", icon theo loại; có nút +', (tester) async {
      await pumpAccount(tester, env);

      expect(find.text('Danh sách phát'), findsOneWidget);
      expect(find.byTooltip('Tạo danh sách phát'), findsOneWidget);
      expect(find.text('5 video · Riêng tư'), findsOneWidget);
      expect(find.text('Xem sau'), findsOneWidget);
      expect(find.text('2 video · Riêng tư'), findsOneWidget);
      expect(find.text('Học Flutter'), findsOneWidget);
      expect(find.text('3 video · Công khai'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_outlined), findsNWidgets(2)); // thẻ Video đã thích + mục menu
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('danh sách mục: đủ mục theo đặc tả, Đăng xuất chữ đỏ ở cuối', (tester) async {
      await pumpAccount(tester, env);

      for (final text in ['Video của bạn', 'Video đã tải xuống', 'Cài đặt', 'Trợ giúp & phản hồi']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('5 video bạn đã thích'), findsOneWidget, reason: 'Mục Video đã thích lấy số từ playlist liked');
      final logout = tester.widget<Text>(find.text('Đăng xuất'));
      expect(logout.style!.color, AppColors.accent);
      expect(tester.getTopLeft(find.text('Đăng xuất')).dy,
          greaterThan(tester.getTopLeft(find.text('Trợ giúp & phản hồi')).dy));
    });

    testWidgets('đang tải: mỗi hàng có vòng quay riêng', (tester) async {
      env.history.hold = Completer<void>();
      await pumpAccount(tester, env, settle: false);

      expect(find.byKey(const ValueKey('history-loading')), findsOneWidget);
      expect(find.text('Học Flutter'), findsOneWidget, reason: 'Hàng playlist không phải chờ hàng lịch sử');

      env.history.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-loading')), findsNothing);
      expect(find.text('Video số 1'), findsOneWidget);
    });

    testWidgets('lịch sử trống: câu hướng dẫn thay cho hàng video', (tester) async {
      env.history.items = [];
      await pumpAccount(tester, env);

      expect(find.text('Video bạn xem sẽ hiện ở đây'), findsOneWidget);
    });

    testWidgets('một hàng lỗi: hiện lỗi + Thử lại ở đúng hàng đó, phần còn lại vẫn hiển thị', (tester) async {
      env.history.error = networkError;
      await pumpAccount(tester, env);

      expect(find.text(networkError.message), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Thử lại'), findsOneWidget);
      expect(find.text('Học Flutter'), findsOneWidget);
      expect(find.text(accountName), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
    });

    testWidgets('dialog tạo playlist: ô tên tối đa 150 ký tự và 3 chế độ, mặc định Riêng tư', (tester) async {
      await pumpAccount(tester, env);

      await tester.tap(find.byTooltip('Tạo danh sách phát'));
      await tester.pumpAndSettle();

      expect(inDialog('Danh sách phát mới'), findsOneWidget);
      expect(tester.widget<TextField>(find.descendant(of: dialogField(), matching: find.byType(TextField))).maxLength,
          150);
      for (final label in ['Công khai', 'Không công khai', 'Riêng tư']) {
        expect(inDialog(label), findsOneWidget, reason: label);
      }
      final selected = tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue;
      expect(selected, 'private');
    });

    testWidgets('nhấn giữ playlist tự tạo: menu Đổi tên, Xóa', (tester) async {
      await pumpAccount(tester, env);

      await longPressPlaylist(tester, 'Học Flutter');

      expect(find.text('Đổi tên'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);
    });

    testWidgets('nhấn giữ playlist hệ thống (Xem sau): không có menu', (tester) async {
      await pumpAccount(tester, env);

      await longPressPlaylist(tester, 'Xem sau');

      expect(find.text('Đổi tên'), findsNothing);
      expect(find.text('Xóa'), findsNothing);
    });

    testWidgets('Chuyển đổi tài khoản: bottom sheet có tài khoản hiện tại và "Đăng nhập tài khoản khác"',
        (tester) async {
      await pumpAccount(tester, env);

      await tester.tap(find.text('Chuyển đổi tài khoản'));
      await tester.pumpAndSettle();

      expect(find.text(accountEmail), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Đăng nhập tài khoản khác'), findsOneWidget);
    });
  });
}
