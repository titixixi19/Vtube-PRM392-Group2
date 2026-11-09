import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/features/library/notifications_screen.dart';
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

  group('Màn 16: Thông báo (NotificationsScreen) Logic & Regression Tests', () {
    testWidgets('Tapping notification marks read asynchronously and navigates immediately', (tester) async {
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

      // Thông báo đầu tiên (id: 1) chưa đọc
      expect(fakeNotifService.items[0].read, isFalse);

      // Nhấn vào thông báo
      await tester.tap(find.textContaining('Flutter Pro vừa đăng video mới'));
      await tester.pump(); // Không chờ await markRead vì đã chuyển thành non-blocking

      // Local state cập nhật đã đọc ngay lập tức
      await tester.pumpAndSettle();
      expect(fakeNotifService.markReadCalls, 1);
      expect(fakeNotifService.lastMarkReadId, 1);
    });

    testWidgets('Filter chip error clears items and displays ErrorView', (tester) async {
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

      expect(find.textContaining('Flutter Pro vừa đăng video mới'), findsOneWidget);

      // Kích hoạt lỗi API list
      fakeNotifService.shouldFailList = true;

      // Đổi sang chip "Lượt nhắc"
      await tester.tap(find.text('Lượt nhắc'));
      await tester.pumpAndSettle();

      // Dữ liệu cũ bị xóa và ErrorView hiển thị
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.textContaining('Flutter Pro vừa đăng video mới'), findsNothing);

      // Bấm Thử lại khi API hoạt động bình thường
      fakeNotifService.shouldFailList = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsNothing);
    });

    testWidgets('Mark all read updates all notifications to read state', (tester) async {
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

      expect(fakeNotifService.items.any((e) => !e.read), isTrue);

      await tester.tap(find.text('Đánh dấu tất cả đã đọc'));
      await tester.pumpAndSettle();

      expect(fakeNotifService.items.every((e) => e.read), isTrue);
      expect(find.text('Đã đánh dấu tất cả là đã đọc'), findsOneWidget);
    });
  });
}
