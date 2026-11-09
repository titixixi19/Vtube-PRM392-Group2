import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/features/library/playlist_screen.dart';

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

  group('Màn 14: Chi tiết Playlist (PlaylistScreen) UI Tests', () {
    testWidgets('Renders playlist header and items', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const PlaylistScreen(playlistId: 100),
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

      expect(find.text('Flutter Toàn Tập'), findsWidgets);
      expect(find.text('Phát tất cả'), findsOneWidget);
      expect(find.text('Trộn bài'), findsOneWidget);
      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);
    });

    testWidgets('Displays 403 forbidden state when playlist is private', (tester) async {
      fakePlaylistService.returnForbidden = true;

      await tester.pumpWidget(
        createTestApp(
          child: const PlaylistScreen(playlistId: 100),
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

      expect(find.text('Danh sách phát này là riêng tư'), findsOneWidget);
      expect(find.text('Yêu cầu đăng nhập'), findsNothing);
    });

    testWidgets('Displays 401 unauthorized login state when unauthenticated instead of private', (tester) async {
      fakePlaylistService.returnUnauthorized = true;

      await tester.pumpWidget(
        createTestApp(
          child: const PlaylistScreen(playlistId: 100),
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

      expect(find.text('Yêu cầu đăng nhập'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Danh sách phát này là riêng tư'), findsNothing);
    });

    testWidgets('Reactive header updates video count dynamically', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const PlaylistScreen(playlistId: 100),
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

      expect(find.text('2 VIDEO'), findsOneWidget);
      expect(find.text('2 video'), findsOneWidget);

      // Xóa 1 video khỏi playlist
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xóa khỏi danh sách phát'));
      await tester.pumpAndSettle();

      // Header cập nhật ngay lập tức dựa trên danh sách items hiện thời
      expect(find.text('1 VIDEO'), findsOneWidget);
      expect(find.text('1 video'), findsOneWidget);

      // Đóng SnackBar trước khi thao tác tiếp
      ScaffoldMessenger.of(tester.element(find.byType(PlaylistScreen))).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Xóa video còn lại
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa khỏi danh sách phát'));
      await tester.pumpAndSettle();

      expect(find.text('0 VIDEO'), findsOneWidget);
      expect(find.text('0 video'), findsOneWidget);

      final playAllBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Phát tất cả'));
      expect(playAllBtn.onPressed, isNull);

      final shuffleBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Trộn bài'));
      expect(shuffleBtn.onPressed, isNull);
    });
  });
}
