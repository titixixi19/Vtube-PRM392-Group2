import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/features/watch/shorts_screen.dart';

import 'watch_test_helpers.dart';

void main() {
  group('Màn 8 - UI Shorts', () {
    late FakeVideoService videoService;

    setUp(() {
      videoService = FakeVideoService();
    });

    testWidgets('Hiển thị PageView Shorts, tiêu đề và handle kênh', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const ShortsScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Shorts 1'), findsOneWidget);
      expect(find.text('@vtechstudio'), findsOneWidget);
    });

    testWidgets('Hiển thị các icon tương tác: Like, Bình luận, Chia sẻ, Remix', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const ShortsScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
      expect(find.byIcon(Icons.comment_outlined), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });
  });
}
