import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/upload_service.dart';
import 'package:vtube/features/library/upload_screen.dart';
import 'package:vtube/features/library/widgets/upload_setting_sheets.dart';

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

    testWidgets('First-frame default thumbnail is extracted at non-zero offset and sent to create when custom thumbnail is not provided', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      int? capturedTimeMs;
      await tester.pumpWidget(
        createTestApp(
          child: UploadScreen(
            pickVideo: (source) async => XFile('test/assets/test.mp4'),
            extractThumbnail: (videoPath, {int timeMs = 1000}) async {
              capturedTimeMs = timeMs;
              return 'test/assets/generated_first_frame.jpg';
            },
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

      // Frame trích xuất không phải timeMs: 0
      expect(capturedTimeMs, isNotNull);
      expect(capturedTimeMs, greaterThan(0));

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
            extractThumbnail: (videoPath, {int timeMs = 1000}) async => 'test/assets/generated_first_frame.jpg',
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

    testWidgets('Cancellation is disabled during record creation phase (~95% progress) to prevent duplicates', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      final createCompleter = Completer<Video>();
      fakeVideoService.createCompleter = createCompleter;

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

      await tester.enterText(find.byType(TextField).first, 'Late Cancel Test Video');
      await tester.pumpAndSettle();

      // Bấm Tải lên
      await tester.tap(find.widgetWithText(FilledButton, 'Tải lên'));
      await tester.pump(); // Upload files hoàn thành, chuyển sang tạo bản ghi ở mức 95%

      // Đang ở giai đoạn tạo bản ghi 95%
      expect(find.text('Đang tải lên 95%'), findsOneWidget);

      // Nút hủy trong UploadProgressCard bị ẩn để tránh hủy muộn gây trùng lặp
      expect(
        find.descendant(of: find.byType(UploadProgressCard), matching: find.byIcon(Icons.close)),
        findsNothing,
      );

      // Thử bấm đóng từ AppBar cũng bị chặn
      final appBarClose = find.widgetWithIcon(IconButton, Icons.close);
      expect(appBarClose, findsOneWidget);
      await tester.tap(appBarClose);
      await tester.pumpAndSettle();
      expect(find.text('Đang tạo bản ghi video, không thể hủy lúc này'), findsOneWidget);
      expect(find.text('Thêm thông tin'), findsOneWidget); // Vẫn ở màn hình upload form

      // Hoàn tất tạo bản ghi
      createCompleter.complete(
        const Video(
          id: 999,
          title: 'Late Cancel Test Video',
          videoUrl: '/uploads/test_video.mp4',
          durationSeconds: 0,
          viewCount: 0,
          likeCount: 0,
          dislikeCount: 0,
          commentCount: 0,
          publishedAt: '2026-11-08T00:00:00Z',
          channel: kTestChannel,
        ),
      );
      await tester.pumpAndSettle();

      // Chỉ gọi create đúng 1 lần và thành công
      expect(fakeVideoService.createCalls, 1);
      expect(find.text('Video đã được tải lên'), findsOneWidget);
    });

    testWidgets('Confirming cancel dialog when upload enters record creation phase blocks cancel', (tester) async {
      await authProvider.login('test@vtube.com', '123456');

      final uploadCompleter = Completer<UploadResult>();
      fakeUploadService.uploadCompleter = uploadCompleter;
      final createCompleter = Completer<Video>();
      fakeVideoService.createCompleter = createCompleter;

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

      await tester.enterText(find.byType(TextField).first, 'Race Condition Video');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Tải lên'));
      await tester.pump(); // Upload is running

      // Mở hộp thoại xác nhận hủy trong khi tệp đang tải
      final cancelBtn = find.descendant(of: find.byType(UploadProgressCard), matching: find.byIcon(Icons.close));
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.text('Hủy tải lên?'), findsOneWidget);

      // Trong khi hộp thoại xác nhận đang mở, tệp upload hoàn thành -> chuyển sang tạo bản ghi (95%)
      uploadCompleter.complete(const UploadResult('/uploads/test.mp4', 'test.mp4', 100));
      await tester.pump();

      // Giờ người dùng mới bấm nút "Hủy tải lên" trong dialog
      await tester.tap(find.widgetWithText(TextButton, 'Hủy tải lên'));
      await tester.pumpAndSettle();

      // Vì đã bước vào giai đoạn tạo bản ghi, việc hủy bị từ chối
      expect(find.text('Đang tạo bản ghi video, không thể hủy lúc này'), findsOneWidget);

      // Cho hoàn tất tạo bản ghi
      createCompleter.complete(
        const Video(
          id: 1001,
          title: 'Race Condition Video',
          videoUrl: '/uploads/test.mp4',
          durationSeconds: 0,
          viewCount: 0,
          likeCount: 0,
          dislikeCount: 0,
          commentCount: 0,
          publishedAt: '2026-11-08T00:00:00Z',
          channel: kTestChannel,
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeVideoService.createCalls, 1);
      expect(find.text('Video đã được tải lên'), findsOneWidget);
    });

    testWidgets('Guest logging in recovers playlist list for upload selector', (tester) async {
      // Bắt đầu ở trạng thái khách chưa đăng nhập
      expect(authProvider.isLoggedIn, isFalse);

      await tester.pumpWidget(
        createTestApp(
          child: UploadScreen(
            pickVideo: (source) async => XFile('test/assets/test.mp4'),
            extractThumbnail: (videoPath, {int timeMs = 1000}) async => 'test/assets/thumb.jpg',
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

      // Chọn video để sang màn Form
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.pumpAndSettle();

      expect(find.text('Danh sách phát'), findsOneWidget);

      // Đăng nhập
      await authProvider.login('test@vtube.com', '123456');
      await tester.pumpAndSettle();

      // Cuộn tới Danh sách phát và mở sheet
      await tester.scrollUntilVisible(
        find.text('Danh sách phát'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Danh sách phát'));
      await tester.pumpAndSettle();

      // Đã nạp danh sách phát của tài khoản
      expect(find.text('Flutter Toàn Tập'), findsOneWidget);
    });
  });
}
