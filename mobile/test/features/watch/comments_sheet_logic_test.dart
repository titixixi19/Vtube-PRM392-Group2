import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/features/watch/comments_sheet.dart';

import 'watch_test_helpers.dart';

void main() {
  group('Màn 7 - Logic Bình luận', () {
    late FakeCommentService commentService;

    setUp(() {
      commentService = FakeCommentService();
    });

    testWidgets('Tải danh sách bình luận ban đầu', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        commentService: commentService,
        child: const Scaffold(
          body: CommentsSheetContent(videoId: 1),
        ),
      ));
      await tester.pumpAndSettle();

      expect(commentService.listCalls, 1);
      expect(find.text('Bình luận 1'), findsOneWidget);
      expect(find.text('Bình luận 2'), findsOneWidget);
    });

    testWidgets('Đổi sort (Hàng đầu / Mới nhất) gọi lại API với tham số tương ứng', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        commentService: commentService,
        child: const Scaffold(
          body: CommentsSheetContent(videoId: 1),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Mới nhất'));
      await tester.pumpAndSettle();

      expect(commentService.listCalls, 2);
      expect(commentService.lastSort, 'new');
    });

    testWidgets('Gửi bình luận mới: thêm vào danh sách và tăng tổng số', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        commentService: commentService,
        isLoggedIn: true,
        child: const Scaffold(
          body: CommentsSheetContent(videoId: 1),
        ),
      ));
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      expect(inputField, findsOneWidget);
      await tester.enterText(inputField, 'Bình luận mới từ test');
      await tester.pump();

      // Nút gửi (icon send)
      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(commentService.createCalls, 1);
      expect(find.text('Bình luận mới từ test'), findsOneWidget);
    });
  });
}
