import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/features/watch/video_screen.dart';
import 'package:vtube/shared/widgets/subscribe_button.dart';

import 'watch_test_helpers.dart';

void main() {
  group('Màn 6 - UI Xem Video', () {
    late FakeVideoService videoService;
    late FakeCommentService commentService;
    late FakeHistoryService historyService;

    setUp(() {
      videoService = FakeVideoService();
      commentService = FakeCommentService();
      historyService = FakeHistoryService();
    });

    testWidgets('Hiển thị đầy đủ thông tin video, kênh và số sub', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        commentService: commentService,
        historyService: historyService,
        child: const VideoScreen(videoId: 1),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Video Chi Tiết'), findsOneWidget);
      expect(find.text('VTech Studio'), findsOneWidget);
      // Hiển thị số sub format: 1.5M người đăng ký
      expect(find.text('1,5 Tr người đăng ký'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
      expect(find.text('Chia sẻ'), findsOneWidget);
    });

    testWidgets('Hiển thị chip lọc video gợi ý và video liên quan', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        commentService: commentService,
        historyService: historyService,
        child: const VideoScreen(videoId: 1),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Tất cả'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Từ kênh này'), findsOneWidget);
      expect(find.text('Video Liên Quan 1'), findsOneWidget);
    });

    testWidgets('Video của chính mình (viewer.owner) không hiện nút Đăng ký', (tester) async {
      videoService.returnDetail = createDummyVideo(
        id: 1,
        title: 'Video Của Tôi',
        viewer: const ViewerState(owner: true),
      );
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        commentService: commentService,
        historyService: historyService,
        child: const VideoScreen(videoId: 1),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Video Của Tôi'), findsOneWidget);
      expect(find.byType(SubscribeButton), findsNothing);
    });

    testWidgets('Video của kênh khác vẫn hiện nút Đăng ký', (tester) async {
      videoService.returnDetail = createDummyVideo(
        id: 1,
        viewer: const ViewerState(owner: false),
      );
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        commentService: commentService,
        historyService: historyService,
        child: const VideoScreen(videoId: 1),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SubscribeButton), findsOneWidget);
    });
  });
}
