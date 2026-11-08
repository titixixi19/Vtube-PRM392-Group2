import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/features/watch/home_screen.dart';

import 'watch_test_helpers.dart';

void main() {
  group('Màn 5 - UI Trang chủ', () {
    late FakeVideoService videoService;

    setUp(() {
      videoService = FakeVideoService();
    });

    testWidgets('Hiển thị thanh category chips và danh sách video', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Tất cả'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Âm nhạc'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Gaming'), findsOneWidget);

      expect(find.text('Video Feed 1'), findsOneWidget);
      expect(find.text('Video Feed 2'), findsOneWidget);
    });

    testWidgets('Bấm 3 chấm và chọn "Không quan tâm": ẩn video khỏi danh sách', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Video Feed 1'), findsOneWidget);

      // Bấm nút 3 chấm đầu tiên
      final moreButtons = find.byIcon(Icons.more_vert);
      expect(moreButtons, findsWidgets);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Bấm "Không quan tâm"
      final notInterestedOption = find.text('Không quan tâm');
      expect(notInterestedOption, findsOneWidget);
      await tester.tap(notInterestedOption);
      await tester.pumpAndSettle();

      // Video Feed 1 biến mất khỏi danh sách
      expect(find.text('Video Feed 1'), findsNothing);
    });
  });
}
