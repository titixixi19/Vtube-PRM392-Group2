import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/app/routes.dart';

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

    testWidgets('Tài khoản chưa đăng ký kênh nào: hiện EmptyView với nút Khám phá', (tester) async {
      channelService.returnSubscriptions = [];
      String? pushedRoute;

      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hãy đăng ký kênh để xem video mới nhất tại đây'), findsOneWidget);
      expect(find.text('Khám phá'), findsOneWidget);

      await tester.tap(find.text('Khám phá'));
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
  });
}
