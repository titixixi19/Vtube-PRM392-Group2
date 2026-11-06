import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/features/explore/widgets/channel_edit_sheet.dart';
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

    testWidgets('Nghiệm thu 3: Kênh của mình → thấy nút Tùy chỉnh kênh, sửa mô tả được', (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 1, channelService: fake);

      // Kênh mình: có nút "Tùy chỉnh kênh" và "Quản lý video"
      expect(find.byKey(const Key('channel_customize_button')), findsOneWidget);
      expect(find.byKey(const Key('channel_manage_videos_button')), findsOneWidget);
      expect(find.byType(SubscribeButton), findsNothing);

      // Bấm "Tùy chỉnh kênh"
      await tester.tap(find.byKey(const Key('channel_customize_button')));
      await tester.pumpAndSettle();

      // Kiểm tra sheet mở lên
      expect(find.byType(ChannelEditSheet), findsOneWidget);
      expect(find.byKey(const Key('channel_edit_name_input')), findsOneWidget);
      expect(find.byKey(const Key('channel_edit_desc_input')), findsOneWidget);

      // Sửa mô tả
      await tester.enterText(
        find.byKey(const Key('channel_edit_desc_input')),
        'Mô tả kênh mới đã được cập nhật thành công!',
      );
      await tester.tap(find.byKey(const Key('channel_edit_save_button')));
      await tester.pumpAndSettle();

      expect(fake.updateMineCalls, 1);
      expect(find.text('Đã cập nhật thông tin kênh'), findsOneWidget);
      expect(find.textContaining('Mô tả kênh mới đã được cập nhật'), findsOneWidget);
    });

    testWidgets('Kênh không tồn tại (404) hoặc lỗi mạng: hiện thông báo "Kênh này không có sẵn"', (tester) async {
      final fake = FakeChannelService();
      fake.error = const ApiException('Kênh này không có sẵn', statusCode: 404);

      await pumpChannelScreen(tester, channelId: 999, channelService: fake);

      expect(find.text('Kênh này không có sẵn'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);
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
