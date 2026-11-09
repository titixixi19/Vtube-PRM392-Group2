import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/features/library/history_screen.dart';
import 'package:vtube/shared/widgets/state_views.dart';

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

  group('Màn 13: Lịch sử xem (HistoryScreen) Logic & Regression Tests', () {
    testWidgets('Filter chip switch error clears list and displays ErrorView', (tester) async {
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

      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);

      // Bật cờ lỗi khi gọi danh sách
      fakeHistoryService.shouldFailList = true;

      // Chọn chip "Shorts"
      await tester.tap(find.text('Shorts'));
      await tester.pumpAndSettle();

      // Danh sách cũ phải bị xóa, ErrorView hiển thị thay vì trộn lẫn dữ liệu
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Học Flutter Cơ Bản 2026'), findsNothing);

      // Thử lại khi API phục hồi
      fakeHistoryService.shouldFailList = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);
    });

    testWidgets('Optimistic delete removes item immediately and Undo restores it without API call', (tester) async {
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

      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);
      expect(find.text('Lập trình Mobile với Clean Architecture'), findsOneWidget);

      // Mở menu 3 chấm của item đầu tiên
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Bấm "Xóa khỏi nhật ký xem"
      await tester.tap(find.text('Xóa khỏi nhật ký xem'));
      await tester.pumpAndSettle();

      // 1. Optimistic removal: biến mất ngay khỏi UI
      expect(find.text('Học Flutter Cơ Bản 2026'), findsNothing);
      expect(find.text('Đã xóa khỏi nhật ký xem'), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);

      // DELETE API chưa được gọi vì snackbar vẫn đang mở!
      expect(fakeHistoryService.deleteCalls, 0);

      // 2. Bấm "Hoàn tác"
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      // Video được khôi phục tại vị trí ban đầu
      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);

      // Chờ thời gian snackbar đóng (nếu có)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Vẫn không gọi API delete
      expect(fakeHistoryService.deleteCalls, 0);
    });

    testWidgets('Deferred delete calls API after SnackBar dismiss', (tester) async {
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

      // Mở menu 3 chấm
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Bấm "Xóa khỏi nhật ký xem"
      await tester.tap(find.text('Xóa khỏi nhật ký xem'));
      await tester.pumpAndSettle(); // Đóng bottom sheet và hiển thị SnackBar

      expect(fakeHistoryService.deleteCalls, 0);

      // Ẩn SnackBar để kích hoạt đóng (hoặc chờ hết thời gian)
      ScaffoldMessenger.of(tester.element(find.byType(HistoryScreen))).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // API delete được gọi sau khi đóng snackbar
      expect(fakeHistoryService.deleteCalls, 1);
      expect(fakeHistoryService.lastDeletedVideoId, 101);
    });

    testWidgets('Deferred delete error restores item at original index and shows error SnackBar', (tester) async {
      await authProvider.login('test@vtube.com', '123456');
      fakeHistoryService.shouldFailDelete = true;

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

      // Mở menu 3 chấm
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Bấm "Xóa khỏi nhật ký xem"
      await tester.tap(find.text('Xóa khỏi nhật ký xem'));
      await tester.pumpAndSettle();

      expect(find.text('Học Flutter Cơ Bản 2026'), findsNothing);

      // Ẩn SnackBar để kích hoạt callback đóng và gọi API
      ScaffoldMessenger.of(tester.element(find.byType(HistoryScreen))).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Video được hoàn trả về danh sách và hiện thông báo lỗi
      expect(find.text('Học Flutter Cơ Bản 2026'), findsOneWidget);
      expect(find.text('Lỗi máy chủ khi xóa lịch sử'), findsOneWidget);
    });
  });
}
