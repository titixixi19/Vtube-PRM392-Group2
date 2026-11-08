import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/features/library/notifications_screen.dart';

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

  group('Màn 16: Thông báo (NotificationsScreen) UI Tests', () {
    testWidgets('Guest view shows login requirement', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const NotificationsScreen(),
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

      expect(find.text('Thông báo của bạn sẽ hiển thị ở đây'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
    });

    testWidgets('Logged in view shows sections, badges, and notification items', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      await tester.pumpWidget(
        createTestApp(
          child: const NotificationsScreen(),
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

      expect(find.text('Mới'), findsOneWidget);
      expect(find.text('Trước đó'), findsOneWidget);
      expect(find.textContaining('Học Flutter Cơ Bản 2026'), findsOneWidget);
      expect(find.text('Đánh dấu tất cả đã đọc'), findsOneWidget);
    });

    testWidgets('Notification 3-dot menu shows hide notification option', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      await tester.pumpWidget(
        createTestApp(
          child: const NotificationsScreen(),
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

      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Ẩn thông báo này'), findsOneWidget);
    });
  });
}
