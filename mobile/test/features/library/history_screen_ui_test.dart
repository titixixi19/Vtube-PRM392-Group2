import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/features/library/history_screen.dart';
import 'package:vtube/features/library/widgets/history_group_section.dart';

import 'library_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late FakeAuthService fakeAuthService;
  late FakeNotificationService fakeNotifService;
  late FakeHistoryService fakeHistoryService;
  late FakePlaylistService fakePlaylistService;
  late FakeVideoService fakeVideoService;
  late FakeUploadService fakeUploadService;
  late AuthProvider authProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tokenStorage = TokenStorage();
    apiClient = ApiClient(tokenStorage);
    fakeAuthService = FakeAuthService(apiClient);
    fakeNotifService = FakeNotificationService(apiClient);
    fakeHistoryService = FakeHistoryService(apiClient);
    fakePlaylistService = FakePlaylistService(apiClient);
    fakeVideoService = FakeVideoService(apiClient);
    fakeUploadService = FakeUploadService(apiClient);
    authProvider = AuthProvider(fakeAuthService, tokenStorage, apiClient);
  });

  group('Unit Tests: History Date Grouping (Timezone Independent)', () {
    final fixedNow = DateTime(2026, 11, 7, 15, 0, 0);

    test('formatHistoryDateLabel generates correct Vietnamese labels', () {
      final todayIso = DateTime(2026, 11, 7, 8, 0, 0).toIso8601String();
      final yesterdayIso = DateTime(2026, 11, 6, 8, 0, 0).toIso8601String();
      final thisWeekIso = DateTime(2026, 11, 4, 8, 0, 0).toIso8601String();
      final olderIso = DateTime(2026, 10, 25, 8, 0, 0).toIso8601String();

      expect(formatHistoryDateLabel(todayIso, now: fixedNow), 'Hôm nay');
      expect(formatHistoryDateLabel(yesterdayIso, now: fixedNow), 'Hôm qua');
      expect(formatHistoryDateLabel(thisWeekIso, now: fixedNow), 'Tuần này');
      expect(formatHistoryDateLabel(olderIso, now: fixedNow), '25 thg 10, 2026');
      expect(formatHistoryDateLabel('invalid-iso', now: fixedNow), 'Trước đó');
    });

    test('groupHistoryItems groups consecutive items properly', () {
      final todayIso = DateTime(2026, 11, 7, 10, 0, 0).toIso8601String();
      final todayEarlierIso = DateTime(2026, 11, 7, 8, 0, 0).toIso8601String();
      final yesterdayIso = DateTime(2026, 11, 6, 12, 0, 0).toIso8601String();

      final items = [
        HistoryItem(watchedAt: todayIso, progressSeconds: 10, video: kTestVideo1),
        HistoryItem(watchedAt: todayEarlierIso, progressSeconds: 20, video: kTestVideo2),
        HistoryItem(watchedAt: yesterdayIso, progressSeconds: 30, video: kTestVideo1),
      ];

      final groups = groupHistoryItems(items, now: fixedNow);
      expect(groups.length, 2);
      expect(groups[0].label, 'Hôm nay');
      expect(groups[0].items.length, 2);
      expect(groups[1].label, 'Hôm qua');
      expect(groups[1].items.length, 1);
    });
  });

  group('Màn 13: Lịch sử xem (HistoryScreen) UI Tests', () {
    testWidgets('Guest view shows empty login view', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const HistoryScreen(),
          auth: authProvider,
          notificationService: fakeNotifService,
          historyService: fakeHistoryService,
          playlistService: fakePlaylistService,
          videoService: fakeVideoService,
          uploadService: fakeUploadService,
          authService: fakeAuthService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nhật ký xem của bạn sẽ xuất hiện tại đây'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
    });

    testWidgets('Logged in view renders items and search bar toggle', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      await tester.pumpWidget(
        createTestApp(
          child: const HistoryScreen(),
          auth: authProvider,
          notificationService: fakeNotifService,
          historyService: fakeHistoryService,
          playlistService: fakePlaylistService,
          videoService: fakeVideoService,
          uploadService: fakeUploadService,
          authService: fakeAuthService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nhật ký xem'), findsOneWidget);
      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);

      // Bấm icon tìm kiếm -> hiện TextField tìm kiếm
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tìm trong nhật ký xem...'), findsOneWidget);

      // Bấm quay lại đóng tìm kiếm
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Nhật ký xem'), findsOneWidget);
    });

    testWidgets('Paused banner renders when history paused', (tester) async {
      await authProvider.login('test@vtube.com', '123456');
      await fakeAuthService.setHistoryPaused(true);
      await authProvider.login('test@vtube.com', '123456'); // reload user state

      await tester.pumpWidget(
        createTestApp(
          child: const HistoryScreen(),
          auth: authProvider,
          notificationService: fakeNotifService,
          historyService: fakeHistoryService,
          playlistService: fakePlaylistService,
          videoService: fakeVideoService,
          uploadService: fakeUploadService,
          authService: fakeAuthService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nhật ký xem đang bị tạm dừng'), findsOneWidget);
      expect(find.text('Bật lại'), findsOneWidget);
    });
  });
}
