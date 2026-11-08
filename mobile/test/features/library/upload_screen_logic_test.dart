import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/services/upload_service.dart';
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

  group('Màn 15: Tải video lên (UploadScreen) Logic & Regression Tests', () {
    testWidgets('500MB file size guard rejects oversized files immediately', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      final tempDir = Directory.systemTemp.createTempSync('upload_test');
      final bigFile = File('${tempDir.path}/big_video.mp4');
      final raf = bigFile.openSync(mode: FileMode.write);
      raf.truncateSync(500 * 1024 * 1024 + 1);
      raf.closeSync();

      await tester.pumpWidget(
        createTestApp(
          child: UploadScreen(
            pickVideo: (source) async => XFile(bigFile.path),
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

      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      expect(find.text('Tệp quá lớn. Giới hạn dung lượng là 500MB.'), findsOneWidget);
      expect(find.text('Thêm thông tin'), findsNothing);

      tempDir.deleteSync(recursive: true);
    });

    testWidgets('First-frame default thumbnail is extracted and sent to create when custom thumbnail is not provided', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      await tester.pumpWidget(
        createTestApp(
          child: UploadScreen(
            pickVideo: (source) async => XFile('test/assets/test.mp4'),
            extractThumbnail: (videoPath) async => 'test/assets/generated_first_frame.jpg',
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

      // Bấm chọn từ thư viện
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      // Nhập tiêu đề
      await tester.enterText(find.byType(TextField).first, 'Video Test First Frame');
      await tester.pumpAndSettle();

      // Bấm Tải lên
      await tester.tap(find.widgetWithText(FilledButton, 'Tải lên'));
      await tester.pumpAndSettle();

      // Cả video và thumbnail trích xuất từ frame đầu tiên đều được tải lên
      expect(fakeUploadService.uploadedTypes, contains('video'));
      expect(fakeUploadService.uploadedTypes, contains('image'));
      expect(fakeUploadService.uploadedPaths, contains('test/assets/generated_first_frame.jpg'));

      // videoService.create nhận thumbnailUrl được sinh ra từ frame đầu
      expect(fakeVideoService.createCalls, 1);
      expect(fakeVideoService.lastCreatedThumbnailUrl, '/uploads/test_thumb.jpg');
    });

    testWidgets('Custom thumbnail overrides first-frame thumbnail', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      await tester.pumpWidget(
        createTestApp(
          child: UploadScreen(
            pickVideo: (source) async => XFile('test/assets/test.mp4'),
            pickImage: (source) async => XFile('test/assets/custom_thumbnail.jpg'),
            extractThumbnail: (videoPath) async => 'test/assets/generated_first_frame.jpg',
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

      // Bấm chọn từ thư viện
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      // Bấm đổi hình thu nhỏ sang custom thumbnail
      await tester.tap(find.text('Đổi hình thu nhỏ'));
      await tester.pumpAndSettle();

      // Nhập tiêu đề
      await tester.enterText(find.byType(TextField).first, 'Video With Custom Thumbnail');
      await tester.pumpAndSettle();

      // Bấm Tải lên
      await tester.tap(find.widgetWithText(FilledButton, 'Tải lên'));
      await tester.pumpAndSettle();

      // Thumbnail custom được dùng thay vì generated frame
      expect(fakeUploadService.uploadedPaths, contains('test/assets/custom_thumbnail.jpg'));
      expect(fakeVideoService.createCalls, 1);
    });

    testWidgets('Cancelling upload during file upload stops process and does not call videoService.create', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      final uploadCompleter = Completer<UploadResult>();
      fakeUploadService.uploadCompleter = uploadCompleter;

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

      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Video Cancelling Demo');
      await tester.pumpAndSettle();

      // Bấm Tải lên
      await tester.tap(find.widgetWithText(FilledButton, 'Tải lên'));
      await tester.pump(); // Không dùng pumpAndSettle vì completer đang pending

      // Tiến trình upload card hiển thị nút Hủy (icon close trong card)
      final cancelBtn = find.widgetWithIcon(IconButton, Icons.close);
      expect(cancelBtn, findsWidgets);
      await tester.tap(cancelBtn.first);
      await tester.pumpAndSettle();

      // Hộp thoại xác nhận hủy
      expect(find.text('Hủy tải lên?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Hủy tải lên'));
      await tester.pumpAndSettle();

      // Hoàn thành upload completer sau khi đã hủy
      uploadCompleter.complete(const UploadResult('/uploads/video.mp4', 'video.mp4', 100));
      await tester.pumpAndSettle();

      // Không gọi create vì đã bị hủy
      expect(fakeVideoService.createCalls, 0);
      expect(find.text('Video đã được tải lên'), findsNothing);
    });

    testWidgets('Retry after record creation failure reuses cached uploaded URLs', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      // Giả lập lỗi ở bước videoService.create
      fakeVideoService.shouldFailCreate = true;

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

      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Video Retry Demo');
      await tester.pumpAndSettle();

      // Tải lên lần 1 -> Upload file thành công nhưng create lỗi
      await tester.tap(find.widgetWithText(FilledButton, 'Tải lên'));
      await tester.pumpAndSettle();

      expect(fakeUploadService.uploadCalls, 1); // Đã upload video file
      expect(fakeVideoService.createCalls, 1);
      expect(find.text('Tạo bản ghi video thất bại'), findsWidgets);

      // Sửa lỗi API create
      fakeVideoService.shouldFailCreate = false;

      // Bấm "Thử lại" trên UploadProgressCard
      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      // Không gọi lại uploadService.upload vì đã cache _uploadedVideoUrl!
      expect(fakeUploadService.uploadCalls, 1);
      expect(fakeVideoService.createCalls, 2);
      expect(find.text('Video đã được tải lên'), findsOneWidget);
    });
  });
}
