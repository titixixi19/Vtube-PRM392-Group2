import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/features/watch/home_screen.dart';

import 'watch_test_helpers.dart';

void main() {
  group('Màn 5 - Logic Nghiệp vụ Trang chủ', () {
    late FakeVideoService videoService;

    setUp(() {
      videoService = FakeVideoService();
    });

    testWidgets('Tải ban đầu: gọi categories, feed mặc định và shorts', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(videoService.categoriesCalls, 1);
      expect(videoService.feedCalls, 1);
      expect(videoService.lastFeedCategory, isNull);
      expect(videoService.lastFeedPage, 0);
      expect(videoService.shortsCalls, 1);
    });

    testWidgets('Đổi category chip: nạp feed của danh mục tương ứng', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      // Bấm chip "Âm nhạc" (slug: 'music')
      final musicChip = find.widgetWithText(ChoiceChip, 'Âm nhạc');
      expect(musicChip, findsOneWidget);
      await tester.tap(musicChip);
      await tester.pumpAndSettle();

      expect(videoService.feedCalls, 2);
      expect(videoService.lastFeedCategory, 'music');
      expect(videoService.lastFeedPage, 0);
    });

    testWidgets('Chống race condition (_reqId): bấm chip nhanh chỉ nhận kết quả của chip bấm cuối', (tester) async {
      // Giả lập request "music_0" bị chậm, "gaming_0" trả về trước
      final musicCompleter = Completer<PageResult<Video>>();
      videoService.feedCompleters['music_0'] = musicCompleter;

      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      // 1. Bấm "Âm nhạc" (sẽ bị treo ở completer)
      await tester.tap(find.widgetWithText(ChoiceChip, 'Âm nhạc'));
      await tester.pump();

      // 2. Ngay lập tức bấm "Gaming" (hoàn tất ngay)
      videoService.returnFeed = PageResult(
        items: [createDummyVideo(id: 99, title: 'Video Gaming Chiến Thuật')],
        page: 0,
        size: 20,
        hasMore: false,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Gaming'));
      await tester.pumpAndSettle();

      expect(find.text('Video Gaming Chiến Thuật'), findsOneWidget);

      // 3. Bây giờ request cũ "music" mới hoàn tất trả về
      musicCompleter.complete(PageResult(
        items: [createDummyVideo(id: 88, title: 'Video Nhạc Chill')],
        page: 0,
        size: 20,
        hasMore: false,
      ));
      await tester.pumpAndSettle();

      // Video nhạc cũ bị loại bỏ vì _reqId không khớp, màn hình vẫn hiển thị Gaming
      expect(find.text('Video Gaming Chiến Thuật'), findsOneWidget);
      expect(find.text('Video Nhạc Chill'), findsNothing);
    });
  });
}
