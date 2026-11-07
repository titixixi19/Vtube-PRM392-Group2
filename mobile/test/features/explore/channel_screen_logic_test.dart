import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/app/routes.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/shared/widgets/subscribe_button.dart';

import 'channel_test_helpers.dart';

/// MÀN 11 · TRANG KÊNH · Kiểm thử logic nghiệp vụ.
/// Chạy: cd mobile && flutter test test/features/explore/channel_screen_logic_test.dart
void main() {
  group('Màn 11 - Logic Nghiệp vụ Trang kênh', () {
    testWidgets('Nghiệm thu 1: Mở kênh 2 → đủ banner, 1,5 Tr người đăng ký, tab Video đổi sắp xếp được',
        (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // 1. Kiểm tra thông tin kênh VTech Studio
      expect(find.text('VTech Studio'), findsWidgets); // Cả SliverAppBar lẫn Header
      expect(find.textContaining('1,5 Tr người đăng ký'), findsOneWidget);
      expect(find.textContaining('320 video'), findsOneWidget);
      expect(find.textContaining('@vtechstudio'), findsOneWidget);

      // 2. Chuyển sang tab Video
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      // Kiểm tra có chip sắp xếp Mới nhất, Phổ biến, Cũ nhất
      expect(find.text('Mới nhất'), findsOneWidget);
      expect(find.text('Phổ biến'), findsOneWidget);
      expect(find.text('Cũ nhất'), findsOneWidget);

      // Đổi sắp xếp sang "Phổ biến"
      await tester.tap(find.text('Phổ biến'));
      await tester.pumpAndSettle();

      expect(fake.lastSort, 'popular');
      expect(find.textContaining('popular'), findsWidgets);

      // Đổi sắp xếp sang "Cũ nhất"
      await tester.tap(find.text('Cũ nhất'));
      await tester.pumpAndSettle();

      expect(fake.lastSort, 'oldest');
      expect(find.textContaining('oldest'), findsWidgets);
    });

    testWidgets('Nghiệm thu 2: Đăng ký / hủy → số người đăng ký đổi ngay', (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // Ban đầu: chưa đăng ký, 1,5 Tr người đăng ký
      expect(find.text('Đăng ký'), findsOneWidget);
      expect(find.textContaining('1,5 Tr người đăng ký'), findsOneWidget);

      // Bấm Đăng ký
      await tester.tap(find.byType(SubscribeButton));
      await tester.pumpAndSettle();

      expect(fake.subscribeCalls, 1);
      expect(find.text('Đã đăng ký'), findsOneWidget);
      // 1500000 + 1 -> vẫn format 1,5 Tr
      expect(find.text('Đã đăng ký kênh'), findsOneWidget);

      // Bấm Hủy đăng ký
      await tester.tap(find.byType(SubscribeButton));
      await tester.pumpAndSettle();

      expect(fake.unsubscribeCalls, 1);
      expect(find.text('Đăng ký'), findsOneWidget);
      expect(find.text('Đã hủy đăng ký kênh'), findsOneWidget);
    });

    testWidgets('Nghiệm thu 3: Kênh của mình → thấy nút Tùy chỉnh kênh, bấm mở AppRoutes.editProfile', (tester) async {
      final fake = FakeChannelService();
      String? navigatedRoute;
      await pumpChannelScreen(
        tester,
        channelId: 1,
        channelService: fake,
        onNavigate: (route) => navigatedRoute = route,
      );

      // Kênh mình: có nút "Tùy chỉnh kênh" và "Quản lý video"
      expect(find.byKey(const Key('channel_customize_button')), findsOneWidget);
      expect(find.byKey(const Key('channel_manage_videos_button')), findsOneWidget);
      expect(find.byType(SubscribeButton), findsNothing);

      // Bấm "Tùy chỉnh kênh"
      await tester.tap(find.byKey(const Key('channel_customize_button')));
      await tester.pumpAndSettle();

      expect(navigatedRoute, AppRoutes.editProfile);
    });

    testWidgets('Lỗi tải kênh 404 hiện "Kênh này không có sẵn", lỗi khác hiện ErrorView với nút Thử lại',
        (tester) async {
      final fake = FakeChannelService();
      // 1. Lỗi mạng 500
      fake.error = const ApiException('Không thể kết nối máy chủ', statusCode: 500);
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      expect(find.text('Không thể kết nối máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Thử lại thành công khi hết lỗi
      fake.error = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('VTech Studio'), findsWidgets);

      // 2. Lỗi 404
      fake.error = const ApiException('Kênh này không có sẵn', statusCode: 404);
      await pumpChannelScreen(tester, channelId: 999, channelService: fake);

      expect(find.text('Kênh này không có sẵn'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);
    });

    testWidgets('Optimistic update: Đăng ký đổi UI ngay, nếu lỗi thì rollback lại trạng thái cũ', (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // Ban đầu: chưa đăng ký
      expect(find.text('Đăng ký'), findsOneWidget);

      final completer = Completer<SubscriptionResult>();
      fake.customSubscribeHandler = (id, {notifyMode}) => completer.future;

      // Bấm Đăng ký khi API chưa hoàn thành
      await tester.tap(find.byType(SubscribeButton));
      await tester.pump(); // Render optimistic UI

      // Nhận thấy UI lập tức optimistic chuyển sang "Đã đăng ký"
      expect(find.text('Đã đăng ký'), findsOneWidget);

      // Khi Future hoàn thành và quăng lỗi -> rollback lại "Đăng ký"
      completer.completeError(const ApiException('Lỗi máy chủ khi đăng ký', statusCode: 500));
      await tester.pumpAndSettle();
      expect(find.text('Đăng ký'), findsOneWidget);
      expect(find.text('Lỗi máy chủ khi đăng ký'), findsOneWidget);
    });

    testWidgets('Race condition tab Video: request cũ về chậm hơn request mới thì kết quả cũ bị bỏ qua',
        (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // Chuyển sang tab Video
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      final completer = Completer<PageResult<Video>>();
      fake.customVideosHandler = (id, {sort, page, size}) {
        if (sort == 'popular') {
          return completer.future;
        } else {
          return Future.value(PageResult(
            items: [
              sampleVideo(99, title: 'Video kết quả của sort cũ nhất'),
            ],
            page: 0,
            size: 20,
            hasMore: false,
          ));
        }
      };

      // 1. Bấm chip "Phổ biến" (chưa hoàn thành do completer)
      await tester.tap(find.text('Phổ biến'));
      await tester.pump();

      // 2. Nhanh chóng bấm chip "Cũ nhất" (hoàn thành ngay)
      await tester.tap(find.text('Cũ nhất'));
      await tester.pumpAndSettle();

      expect(find.text('Video kết quả của sort cũ nhất'), findsOneWidget);

      // 3. Request cũ của "Phổ biến" hoàn thành trễ
      completer.complete(PageResult(
        items: [
          sampleVideo(88, title: 'Video trễ của sort phổ biến'),
        ],
        page: 0,
        size: 20,
        hasMore: false,
      ));
      await tester.pumpAndSettle();

      // Kết quả cũ của "Phổ biến" không đè lên kết quả hiện tại
      expect(find.text('Video trễ của sort phổ biến'), findsNothing);
      expect(find.text('Video kết quả của sort cũ nhất'), findsOneWidget);
    });

    testWidgets('Kênh trống không có nội dung: hiện EmptyView với nút Tải video lên nếu là kênh mình', (tester) async {
      final fake = FakeChannelService();
      fake.channels[3] = const Channel(
        id: 3,
        userId: 1,
        name: 'Kênh của tôi chưa có video',
        handle: 'myempty',
        createdAt: '2026-01-01T00:00:00Z',
        mine: true,
      );

      String? navigatedRoute;
      await pumpChannelScreen(
        tester,
        channelId: 3,
        channelService: fake,
        onNavigate: (route) => navigatedRoute = route,
      );

      expect(find.text('Kênh này không có nội dung nào'), findsOneWidget);
      expect(find.text('Tải video lên'), findsOneWidget);

      await tester.tap(find.text('Tải video lên'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/upload');
    });

    testWidgets('Tab Shorts: hiển thị danh sách video ngắn và bấm vào mở đúng màn Shorts', (tester) async {
      final fake = FakeChannelService();
      String? navigatedRoute;

      await pumpChannelScreen(
        tester,
        channelId: 2,
        channelService: fake,
        onNavigate: (route) => navigatedRoute = route,
      );

      // Chuyển tab Shorts
      await tester.tap(find.widgetWithText(Tab, 'Shorts'));
      await tester.pumpAndSettle();

      expect(find.text('Mẹo tối ưu Flutter 1'), findsOneWidget);

      // Bấm vào video short 101
      await tester.tap(find.text('Mẹo tối ưu Flutter 1'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/shorts?start=101');
    });

    testWidgets('Tab Danh sách phát: hiển thị playlist và chuyển hướng sang màn playlist', (tester) async {
      final fake = FakeChannelService();
      String? navigatedRoute;

      await pumpChannelScreen(
        tester,
        channelId: 2,
        channelService: fake,
        onNavigate: (route) => navigatedRoute = route,
      );

      // Chuyển tab Danh sách phát
      await tester.tap(find.widgetWithText(Tab, 'Danh sách phát'));
      await tester.pumpAndSettle();

      expect(find.text('Lập trình Flutter Toàn diện'), findsOneWidget);

      // Bấm vào playlist 201
      await tester.tap(find.text('Lập trình Flutter Toàn diện'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/playlist/201');
    });
  });
}
