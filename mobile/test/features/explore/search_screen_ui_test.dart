import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/data/models/models.dart';

import 'search_test_helpers.dart';

void main() {
  group('Màn 9 - Giao diện Tìm kiếm (UI Test)', () {
    late FakeSearchService service;

    setUp(() {
      service = FakeSearchService();
      service.returnSuggestions = const SearchSuggestions(
        history: ['flutter basics'],
        suggestions: ['flutter animation', 'flutter layout'],
      );
    });

    testWidgets('AppBar có đủ nút Back, ô tìm kiếm bo tròn và nút Micro', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byKey(const Key('search_text_field')), findsOneWidget);
      expect(find.byKey(const Key('search_mic_button')), findsOneWidget);
      expect(find.text('Tìm kiếm trên VTube'), findsOneWidget);
    });

    testWidgets('Tự động focus vào ô tìm kiếm khi mở màn hình', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byKey(const Key('search_text_field')));
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('Nút X xóa nhanh xuất hiện khi có chữ và xóa sạch khi bấm', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      // Ban đầu rỗng -> không có nút X
      expect(find.byKey(const Key('search_clear_button')), findsNothing);

      // Gõ chữ -> xuất hiện nút X
      await tester.enterText(find.byKey(const Key('search_text_field')), 'vtube');
      await tester.pump();
      expect(find.byKey(const Key('search_clear_button')), findsOneWidget);

      // Bấm nút X -> xóa sạch chữ và nút X biến mất
      await tester.tap(find.byKey(const Key('search_clear_button')));
      await tester.pump();
      expect(find.text('vtube'), findsNothing);
      expect(find.byKey(const Key('search_clear_button')), findsNothing);
    });

    testWidgets('Icon ↖ điền từ khóa vào ô nhập mà không thực hiện tìm kiếm', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchScreen(
        searchService: service,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      // Tìm nút ↖ của mục history
      final historyTile = find.byKey(const Key('history_flutter basics'));
      final arrowButton = find.descendant(of: historyTile, matching: find.byIcon(Icons.north_west));
      expect(arrowButton, findsOneWidget);

      await tester.tap(arrowButton);
      await tester.pumpAndSettle();

      // Ô nhập có text nhưng KHÔNG chuyển trang
      expect(find.text('flutter basics'), findsOneWidget);
      expect(pushedRoute, isNull);
    });

    testWidgets('Bấm nút Micro hiện SnackBar thông báo', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_mic_button')));
      await tester.pumpAndSettle();

      expect(find.text('Tính năng tìm kiếm bằng giọng nói đang được phát triển.'), findsOneWidget);
    });

    testWidgets('Hiển thị đúng icon: đồng hồ cho lịch sử và kính lúp cho gợi ý', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      final historyTile = find.byKey(const Key('history_flutter basics'));
      expect(find.descendant(of: historyTile, matching: find.byIcon(Icons.history)), findsOneWidget);

      final suggestionTile = find.byKey(const Key('suggestion_flutter animation'));
      expect(find.descendant(of: suggestionTile, matching: find.byIcon(Icons.search)), findsOneWidget);
    });
  });
}
