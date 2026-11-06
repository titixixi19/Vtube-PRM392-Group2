import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/app/theme.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/auth_service.dart';
import 'package:vtube/data/services/history_service.dart';
import 'package:vtube/data/services/notification_service.dart';
import 'package:vtube/data/services/playlist_service.dart';
import 'package:vtube/data/services/upload_service.dart';
import 'package:vtube/data/services/video_service.dart';
import 'package:vtube/features/library/history_screen.dart';
import 'package:vtube/features/library/notifications_screen.dart';
import 'package:vtube/features/library/playlist_screen.dart';
import 'package:vtube/features/library/upload_screen.dart';
import 'package:vtube/features/library/widgets/history_group_section.dart';

// --- Test Fakes & Mocks ---

const kTestChannel = ChannelBrief(
  id: 10,
  name: 'Flutter Pro',
  handle: 'flutterpro',
  avatarUrl: 'https://example.com/avatar.jpg',
);

const kTestVideo1 = Video(
  id: 101,
  title: 'Học Flutter Cơ Bản 2026',
  videoUrl: 'https://example.com/v1.mp4',
  durationSeconds: 600,
  viewCount: 15000,
  likeCount: 500,
  dislikeCount: 10,
  commentCount: 45,
  publishedAt: '2026-11-01T00:00:00Z',
  channel: kTestChannel,
);

const kTestVideo2 = Video(
  id: 102,
  title: 'Lập trình Mobile với Clean Architecture',
  videoUrl: 'https://example.com/v2.mp4',
  durationSeconds: 1200,
  viewCount: 28000,
  likeCount: 1200,
  dislikeCount: 5,
  commentCount: 90,
  publishedAt: '2026-11-02T00:00:00Z',
  channel: kTestChannel,
);

class FakeAuthService extends AuthService {
  FakeAuthService(super.api);

  bool historyPaused = false;

  @override
  Future<AuthResult> login(String email, String password) async => const AuthResult(
        'test-token',
        Me(
          id: 1,
          email: 'test@vtube.com',
          displayName: 'Dũng Vũ',
          createdAt: '2026-01-01T00:00:00Z',
          channel: kTestChannel,
        ),
      );

  @override
  Future<Me> setHistoryPaused(bool paused) async {
    historyPaused = paused;
    return Me(
      id: 1,
      email: 'test@vtube.com',
      displayName: 'Dũng Vũ',
      historyPaused: paused,
      createdAt: '2026-01-01T00:00:00Z',
      channel: kTestChannel,
    );
  }
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService(super.api);

  List<NotificationItem> items = [
    const NotificationItem(
      id: 1,
      type: 'new_video',
      message: 'Flutter Pro vừa đăng video mới: Học Flutter Cơ Bản 2026',
      read: false,
      createdAt: '2026-11-06T10:00:00Z',
      actor: kTestChannel,
      videoId: 101,
      videoThumbnailUrl: 'https://example.com/thumb1.jpg',
      videoDurationSeconds: 600,
    ),
    const NotificationItem(
      id: 2,
      type: 'comment_reply',
      message: 'Nguyễn Văn A đã trả lời bình luận của bạn: Video rất hay!',
      read: true,
      createdAt: '2026-11-05T08:00:00Z',
      actor: kTestChannel,
      videoId: 102,
    ),
  ];

  @override
  Future<PageResult<NotificationItem>> list({String type = 'all', int page = 0, int size = 20}) async {
    if (type == 'mention') {
      final filtered = items.where((e) => e.type.startsWith('comment')).toList();
      return PageResult(items: filtered, page: page, size: size, hasMore: false);
    }
    return PageResult(items: items, page: page, size: size, hasMore: false);
  }

  @override
  Future<void> markAllRead() async {
    items = items
        .map((e) => NotificationItem(
              id: e.id,
              type: e.type,
              message: e.message,
              read: true,
              createdAt: e.createdAt,
              actor: e.actor,
              videoId: e.videoId,
              videoThumbnailUrl: e.videoThumbnailUrl,
              videoDurationSeconds: e.videoDurationSeconds,
              videoShort: e.videoShort,
              commentId: e.commentId,
            ))
        .toList();
  }
}

class FakeHistoryService extends HistoryService {
  FakeHistoryService(super.api);

  List<HistoryItem> items = [
    const HistoryItem(
      watchedAt: '2026-11-07T12:00:00Z',
      progressSeconds: 300,
      video: kTestVideo1,
    ),
    const HistoryItem(
      watchedAt: '2026-11-06T09:00:00Z',
      progressSeconds: 600,
      video: kTestVideo2,
    ),
  ];

  @override
  Future<PageResult<HistoryItem>> list({String type = 'all', String? q, int page = 0, int size = 20}) async {
    var res = items;
    if (q != null && q.isNotEmpty) {
      res = res.where((e) => e.video.title.toLowerCase().contains(q.toLowerCase())).toList();
    }
    return PageResult(items: res, page: page, size: size, hasMore: false);
  }

  @override
  Future<void> delete(int videoId) async {
    items.removeWhere((e) => e.video.id == videoId);
  }

  @override
  Future<void> clear() async {
    items.clear();
  }
}

class FakePlaylistService extends PlaylistService {
  FakePlaylistService(super.api);

  bool returnForbidden = false;

  @override
  Future<PlaylistDetail> detail(int id, {String sort = 'manual'}) async {
    if (returnForbidden) {
      throw const ApiException('Bạn không có quyền truy cập', statusCode: 403);
    }

    return const PlaylistDetail(
      playlist: Playlist(
        id: 100,
        title: 'Flutter Toàn Tập',
        description: 'Tổng hợp video hướng dẫn lập trình Flutter từ cơ bản đến nâng cao.',
        visibility: 'public',
        kind: 'custom',
        videoCount: 2,
        updatedAt: '2026-11-01T00:00:00Z',
        ownerUserId: 10,
        ownerName: 'Flutter Pro',
        ownerChannelId: 10,
      ),
      mine: true,
      totalViews: 43000,
      items: [
        PlaylistItem(position: 1, addedAt: '2026-11-01T00:00:00Z', video: kTestVideo1),
        PlaylistItem(position: 2, addedAt: '2026-11-02T00:00:00Z', video: kTestVideo2),
      ],
    );
  }

  @override
  Future<List<Playlist>> mine({int? videoId}) async => [];
}

class FakeVideoService extends VideoService {
  FakeVideoService(super.api);

  @override
  Future<List<Category>> categories() async => [
        const Category(id: 1, name: 'Công nghệ & Lập trình', slug: 'tech'),
        const Category(id: 2, name: 'Âm nhạc', slug: 'music'),
      ];
}

class FakeUploadService extends UploadService {
  FakeUploadService(super.api);

  @override
  Future<UploadResult> upload(
    String filePath, {
    String type = 'image',
    void Function(double progress)? onProgress,
    dynamic cancelToken,
  }) async {
    onProgress?.call(1.0);
    return const UploadResult('/uploads/test.mp4', 'test.mp4', 1048576);
  }
}

Widget createTestApp({
  required Widget child,
  required AuthProvider auth,
  required FakeNotificationService notificationService,
  required FakeHistoryService historyService,
  required FakePlaylistService playlistService,
  required FakeVideoService videoService,
  required FakeUploadService uploadService,
  required FakeAuthService authService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      Provider<NotificationService>.value(value: notificationService),
      Provider<HistoryService>.value(value: historyService),
      Provider<PlaylistService>.value(value: playlistService),
      Provider<VideoService>.value(value: videoService),
      Provider<UploadService>.value(value: uploadService),
      Provider<AuthService>.value(value: authService),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: child,
    ),
  );
}

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

  group('Unit Tests: History Date Grouping', () {
    final fixedNow = DateTime(2026, 11, 7, 15, 0, 0);

    test('formatHistoryDateLabel generates correct Vietnamese labels', () {
      expect(formatHistoryDateLabel('2026-11-07T08:00:00Z', now: fixedNow), 'Hôm nay');
      expect(formatHistoryDateLabel('2026-11-06T08:00:00Z', now: fixedNow), 'Hôm qua');
      expect(formatHistoryDateLabel('2026-11-04T08:00:00Z', now: fixedNow), 'Tuần này');
      expect(formatHistoryDateLabel('2026-10-25T08:00:00Z', now: fixedNow), '25 thg 10, 2026');
      expect(formatHistoryDateLabel('invalid-iso', now: fixedNow), 'Trước đó');
    });

    test('groupHistoryItems groups consecutive items properly', () {
      final items = [
        const HistoryItem(watchedAt: '2026-11-07T10:00:00Z', progressSeconds: 10, video: kTestVideo1),
        const HistoryItem(watchedAt: '2026-11-07T08:00:00Z', progressSeconds: 20, video: kTestVideo2),
        const HistoryItem(watchedAt: '2026-11-06T12:00:00Z', progressSeconds: 30, video: kTestVideo1),
      ];

      final groups = groupHistoryItems(items, now: fixedNow);
      expect(groups.length, 2);
      expect(groups[0].label, 'Hôm nay');
      expect(groups[0].items.length, 2);
      expect(groups[1].label, 'Hôm qua');
      expect(groups[1].items.length, 1);
    });
  });

  group('Màn 16: Thông báo (NotificationsScreen)', () {
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

    testWidgets('Logged in view shows sections and notifications', (tester) async {
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
    });
  });

  group('Màn 13: Lịch sử xem (HistoryScreen)', () {
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
    });
  });

  group('Màn 14: Chi tiết Playlist (PlaylistScreen)', () {
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
    });
  });

  group('Màn 15: Tải video lên (UploadScreen)', () {
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
  });
}
