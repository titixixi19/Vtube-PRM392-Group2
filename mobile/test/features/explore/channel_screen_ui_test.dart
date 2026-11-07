import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/features/explore/widgets/channel_about_sheet.dart';
import 'package:vtube/features/explore/widgets/channel_header.dart';
import 'package:vtube/features/explore/widgets/channel_tabs.dart';
import 'package:vtube/shared/widgets/app_network_image.dart';
import 'package:vtube/shared/widgets/channel_avatar.dart';

import 'channel_test_helpers.dart';

/// MÀN 11 · TRANG KÊNH · Kiểm thử giao diện (UI Test).
/// Chạy: cd mobile && flutter test test/features/explore/channel_screen_ui_test.dart
void main() {
  group('Màn 11 - Giao diện Trang kênh (UI Test)', () {
    testWidgets('App Bar có tiêu đề là tên kênh, icon Cast, icon Tìm kiếm và menu 3 chấm', (tester) async {
      final fake = FakeChannelService();
      String? navigatedRoute;

      await pumpChannelScreen(
        tester,
        channelId: 2,
        channelService: fake,
        onNavigate: (route) => navigatedRoute = route,
      );

      // 1. Tiêu đề App bar là tên kênh VTech Studio (không phải "Trang kênh")
      expect(find.descendant(of: find.byType(SliverAppBar), matching: find.text('VTech Studio')), findsOneWidget);

      // 2. Icon Cast
      expect(find.byIcon(Icons.cast), findsOneWidget);

      // 3. Icon Tìm kiếm và bấm vào điều hướng sang màn tìm kiếm
      expect(find.byIcon(Icons.search), findsOneWidget);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(navigatedRoute, '/search');
    });

    testWidgets('Header hiển thị ảnh banner, avatar lớn, tên kênh kèm tích xanh, handle & số video', (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // 1. Header có Banner và Avatar
      expect(find.byType(ChannelHeader), findsOneWidget);
      expect(find.byType(AppNetworkImage), findsWidgets);
      expect(find.descendant(of: find.byType(ChannelHeader), matching: find.byType(ChannelAvatar)), findsOneWidget);

      // 2. Tên kênh kèm tích xanh verified
      expect(find.text('VTech Studio'), findsWidgets);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // 3. Dòng thông số
      expect(find.text('@vtechstudio · 1,5 Tr người đăng ký · 320 video'), findsOneWidget);
    });

    testWidgets('Mô tả ngắn hiển thị kèm nút "...thêm", bấm vào mở bottom sheet Giới thiệu', (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // Thấy phần mô tả ngắn và "...thêm"
      expect(find.textContaining('...thêm'), findsOneWidget);

      // Bấm vào "...thêm"
      await tester.tap(find.textContaining('...thêm'));
      await tester.pumpAndSettle();

      // Mở bottom sheet Giới thiệu
      expect(find.byType(ChannelAboutSheet), findsOneWidget);
      expect(find.text('Thông tin khác'), findsOneWidget);
      expect(find.text('https://vtube.vn/@vtechstudio'), findsOneWidget);
      expect(find.byKey(const Key('channel_share_button_sheet')), findsOneWidget);
    });

    testWidgets('Nút "Tham gia" trên kênh người khác hiển thị dialog hội viên', (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // Bấm nút "Tham gia"
      expect(find.byKey(const Key('channel_join_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('channel_join_button')));
      await tester.pumpAndSettle();

      // Hiện AlertDialog
      expect(find.text('Tham gia hội viên'), findsOneWidget);
      expect(find.textContaining('Tính năng Hội viên cho kênh VTech Studio đang được phát triển'), findsOneWidget);

      // Bấm Đóng
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Tham gia hội viên'), findsNothing);
    });

    testWidgets('TabBar ghim có đủ 5 tab: Trang chủ, Video, Shorts, Danh sách phát, Giới thiệu', (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      expect(find.widgetWithText(Tab, 'Trang chủ'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Video'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Shorts'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Danh sách phát'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Giới thiệu'), findsOneWidget);
    });

    testWidgets('Tab Giới thiệu: hiển thị chi tiết mô tả, liên kết, ngày tham gia, quốc gia và nút Chia sẻ',
        (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // Kéo TabBar sang trái để thấy tab Giới thiệu
      await tester.drag(find.byType(TabBar), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Chuyển sang tab Giới thiệu
      await tester.tap(find.widgetWithText(Tab, 'Giới thiệu'));
      await tester.pumpAndSettle();

      // Kiểm tra nội dung tab Giới thiệu
      expect(find.text('Mô tả'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChannelAboutTab),
          matching: find.textContaining('Kênh chia sẻ kiến thức lập trình Fullstack'),
        ),
        findsOneWidget,
      );
      expect(find.text('Thông tin chi tiết'), findsOneWidget);
      expect(find.text('https://vtube.vn/@vtechstudio'), findsOneWidget);
      expect(find.text('1,5 Tr người đăng ký'), findsOneWidget);
      expect(find.text('320 video'), findsOneWidget);
      expect(find.text('45 Tr lượt xem'), findsOneWidget);
      expect(find.text('Đã tham gia 1 thg 1, 2024'), findsOneWidget);
      expect(find.text('Việt Nam'), findsOneWidget);
      expect(find.byKey(const Key('channel_share_button_tab')), findsOneWidget);
    });

    testWidgets('Menu 3 chấm trên App Bar: bấm mở menu chứa Chia sẻ, Báo cáo và Chặn', (tester) async {
      final fake = FakeChannelService();
      await pumpChannelScreen(tester, channelId: 2, channelService: fake);

      // Bấm icon 3 chấm
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Chia sẻ'), findsOneWidget);
      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Chặn'), findsOneWidget);

      // Bấm Báo cáo
      await tester.tap(find.text('Báo cáo'));
      await tester.pumpAndSettle();

      expect(find.text('Cảm ơn bạn đã báo cáo kênh'), findsOneWidget);
    });
  });
}
