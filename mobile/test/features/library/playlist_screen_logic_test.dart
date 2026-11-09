import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/features/library/playlist_screen.dart';
import 'package:vtube/features/library/widgets/playlist_edit_dialog.dart';
import 'package:vtube/shared/widgets/save_to_playlist_sheet.dart';

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

  group('Màn 14: Chi tiết Playlist (PlaylistScreen) Logic & Regression Tests', () {
    testWidgets('Optimistic delete removes video immediately and Undo restores it without calling addVideo', (tester) async {
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

      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);

      // Mở menu 3 chấm của video đầu tiên
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Bấm "Xóa khỏi danh sách phát"
      await tester.tap(find.text('Xóa khỏi danh sách phát'));
      await tester.pumpAndSettle();

      // Video bị xóa khỏi giao diện ngay lập tức
      expect(find.text('Học Flutter Cơ Bản 2026'), findsNothing);
      expect(find.text('Đã xóa khỏi danh sách phát'), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);

      // Chưa gọi API removeVideo
      expect(fakePlaylistService.removeVideoCalls, 0);

      // Bấm "Hoàn tác"
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      // Video xuất hiện lại tại vị trí cũ
      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);

      // Không gọi addVideo hay removeVideo
      expect(fakePlaylistService.removeVideoCalls, 0);
      expect(fakePlaylistService.addVideoCalls, 0);
    });

    testWidgets('Deferred delete calls removeVideo after SnackBar dismiss', (tester) async {
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

      // Mở menu 3 chấm
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Bấm "Xóa khỏi danh sách phát"
      await tester.tap(find.text('Xóa khỏi danh sách phát'));
      await tester.pumpAndSettle();

      expect(fakePlaylistService.removeVideoCalls, 0);

      // Đóng SnackBar
      ScaffoldMessenger.of(tester.element(find.byType(PlaylistScreen))).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // API removeVideo được gọi đúng với playlistId và videoId
      expect(fakePlaylistService.removeVideoCalls, 1);
      expect(fakePlaylistService.lastRemovedPlaylistId, 100);
      expect(fakePlaylistService.lastRemovedVideoId, 101);
    });

    testWidgets('Deferred delete error restores item at original index and shows error SnackBar', (tester) async {
      fakePlaylistService.shouldFailRemove = true;

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

      // Mở menu 3 chấm
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Bấm "Xóa khỏi danh sách phát"
      await tester.tap(find.text('Xóa khỏi danh sách phát'));
      await tester.pumpAndSettle();

      expect(find.text('Học Flutter Cơ Bản 2026'), findsNothing);

      // Đóng SnackBar để kích hoạt API xóa
      ScaffoldMessenger.of(tester.element(find.byType(PlaylistScreen))).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Video được hoàn trả về danh sách và hiện thông báo lỗi
      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);
      expect(find.text('Lỗi máy chủ khi gỡ video'), findsOneWidget);
    });

    testWidgets('Reorder items triggers playlistService.reorder', (tester) async {
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

      // Kéo thả reorder item đầu tiên xuống vị trí thứ hai
      final reorderableList = find.byType(ReorderableListView);
      expect(reorderableList, findsOneWidget);

      final state = tester.state(find.byType(PlaylistScreen)) as dynamic;
      // Gọi trực tiếp _onReorder để kiểm tra logic cập nhật thứ tự
      await state.widget; // ensure widget mounted
      // Simulate reorder
      final listWidget = tester.widget<ReorderableListView>(reorderableList);
      // ignore: deprecated_member_use
      listWidget.onReorder!(0, 2);
      await tester.pumpAndSettle();

      expect(fakePlaylistService.reorderCalls, 1);
      expect(fakePlaylistService.lastReorderedVideoIds, [102, 101]);
    });

    testWidgets('Playlist edit dialog sends empty string description when cleared', (tester) async {
      final playlist = createTestPlaylist(id: 100, title: 'Old Title', description: 'Old Description');

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => PlaylistEditDialog.show(ctx, playlist),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
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

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa danh sách phát'), findsOneWidget);

      // Xóa trắng ô mô tả
      final descField = find.widgetWithText(TextField, 'Old Description');
      await tester.enterText(descField, '');
      await tester.pumpAndSettle();

      // Bấm Lưu
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      // API nhận được chuỗi rỗng '' thay vì null
      expect(fakePlaylistService.lastUpdatedDescription, '');
    });

    testWidgets('Save to playlist sheet filters out liked videos playlist', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(
            body: SaveToPlaylistSheet(videoId: 999),
          ),
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

      expect(find.text('Flutter Toàn Tập'), findsOneWidget);
      // Playlist "Video đã thích" (kind == 'liked') đã bị lọc bỏ
      expect(find.text('Video đã thích'), findsNothing);
    });

    testWidgets('Reordering items flushes pending removes before calling reorder API', (tester) async {
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

      // Giả sử có 2 videos: 101 và 102. Xóa video 101 optimistically.
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xóa khỏi danh sách phát'));
      await tester.pumpAndSettle();

      expect(fakePlaylistService.removeVideoCalls, 0); // Vẫn đang pending vì SnackBar hiển thị

      // Gọi _onReorder (hoặc _moveItemTo)
      final state = tester.state(find.byType(PlaylistScreen)) as dynamic;
      await state.widget;
      final reorderableList = find.byType(ReorderableListView);
      final listWidget = tester.widget<ReorderableListView>(reorderableList);
      // ignore: deprecated_member_use
      listWidget.onReorder!(0, 1);
      await tester.pumpAndSettle();

      // Pending remove phải được hoàn tất trước khi reorder
      expect(fakePlaylistService.removeVideoCalls, 1);
      expect(fakePlaylistService.reorderCalls, 1);
    });
  });
}
