import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/data/models/models.dart';

import 'search_test_helpers.dart';

void main() {
  group('Màn 9 - Logic Nghiệp vụ Tìm kiếm', () {
    late FakeSearchService service;

    setUp(() {
      service = FakeSearchService();
    });

    testWidgets('Mở màn hình: tự động tải lịch sử với query rỗng', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      expect(service.suggestionsCalls, 1);
      expect(service.lastSuggestionsQuery, '');
      expect(find.byKey(const Key('history_flutter')), findsOneWidget);
      expect(find.byKey(const Key('history_vtube')), findsOneWidget);
    });

    testWidgets('Debounce 300 ms: gõ liên tục không gọi API dồn dập', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      final callsBefore = service.suggestionsCalls;

      // Gõ "f"
      await tester.enterText(find.byKey(const Key('search_text_field')), 'f');
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.suggestionsCalls, callsBefore);

      // Gõ tiếp "fl"
      await tester.enterText(find.byKey(const Key('search_text_field')), 'fl');
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.suggestionsCalls, callsBefore);

      // Gõ tiếp "flu"
      await tester.enterText(find.byKey(const Key('search_text_field')), 'flu');
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.suggestionsCalls, callsBefore);

      // Sau 300 ms kể từ lần gõ cuối
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(service.suggestionsCalls, callsBefore + 1);
      expect(service.lastSuggestionsQuery, 'flu');
    });

    testWidgets('Bấm Enter chuỗi rỗng hoặc toàn khoảng trắng: không tìm kiếm', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchScreen(
        searchService: service,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_text_field')), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(pushedRoute, isNull);
    });

    testWidgets('Bấm Enter từ khóa hợp lệ: điều hướng tới màn kết quả', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchScreen(
        searchService: service,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_text_field')), ' flutter ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(pushedRoute, '/search/results?q=flutter');
    });

    testWidgets('Bấm vào một mục gợi ý: tìm kiếm từ khóa đó', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(buildTestSearchScreen(
        searchService: service,
        onPushed: (route) => pushedRoute = route,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_flutter')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/search/results?q=flutter');
    });

    testWidgets('Tìm xong bấm Back: tự động tải lại lịch sử cập nhật', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      expect(service.suggestionsCalls, 1);

      // Tìm kiếm "dart"
      await tester.enterText(find.byKey(const Key('search_text_field')), 'dart');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Đang ở màn kết quả (hiển thị BackButton)
      expect(find.text('Results: dart'), findsOneWidget);

      // Bấm Back quay lại màn Tìm kiếm
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Kiểm tra _loadSuggestions được gọi lại khi quay về
      expect(service.suggestionsCalls, greaterThanOrEqualTo(2));
      expect(service.lastSuggestionsQuery, 'dart');
    });

    testWidgets('Response về sai thứ tự (race condition): kết quả cũ về sau không đè kết quả mới', (tester) async {
      final completerA = Completer<SearchSuggestions>();
      final completerB = Completer<SearchSuggestions>();
      service.queryCompleters['a'] = completerA;
      service.queryCompleters['b'] = completerB;

      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      // Gõ "a"
      await tester.enterText(find.byKey(const Key('search_text_field')), 'a');
      await tester.pump(const Duration(milliseconds: 350));
      expect(service.lastSuggestionsQuery, 'a');

      // Gõ tiếp "b"
      await tester.enterText(find.byKey(const Key('search_text_field')), 'b');
      await tester.pump(const Duration(milliseconds: 350));
      expect(service.lastSuggestionsQuery, 'b');

      // Cho request "b" (mới nhất) về trước
      completerB.complete(const SearchSuggestions(
        history: [],
        suggestions: ['banana shake'],
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('suggestion_banana shake')), findsOneWidget);

      // Cho request "a" (cũ) về sau
      completerA.complete(const SearchSuggestions(
        history: [],
        suggestions: ['apple pie'],
      ));
      await tester.pumpAndSettle();

      // Giao diện vẫn phải giữ kết quả của "b", không bị "a" đè lên
      expect(find.byKey(const Key('suggestion_banana shake')), findsOneWidget);
      expect(find.byKey(const Key('suggestion_apple pie')), findsNothing);
    });

    testWidgets('Lỗi khi tải gợi ý: hiện SnackBar báo lỗi', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      service.suggestionsError = const ApiException('Lỗi máy chủ khi tải gợi ý');

      await tester.enterText(find.byKey(const Key('search_text_field')), 'error_test');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Lỗi máy chủ khi tải gợi ý'), findsOneWidget);
    });

    testWidgets('Lọc trùng gợi ý không phân biệt hoa thường', (tester) async {
      service.returnSuggestions = const SearchSuggestions(
        history: ['Flutter'],
        suggestions: ['flutter', 'Flutter Tutorial'],
      );

      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      // Mục lịch sử 'Flutter' có mặt
      expect(find.byKey(const Key('history_Flutter')), findsOneWidget);
      // Gợi ý 'flutter' (viết thường) bị lọc bỏ để tránh trùng
      expect(find.byKey(const Key('suggestion_flutter')), findsNothing);
      // 'Flutter Tutorial' vẫn xuất hiện
      expect(find.byKey(const Key('suggestion_Flutter Tutorial')), findsOneWidget);
    });

    testWidgets('Nhấn giữ mục lịch sử và xác nhận xóa: gọi deleteHistory', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history_flutter')), findsOneWidget);

      // Nhấn giữ mục flutter
      await tester.longPress(find.byKey(const Key('history_flutter')));
      await tester.pumpAndSettle();

      // Hiện dialog xác nhận
      expect(find.text('Xóa khỏi nhật ký tìm kiếm?'), findsOneWidget);

      // Bấm Xóa
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(service.deleteCalls, 1);
      expect(service.lastDeletedKeyword, 'flutter');
      expect(find.byKey(const Key('history_flutter')), findsNothing);
    });

    testWidgets('Nhấn giữ mục lịch sử nhưng bấm Hủy: không gọi deleteHistory và giữ nguyên', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('history_flutter')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(service.deleteCalls, 0);
      expect(find.byKey(const Key('history_flutter')), findsOneWidget);
    });

    testWidgets('Xóa lịch sử lỗi: rollback lại mục đó và hiện SnackBar', (tester) async {
      service.deleteError = const ApiException('Không thể kết nối máy chủ');

      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('history_flutter')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      // Mục flutter được rollback lại
      expect(find.byKey(const Key('history_flutter')), findsOneWidget);
      expect(find.text('Không thể kết nối máy chủ'), findsOneWidget);
    });

    testWidgets('Mở với initialQuery: điền sẵn ô tìm kiếm và gọi gợi ý', (tester) async {
      await tester.pumpWidget(buildTestSearchScreen(
        searchService: service,
        initialQuery: 'dart language',
      ));
      await tester.pumpAndSettle();

      expect(find.text('dart language'), findsOneWidget);
      expect(service.lastSuggestionsQuery, 'dart language');
    });

    testWidgets('Không có gợi ý nào khớp: hiện 1 dòng "Tìm <từ khóa>"', (tester) async {
      service.returnSuggestions = const SearchSuggestions(history: [], suggestions: []);

      await tester.pumpWidget(buildTestSearchScreen(searchService: service));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_text_field')), 'xyz123abc');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_fallback_tile')), findsOneWidget);
      expect(find.text('Tìm "xyz123abc"'), findsOneWidget);
    });
  });
}
