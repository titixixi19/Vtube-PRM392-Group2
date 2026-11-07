import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/app/routes.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/data/models/models.dart';

import 'subscriptions_test_helpers.dart';

void main() {
  group('Màn 12 - Logic Nghiệp vụ Kênh đăng ký', () {
    late FakeChannelService channelService;

    setUp(() {
      channelService = FakeChannelService();
    });

    testWidgets('Khách chưa đăng nhập: hiện EmptyView với nút Đăng nhập', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: false,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Đừng bỏ lỡ video mới'), findsOneWidget);
      expect(find.text('Đăng nhập để xem cập nhật từ các kênh VTube bạn yêu thích'), findsOneWidget);

      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(pushedRoute, AppRoutes.login);
    });

    testWidgets('Đã đăng nhập: tự động tải danh sách kênh và feed ban đầu', (tester) async {
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      expect(channelService.mySubscriptionsCalls, 1);
      expect(channelService.subscriptionFeedCalls, 1);
      expect(channelService.lastFeedChannelId, isNull);
      expect(channelService.lastFeedType, 'all');
      expect(channelService.lastFeedPage, 0);

      // Thấy các kênh trên hàng avatar
      expect(find.text('Vietnam Vibes'), findsOneWidget);
      expect(find.text('Ẩm Thực Bụi'), findsOneWidget);
      expect(find.byKey(const Key('all_subscriptions_button')), findsOneWidget);

      // Thấy video trên feed
      expect(find.text('Ẩm thực đêm Hà Nội'), findsOneWidget);
    });

    testWidgets('Bấm avatar kênh: lọc feed theo channelId và hiện nút Xem kênh; bấm lại thì bỏ lọc', (tester) async {
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      final callsBefore = channelService.subscriptionFeedCalls;

      // Bấm vào avatar kênh 1 (Vietnam Vibes)
      await tester.tap(find.byKey(const Key('channel_avatar_item_1')));
      await tester.pumpAndSettle();

      expect(channelService.subscriptionFeedCalls, callsBefore + 1);
      expect(channelService.lastFeedChannelId, 1);
      expect(find.byKey(const Key('view_channel_button')), findsOneWidget);

      // Bấm lại avatar kênh 1 để bỏ lọc
      await tester.tap(find.byKey(const Key('channel_avatar_item_1')));
      await tester.pumpAndSettle();

      expect(channelService.subscriptionFeedCalls, callsBefore + 2);
      expect(channelService.lastFeedChannelId, isNull);
      expect(find.byKey(const Key('view_channel_button')), findsNothing);
    });

    testWidgets('Bấm chip phân loại loại nội dung: gọi lại subscriptionFeed với type tương ứng', (tester) async {
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      final callsBefore = channelService.subscriptionFeedCalls;

      // Bấm chip "Trực tiếp"
      await tester.tap(find.text('Trực tiếp'));
      await tester.pumpAndSettle();

      expect(channelService.subscriptionFeedCalls, callsBefore + 1);
      expect(channelService.lastFeedType, 'live');
      expect(channelService.lastFeedPage, 0);

      // Bấm chip "Shorts"
      await tester.tap(find.text('Shorts'));
      await tester.pumpAndSettle();

      expect(channelService.subscriptionFeedCalls, callsBefore + 2);
      expect(channelService.lastFeedType, 'short');
      expect(channelService.lastFeedPage, 0);
    });

    testWidgets('Kéo xuống làm mới (pull to refresh) gọi lại cả kênh và feed', (tester) async {
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      final channelCallsBefore = channelService.mySubscriptionsCalls;
      final feedCallsBefore = channelService.subscriptionFeedCalls;

      // Kéo RefreshIndicator
      await tester.fling(find.byKey(const Key('subscriptions_feed_list_view')), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(channelService.mySubscriptionsCalls, channelCallsBefore + 1);
      expect(channelService.subscriptionFeedCalls, feedCallsBefore + 1);
      expect(channelService.lastFeedPage, 0);
    });

    testWidgets('Tài khoản chưa đăng ký kênh nào: hiện EmptyView với nút Khám phá kênh', (tester) async {
      channelService.returnSubscriptions = [];
      String? pushedRoute;

      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hãy đăng ký kênh để xem video mới nhất tại đây'), findsOneWidget);
      expect(find.text('Khám phá kênh'), findsOneWidget);

      await tester.tap(find.text('Khám phá kênh'));
      await tester.pumpAndSettle();

      expect(pushedRoute, AppRoutes.home);
    });

    testWidgets('Trang Tất cả kênh đăng ký: sắp xếp A-Z, đổi chế độ chuông và hủy đăng ký', (tester) async {
      await tester.pumpWidget(buildTestAllSubscriptionsScreen(
        channelService: channelService,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('all_subscriptions_list')), findsOneWidget);

      // 1. Bấm sắp xếp A-Z
      await tester.tap(find.text('A-Z'));
      await tester.pumpAndSettle();

      expect(channelService.lastSubscriptionsSort, 'az');

      // 2. Bấm đổi chuông thông báo cho kênh 1
      await tester.tap(find.byKey(const Key('bell_button_1')));
      await tester.pumpAndSettle();

      // Chọn "Tất cả"
      await tester.tap(find.text('Tất cả').last);
      await tester.pumpAndSettle();

      expect(channelService.subscribeCalls, 1);
      expect(channelService.lastSubscribeId, 1);
      expect(channelService.lastSubscribeMode, 'all');

      // 3. Hủy đăng ký kênh 1 qua menu 3 chấm
      await tester.tap(find.byKey(const Key('channel_more_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hủy đăng ký'));
      await tester.pumpAndSettle();

      // Bấm xác nhận trong dialog
      await tester.tap(find.byKey(const Key('confirm_unsubscribe_button')));
      await tester.pumpAndSettle();

      expect(channelService.unsubscribeCalls, 1);
      expect(channelService.lastUnsubscribeId, 1);
      expect(find.byKey(const Key('all_sub_channel_1')), findsNothing);
    });

    testWidgets('Bấm vào Short trong feed điều hướng tới AppRoutes.shortsAt(videoId)', (tester) async {
      String? pushedRoute;
      channelService.returnFeed = const PageResult(
        items: [
          Video(
            id: 99,
            title: 'Short hài hước',
            videoUrl: '/shorts/99.mp4',
            thumbnailUrl: '/thumbs/99.jpg',
            durationSeconds: 45,
            viewCount: 15000,
            isShort: true,
            isLive: false,
            publishedAt: '2026-10-02T00:00:00Z',
            channel: ChannelBrief(id: 1, name: 'Vietnam Vibes', handle: 'vietnamvibes'),
          ),
        ],
        page: 0,
        size: 20,
        hasMore: false,
      );

      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('video_card_large_99')));
      await tester.pumpAndSettle();

      expect(pushedRoute, AppRoutes.shortsAt(99));
    });

    testWidgets('Lỗi tải feed hiển thị ErrorView và cho phép bấm Thử lại', (tester) async {
      channelService.feedError = const ApiException('Lỗi kết nối máy chủ');

      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Lỗi kết nối máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      channelService.feedError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Ẩm thực đêm Hà Nội'), findsOneWidget);
    });

    testWidgets('Race condition: request feed cũ về chậm hơn request mới thì kết quả cũ bị bỏ qua', (tester) async {
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      // Giả lập 2 request liên tiếp: bấm "Video" rồi nhanh chóng bấm "Shorts"
      var delayedCompleter = Completer<PageResult<Video>>();
      channelService.customFeedHandler = ({channelId, type, page, size}) {
        if (type == 'video') {
          return delayedCompleter.future;
        } else {
          return Future.value(PageResult(
            items: [
              testFeedVideo(id: 101, title: 'Video mới nhất của Shorts tab'),
            ],
            page: 0,
            size: 20,
            hasMore: false,
          ));
        }
      };

      // 1. Bấm chip "Video" (chưa hoàn thành vì delayedCompleter)
      await tester.tap(find.text('Video'));
      await tester.pump(); // Render loading feed

      // 2. Nhanh chóng bấm chip "Shorts" (hoàn thành ngay)
      await tester.tap(find.text('Shorts'));
      await tester.pumpAndSettle();

      // Lúc này màn hình hiển thị kết quả của "Shorts"
      expect(find.text('Video mới nhất của Shorts tab'), findsOneWidget);

      // 3. Request cũ của "Video" mới hoàn thành
      delayedCompleter.complete(PageResult(
        items: [
          testFeedVideo(id: 102, title: 'Video cũ bị trễ từ Video tab'),
        ],
        page: 0,
        size: 20,
        hasMore: false,
      ));
      await tester.pumpAndSettle();

      // Kết quả cũ của "Video" không được đè lên hoặc nối vào
      expect(find.text('Video cũ bị trễ từ Video tab'), findsNothing);
      expect(find.text('Video mới nhất của Shorts tab'), findsOneWidget);
    });
  });
}
