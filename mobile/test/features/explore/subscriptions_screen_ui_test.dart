import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/app/routes.dart';
import 'package:vtube/shared/widgets/channel_avatar.dart';
import 'package:vtube/shared/widgets/chip_bar.dart';
import 'package:vtube/shared/widgets/top_bar.dart';

import 'subscriptions_test_helpers.dart';

void main() {
  group('Màn 12 - Giao diện Kênh đăng ký (UI Test)', () {
    late FakeChannelService channelService;

    setUp(() {
      channelService = FakeChannelService();
    });

    testWidgets('App bar có đủ Logo VTube, icon Cast, Chuông và Tìm kiếm', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VtubeLogo), findsOneWidget);
      expect(find.byIcon(Icons.cast), findsOneWidget);
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Bấm icon tìm kiếm -> chuyển sang Màn 9
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(pushedRoute, AppRoutes.search);
    });

    testWidgets('Hàng avatar kênh hiển thị đúng chấm xanh hasNewDot cho kênh có video mới', (tester) async {
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      // Kênh 2 (Ẩm Thực Bụi) và kênh 4 (Âm Nhạc Trẻ) có hasNew = true
      final avatarsWithDot = find.byWidgetPredicate(
        (widget) => widget is ChannelAvatar && widget.hasNewDot,
      );
      expect(avatarsWithDot, findsAtLeastNWidgets(1));
    });

    testWidgets('Thanh ChipBar hiển thị đủ 7 loại bộ lọc feed', (tester) async {
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      for (final label in ['Tất cả', 'Hôm nay', 'Video', 'Shorts', 'Trực tiếp']) {
        expect(
          find.descendant(of: find.byType(ChipBar), matching: find.text(label)),
          findsOneWidget,
        );
      }
      // Cuộn ChipBar sang phải để thấy các chip tiếp theo
      await tester.drag(find.byType(ChipBar), const Offset(-300, 0));
      await tester.pumpAndSettle();
      for (final label in ['Tiếp tục xem', 'Chưa xem']) {
        expect(
          find.descendant(of: find.byType(ChipBar), matching: find.text(label)),
          findsOneWidget,
        );
      }
    });

    testWidgets('Bấm thẻ video trên feed: điều hướng tới màn xem video /video/:id', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('video_card_large_1')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/video/1');
    });

    testWidgets('Bấm nút "Xem kênh" khi đang lọc: điều hướng tới trang kênh /channel/:id', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      // Lọc theo kênh 1
      await tester.tap(find.byKey(const Key('channel_avatar_item_1')));
      await tester.pumpAndSettle();

      // Bấm nút "Xem kênh"
      await tester.tap(find.byKey(const Key('view_channel_button')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/channel/1');
    });

    testWidgets('Bấm nút "Tất cả" trên hàng kênh: mở trang Tất cả kênh đăng ký', (tester) async {
      await tester.pumpWidget(buildTestSubscriptionsScreen(
        channelService: channelService,
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('all_subscriptions_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('all_subscriptions_list')), findsOneWidget);
      expect(find.text('Kênh đăng ký'), findsOneWidget);
    });
  });
}
