import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/data/models/models.dart';
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

    testWidgets('Chưa có bình luận + bàn phím đang mở: không bị tràn (BOTTOM OVERFLOWED)', (tester) async {
      // Màn hình điện thoại 411x914 dp, bàn phím chiếm 300 dp phía dưới
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2.625);
      addTearDown(tester.view.reset);

      commentService.returnList = const PageResult(items: [], page: 0, size: 20, hasMore: false);
      await tester.pumpWidget(buildTestWatchApp(
        commentService: commentService,
        isLoggedIn: true,
        child: const Scaffold(
          // Giống bottom sheet thật: sheet tự cộng viewInsets, Scaffold không co thêm
          resizeToAvoidBottomInset: false,
          body: CommentsSheetContent(videoId: 1),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chưa có bình luận nào'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
