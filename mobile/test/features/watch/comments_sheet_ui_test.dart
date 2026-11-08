import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/features/watch/comments_sheet.dart';

import 'watch_test_helpers.dart';

void main() {
  group('Màn 7 - UI Bình luận', () {
    late FakeCommentService commentService;

    setUp(() {
      commentService = FakeCommentService();
    });

    testWidgets('Hiển thị header, tổng số bình luận và ô nhập', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        commentService: commentService,
        isLoggedIn: true,
        child: const Scaffold(
          body: CommentsSheetContent(
            videoId: 1,
            totalCommentCount: 25,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bình luận'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Hàng đầu'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Mới nhất'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Trạng thái commentsEnabled = false: hiển thị thông báo đã bị tắt', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        commentService: commentService,
        child: const Scaffold(
          body: CommentsSheetContent(
            videoId: 1,
            commentsEnabled: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tính năng bình luận đã bị tắt cho video này.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
