import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/shared/widgets/chip_bar.dart';

import 'search_test_helpers.dart';

void main() {
  group('Màn 10 - Giao diện Kết quả tìm kiếm (UI Test)', () {
    late FakeSearchService searchService;

    setUp(() {
      searchService = FakeSearchService();
    });

    testWidgets('AppBar có đủ nút Back, ô từ khóa, nút Micro và nút Bộ lọc', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('flutter'), findsOneWidget);
      expect(find.byKey(const Key('search_results_mic_button')), findsOneWidget);
      expect(find.byKey(const Key('search_filter_button')), findsOneWidget);
    });

    testWidgets('Bấm vào ô tìm kiếm trên AppBar: chuyển về Màn 9 sửa từ khóa', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter tutorial',
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_bar_query_tap')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/search?q=flutter tutorial');
    });

    testWidgets('Thanh ChipBar hiển thị đủ 6 danh mục', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      for (final label in ['Tất cả', 'Video', 'Shorts', 'Kênh', 'Danh sách phát', 'Chưa xem']) {
        expect(
          find.descendant(of: find.byType(ChipBar), matching: find.text(label)),
          findsOneWidget,
        );
      }
    });

    testWidgets('Bấm vào thẻ kênh: điều hướng tới trang kênh /channel/:id', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('channel_card_1')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/channel/1');
    });

    testWidgets('Bấm vào thẻ video: điều hướng tới xem video /video/:id', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('video_card_1')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/video/1');
    });

    testWidgets('Bấm vào thẻ playlist: điều hướng tới chi tiết playlist /playlist/:id', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('playlist_card_1')),
        300,
        scrollable: findMainVerticalScrollable(),
      );
      await tester.tap(find.byKey(const Key('playlist_card_1')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/playlist/1');
    });

    testWidgets('Bấm vào Short trên kệ ShortsShelf: điều hướng tới /shorts?start=:id', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      // Bấm short đầu tiên trong kệ
      await tester.scrollUntilVisible(
        find.byKey(const Key('search_shorts_shelf')),
        200,
        scrollable: findMainVerticalScrollable(),
      );
      await tester.drag(findMainVerticalScrollable(), const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Short 1'));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/shorts?start=100');
    });

    testWidgets('Bấm nút Micro hiện thông báo SnackBar', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_results_mic_button')));
      await tester.pumpAndSettle();

      expect(find.text('Tính năng tìm kiếm bằng giọng nói đang được phát triển.'), findsOneWidget);
    });
  });
}
