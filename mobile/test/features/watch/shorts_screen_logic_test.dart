import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/features/watch/shorts_screen.dart';

import 'watch_test_helpers.dart';

void main() {
  group('Màn 8 - Logic Shorts', () {
    late FakeVideoService videoService;

    setUp(() {
      videoService = FakeVideoService();
    });

    testWidgets('Tải danh sách Shorts ban đầu từ videoService.shorts', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const ShortsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(videoService.shortsCalls, 1);
      expect(find.text('Shorts 1'), findsOneWidget);
    });

    testWidgets('Không gọi load-more trùng lặp khi đang tải', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const ShortsScreen(),
      ));
      await tester.pumpAndSettle();

      final callsInitial = videoService.shortsCalls;
      expect(callsInitial, 1);

      // Thao tác cuộn nhẹ không làm dồn dập request
      await tester.drag(find.byType(PageView), const Offset(0, -100));
      await tester.pump();

      expect(videoService.shortsCalls, callsInitial);
    });
  });
}
