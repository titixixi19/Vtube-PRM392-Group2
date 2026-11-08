import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/features/library/upload_screen.dart';

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

  group('Màn 15: Tải video lên (UploadScreen) UI Tests', () {
    testWidgets('Step 1 -> Step 2 transition and submit button enablement', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: UploadScreen(
            pickVideo: (source) async => XFile('test/assets/test.mp4'),
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

      // Step 1: Chọn video
      expect(find.text('Chọn video'), findsOneWidget);
      expect(find.text('Chọn từ thư viện'), findsOneWidget);
      expect(find.text('Quay video mới'), findsOneWidget);

      // Bấm chọn từ thư viện
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      // Step 2: Form nhập thông tin
      expect(find.text('Thêm thông tin'), findsOneWidget);
      expect(find.text('Tải lên'), findsOneWidget);

      // Nút Tải lên chưa được bấm vì tiêu đề trống
      final uploadBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Tải lên'));
      expect(uploadBtn.onPressed, isNull);

      // Nhập tiêu đề
      await tester.enterText(find.byType(TextField).first, 'Video Demo Đỉnh Cao');
      await tester.pumpAndSettle();

      final uploadBtnEnabled = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Tải lên'));
      expect(uploadBtnEnabled.onPressed, isNotNull);
    });

    testWidgets('Renders Short-specific UI when isShort is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const UploadScreen(isShort: true),
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

      expect(find.text('Chọn video Short'), findsOneWidget);
      expect(find.text('Tạo một video Short'), findsOneWidget);
    });
  });
}
