import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/features/auth/account_screen.dart';
import 'package:vtube/features/auth/widgets/playlist_form_dialog.dart';

import 'account_test_helpers.dart';

/// MÀN 4 · TRANG "BẠN" · kiểm thử logic nghiệp vụ.
/// Chạy: cd mobile && flutter test test/features/auth/account_screen_logic_test.dart
void main() {
  group('PlaylistFormDialog.validateTitle', () {
    test('bắt buộc nhập tên (khoảng trắng không tính)', () {
      expect(PlaylistFormDialog.validateTitle(null), 'Vui lòng nhập tên danh sách phát');
      expect(PlaylistFormDialog.validateTitle('   '), 'Vui lòng nhập tên danh sách phát');
    });

    test('tối đa 150 ký tự', () {
      expect(PlaylistFormDialog.validateTitle('a' * 150), isNull);
      expect(PlaylistFormDialog.validateTitle('a' * 151), 'Tên tối đa 150 ký tự');
      expect(PlaylistFormDialog.validateTitle('  ${'a' * 150}  '), isNull, reason: 'Không tính khoảng trắng hai đầu');
    });
  });

  group('Luồng màn Bạn', () {
    late AccountTestEnv env;

    setUp(() => env = AccountTestEnv());

    testWidgets('tải 10 video gần nhất cho Nhật ký xem và playlist của tôi', (tester) async {
      env.history.items = [for (var i = 1; i <= 12; i++) sampleHistory(i)];
      await pumpAccount(tester, env);

      expect(env.history.sizes, [AccountScreen.historySize]);
      expect(AccountScreen.historySize, 10);
      expect(env.playlists.mineCalls, 1);
      expect(find.text('Video số 10'), findsOneWidget);
      expect(find.text('Video số 11'), findsNothing);
    });

    testWidgets('Thử lại ở hàng lỗi: chỉ tải lại hàng đó', (tester) async {
      env.history.error = networkError;
      await pumpAccount(tester, env);

      env.history.error = null;
      await tester.tap(find.widgetWithText(TextButton, 'Thử lại'));
      await tester.pumpAndSettle();

      expect(env.history.sizes.length, 2);
      expect(env.playlists.mineCalls, 1, reason: 'Hàng playlist không bị tải lại');
      expect(find.text('Video số 1'), findsOneWidget);
      expect(find.text(networkError.message), findsNothing);
    });

    testWidgets('kéo xuống để làm mới: tải lại lịch sử, playlist và thông tin tài khoản', (tester) async {
      await pumpAccount(tester, env);
      env.history.items = [sampleHistory(42)];
      env.authService.user = accountUser(subscribers: 5000);

      await tester.fling(find.text(accountName), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(env.history.sizes.length, 2);
      expect(env.playlists.mineCalls, 2);
      expect(env.authService.meCalls, 1);
      expect(find.text('Video số 42'), findsOneWidget);
      expect(find.text('5 N người đăng ký'), findsOneWidget);
    });

    testWidgets('bấm video trong Nhật ký xem: mở màn Xem video; "Xem tất cả": mở Lịch sử', (tester) async {
      await pumpAccount(tester, env);

      await tester.tap(find.text('Video số 2'));
      await tester.pumpAndSettle();
      expect(find.text(videoLabel(2)), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem tất cả'));
      await tester.pumpAndSettle();
      expect(find.text(historyLabel), findsOneWidget);
    });

    testWidgets('quay lại từ màn khác: tải ngầm lại hàng liên quan (vd. vừa xem thêm video)', (tester) async {
      await pumpAccount(tester, env);
      await tester.tap(find.text('Xem tất cả'));
      await tester.pumpAndSettle();

      env.history.items = [sampleHistory(99)];
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Video số 99'), findsOneWidget);
    });

    testWidgets('"@handle · Xem kênh" và "Video của bạn": mở trang kênh của mình', (tester) async {
      await pumpAccount(tester, env);

      await tester.tap(find.text('@$accountHandle · Xem kênh'));
      await tester.pumpAndSettle();
      expect(find.text(channelLabel(accountChannelId)), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Video của bạn'));
      expect(find.text(channelLabel(accountChannelId)), findsOneWidget);
    });

    testWidgets('bấm thẻ playlist: mở Chi tiết playlist đúng id', (tester) async {
      await pumpAccount(tester, env);

      await tapVisible(tester, find.text('Học Flutter'));

      expect(find.text(playlistLabel(10)), findsOneWidget);
    });

    testWidgets('mục "Video đã thích": mở playlist kind == liked', (tester) async {
      await pumpAccount(tester, env);

      await tapVisible(tester, find.text('5 video bạn đã thích'));

      expect(find.text(playlistLabel(1)), findsOneWidget);
    });

    testWidgets('tạo playlist: gửi tên đã cắt khoảng trắng + chế độ đã chọn, hiện ngay sau playlist hệ thống',
        (tester) async {
      await pumpAccount(tester, env);

      await tester.tap(find.byTooltip('Tạo danh sách phát'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField(), '  Test  ');
      await tester.tap(inDialog('Công khai'));
      await tester.tap(inDialog('Tạo'));
      await tester.pumpAndSettle();

      expect(env.playlists.created, [('Test', 'public')]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('0 video · Công khai'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Test')).dx, lessThan(tester.getTopLeft(find.text('Học Flutter')).dx));
      expect(env.playlists.mineCalls, 1, reason: 'Hiện ngay, không cần tải lại cả hàng');
    });

    testWidgets('tạo playlist tên trống: báo lỗi trong dialog, không gọi API', (tester) async {
      await pumpAccount(tester, env);

      await tester.tap(find.byTooltip('Tạo danh sách phát'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Tạo'));
      await tester.pumpAndSettle();

      expect(inDialog('Vui lòng nhập tên danh sách phát'), findsOneWidget);
      expect(env.playlists.created, isEmpty);
    });

    testWidgets('tạo playlist lỗi server: lỗi hiện trong dialog, giữ chữ đã nhập', (tester) async {
      env.playlists.writeError = const ApiException('Không tạo được danh sách phát', statusCode: 500);
      await pumpAccount(tester, env);

      await tester.tap(find.byTooltip('Tạo danh sách phát'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField(), 'Test');
      await tester.tap(inDialog('Tạo'));
      await tester.pumpAndSettle();

      expect(inDialog('Không tạo được danh sách phát'), findsOneWidget);
      expect(tester.widget<TextFormField>(dialogField()).controller!.text, 'Test');
    });

    testWidgets('đổi tên playlist tự tạo: dialog có sẵn tên cũ, lưu xong thẻ đổi tên', (tester) async {
      await pumpAccount(tester, env);

      await longPressPlaylist(tester, 'Học Flutter');
      await tester.tap(find.text('Đổi tên'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(dialogField()).controller!.text, 'Học Flutter');

      await tester.enterText(dialogField(), 'Flutter nâng cao');
      await tester.tap(inDialog('Lưu'));
      await tester.pumpAndSettle();

      expect(env.playlists.renamed, [(10, 'Flutter nâng cao')]);
      expect(find.text('Flutter nâng cao'), findsOneWidget);
      expect(find.text('Học Flutter'), findsNothing);
    });

    testWidgets('xóa playlist: hỏi xác nhận; Hủy thì giữ, Xóa thì biến mất (nghiệm thu 3)', (tester) async {
      await pumpAccount(tester, env);

      await longPressPlaylist(tester, 'Học Flutter');
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa danh sách phát?'), findsOneWidget);
      await tester.tap(inDialog('Hủy'));
      await tester.pumpAndSettle();
      expect(env.playlists.deleted, isEmpty);
      expect(find.text('Học Flutter'), findsOneWidget);

      await longPressPlaylist(tester, 'Học Flutter');
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Xóa'));
      await tester.pumpAndSettle();

      expect(env.playlists.deleted, [10]);
      expect(find.text('Học Flutter'), findsNothing);
    });

    testWidgets('xóa lỗi: báo SnackBar, playlist vẫn còn', (tester) async {
      env.playlists.writeError = const ApiException('Không có quyền', statusCode: 403);
      await pumpAccount(tester, env);

      await longPressPlaylist(tester, 'Học Flutter');
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Không có quyền'), findsOneWidget);
      expect(find.text('Học Flutter'), findsOneWidget);
    });

    testWidgets('Đăng xuất: Hủy thì vẫn đăng nhập', (tester) async {
      await pumpAccount(tester, env);

      await tapVisible(tester, find.text('Đăng xuất'));
      expect(find.text('Đăng xuất?'), findsOneWidget);
      await tester.tap(inDialog('Hủy'));
      await tester.pumpAndSettle();

      expect(env.auth.isLoggedIn, isTrue);
      expect(env.authService.logoutCalls, 0);
    });

    testWidgets('Đăng xuất: xác nhận thì về trạng thái khách, sang Trang chủ (nghiệm thu 4)', (tester) async {
      await pumpAccount(tester, env);

      await tapVisible(tester, find.text('Đăng xuất'));
      await tester.tap(inDialog('Đăng xuất'));
      await tester.pumpAndSettle();

      expect(env.authService.logoutCalls, 1);
      expect(env.auth.isLoggedIn, isFalse);
      expect(find.text(homeLabel), findsOneWidget);
      expect(find.text('Đã đăng xuất'), findsOneWidget);
    });

    testWidgets('khách bấm Đăng nhập: mở màn Đăng nhập; đăng nhập xong màn Bạn tự tải dữ liệu', (tester) async {
      await pumpAccount(tester, env, signedIn: false);

      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text(loginLabel), findsOneWidget);

      await env.signIn();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text(accountName), findsOneWidget);
      expect(find.text('Video số 1'), findsOneWidget);
      expect(env.history.sizes, [10]);
    });

    testWidgets('Chuyển đổi tài khoản > Đăng nhập tài khoản khác: đăng xuất rồi mở màn Đăng nhập', (tester) async {
      await pumpAccount(tester, env);

      await tester.tap(find.text('Chuyển đổi tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập tài khoản khác'));
      await tester.pumpAndSettle();

      expect(env.auth.isLoggedIn, isFalse);
      expect(find.text(loginLabel), findsOneWidget);
    });

    testWidgets('đổi tài khoản giữa chừng: kết quả tải muộn của tài khoản cũ không hiện ra', (tester) async {
      env.history.hold = Completer<void>();
      await pumpAccount(tester, env, settle: false);

      await env.auth.logout();
      await tester.pump();
      env.history.hold!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Video số 1'), findsNothing);
      expect(find.text('Tận hưởng các video yêu thích'), findsOneWidget);
    });

    testWidgets('Video đã tải xuống, Tài khoản Google, Cài đặt: SnackBar giả lập', (tester) async {
      await pumpAccount(tester, env);

      await tapVisible(tester, find.text('Video đã tải xuống'));
      expect(find.text('Chưa có video tải xuống (giả lập)'), findsOneWidget);

      await tapVisible(tester, find.text('Tài khoản Google'));
      expect(find.text('Quản lý Tài khoản Google (giả lập)'), findsOneWidget);

      await tapVisible(tester, find.text('Cài đặt'));
      expect(find.text('Cài đặt sẽ có ở bản sau'), findsOneWidget);
    });
  });
}
