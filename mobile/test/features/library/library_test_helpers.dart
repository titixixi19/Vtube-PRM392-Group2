import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vtube/app/theme.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/auth_service.dart';
import 'package:vtube/data/services/history_service.dart';
import 'package:vtube/data/services/notification_service.dart';
import 'package:vtube/data/services/playlist_service.dart';
import 'package:vtube/data/services/upload_service.dart';
import 'package:vtube/data/services/video_service.dart';

// --- Fixtures ---

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
  thumbnailUrl: 'https://example.com/thumb1.jpg',
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
  thumbnailUrl: 'https://example.com/thumb2.jpg',
  channel: kTestChannel,
);

Playlist createTestPlaylist({
  int id = 100,
  String title = 'Flutter Toàn Tập',
  String? description = 'Tổng hợp video hướng dẫn lập trình Flutter từ cơ bản đến nâng cao.',
  String visibility = 'public',
  String kind = 'custom',
  int videoCount = 2,
  String? thumbnailUrl,
  String updatedAt = '2026-11-01T00:00:00Z',
  int ownerUserId = 10,
  String ownerName = 'Flutter Pro',
  int ownerChannelId = 10,
  bool? containsVideo,
}) =>
    Playlist(
      id: id,
      title: title,
      description: description,
      visibility: visibility,
      kind: kind,
      videoCount: videoCount,
      thumbnailUrl: thumbnailUrl,
      updatedAt: updatedAt,
      ownerUserId: ownerUserId,
      ownerName: ownerName,
      ownerChannelId: ownerChannelId,
      containsVideo: containsVideo,
    );

// --- Fake Services ---

class FakeAuthService extends AuthService {
  FakeAuthService(super.api);

  bool historyPaused = false;

  @override
  Future<AuthResult> login(String email, String password) async => AuthResult(
        'test-token',
        Me(
          id: 1,
          email: 'test@vtube.com',
          displayName: 'Dũng Vũ',
          historyPaused: historyPaused,
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

  bool shouldFailList = false;
  bool shouldFailLoadMore = false;
  bool shouldFailMarkRead = false;
  int markReadCalls = 0;
  int? lastMarkReadId;

  @override
  Future<PageResult<NotificationItem>> list({String type = 'all', int page = 0, int size = 20}) async {
    if (page == 0 && shouldFailList) {
      throw const ApiException('Lỗi tải danh sách thông báo');
    }
    if (page > 0 && shouldFailLoadMore) {
      throw const ApiException('Lỗi tải thêm thông báo');
    }
    if (type == 'mention') {
      final filtered = items.where((e) => e.type.startsWith('comment')).toList();
      return PageResult(items: filtered, page: page, size: size, hasMore: false);
    }
    return PageResult(items: items, page: page, size: size, hasMore: false);
  }

  @override
  Future<void> markRead(int id) async {
    markReadCalls++;
    lastMarkReadId = id;
    if (shouldFailMarkRead) {
      throw const ApiException('Lỗi cập nhật trạng thái đã đọc');
    }
    final index = items.indexWhere((e) => e.id == id);
    if (index != -1) {
      final old = items[index];
      items[index] = NotificationItem(
        id: old.id,
        type: old.type,
        message: old.message,
        read: true,
        createdAt: old.createdAt,
        actor: old.actor,
        videoId: old.videoId,
        videoThumbnailUrl: old.videoThumbnailUrl,
        videoDurationSeconds: old.videoDurationSeconds,
        videoShort: old.videoShort,
        commentId: old.commentId,
      );
    }
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

  bool shouldFailList = false;
  bool shouldFailLoadMore = false;
  bool shouldFailDelete = false;
  int deleteCalls = 0;
  int? lastDeletedVideoId;

  @override
  Future<PageResult<HistoryItem>> list({String type = 'all', String? q, int page = 0, int size = 20}) async {
    if (page == 0 && shouldFailList) {
      throw const ApiException('Lỗi tải lịch sử');
    }
    if (page > 0 && shouldFailLoadMore) {
      throw const ApiException('Lỗi tải thêm lịch sử');
    }
    var res = List<HistoryItem>.from(items);
    if (q != null && q.isNotEmpty) {
      res = res.where((e) => e.video.title.toLowerCase().contains(q.toLowerCase())).toList();
    }
    return PageResult(items: res, page: page, size: size, hasMore: false);
  }

  @override
  Future<void> delete(int videoId) async {
    deleteCalls++;
    lastDeletedVideoId = videoId;
    if (shouldFailDelete) {
      throw const ApiException('Lỗi máy chủ khi xóa lịch sử');
    }
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
  bool returnUnauthorized = false;
  bool shouldFailRemove = false;
  bool shouldFailAdd = false;
  int removeVideoCalls = 0;
  int? lastRemovedPlaylistId;
  int? lastRemovedVideoId;
  int addVideoCalls = 0;
  int reorderCalls = 0;
  int mineCalls = 0;
  Completer<Playlist>? addVideoCompleter;
  List<int>? lastReorderedVideoIds;
  String? lastUpdatedDescription;

  List<PlaylistItem> items = [
    const PlaylistItem(position: 1, addedAt: '2026-11-01T00:00:00Z', video: kTestVideo1),
    const PlaylistItem(position: 2, addedAt: '2026-11-02T00:00:00Z', video: kTestVideo2),
  ];

  @override
  Future<PlaylistDetail> detail(int id, {String sort = 'manual'}) async {
    if (returnForbidden) {
      throw const ApiException('Bạn không có quyền truy cập', statusCode: 403);
    }
    if (returnUnauthorized) {
      throw const ApiException('Yêu cầu đăng nhập', statusCode: 401);
    }

    return PlaylistDetail(
      playlist: createTestPlaylist(
        id: 100,
        title: 'Flutter Toàn Tập',
        description: 'Tổng hợp video hướng dẫn lập trình Flutter từ cơ bản đến nâng cao.',
        visibility: 'public',
        kind: 'custom',
        videoCount: items.length,
      ),
      mine: true,
      totalViews: 43000,
      items: items,
    );
  }

  @override
  Future<Playlist> removeVideo(int id, int videoId) async {
    removeVideoCalls++;
    lastRemovedPlaylistId = id;
    lastRemovedVideoId = videoId;
    if (shouldFailRemove) {
      throw const ApiException('Lỗi máy chủ khi gỡ video');
    }
    items.removeWhere((e) => e.video.id == videoId);
    return createTestPlaylist(id: 100, title: 'Flutter Toàn Tập');
  }

  @override
  Future<Playlist> addVideo(int id, int videoId) async {
    addVideoCalls++;
    if (addVideoCompleter != null) {
      return await addVideoCompleter!.future;
    }
    if (shouldFailAdd) {
      throw const ApiException('Lỗi máy chủ khi thêm video');
    }
    return createTestPlaylist(id: 100, title: 'Flutter Toàn Tập');
  }

  @override
  Future<Playlist> reorder(int id, List<int> videoIds) async {
    reorderCalls++;
    lastReorderedVideoIds = videoIds;
    return createTestPlaylist(id: 100, title: 'Flutter Toàn Tập');
  }

  @override
  Future<Playlist> update(int id, {String? title, String? description, String? visibility}) async {
    lastUpdatedDescription = description;
    return createTestPlaylist(
      id: id,
      title: title ?? 'Flutter Toàn Tập',
      description: description,
      visibility: visibility ?? 'public',
    );
  }

  @override
  Future<List<Playlist>> mine({int? videoId}) async {
    mineCalls++;
    return [
      createTestPlaylist(
        id: 100,
        title: 'Flutter Toàn Tập',
        visibility: 'public',
        kind: 'custom',
        videoCount: 2,
        containsVideo: videoId == 101,
      ),
      createTestPlaylist(
        id: 101,
        title: 'Video đã thích',
        visibility: 'private',
        kind: 'liked',
        videoCount: 5,
      ),
    ];
  }
}

class FakeVideoService extends VideoService {
  FakeVideoService(super.api);

  int createCalls = 0;
  String? lastCreatedTitle;
  String? lastCreatedThumbnailUrl;
  String? lastCreatedVideoUrl;
  bool shouldFailCreate = false;
  Completer<Video>? createCompleter;

  @override
  Future<List<Category>> categories() async => [
        const Category(id: 1, name: 'Công nghệ & Lập trình', slug: 'tech'),
        const Category(id: 2, name: 'Âm nhạc', slug: 'music'),
      ];

  @override
  Future<Video> create({
    required String title,
    required String videoUrl,
    String? description,
    String? thumbnailUrl,
    int? durationSeconds,
    int? categoryId,
    bool isShort = false,
    String visibility = 'public',
    bool commentsEnabled = true,
    bool madeForKids = false,
    String? tags,
  }) async {
    createCalls++;
    lastCreatedTitle = title;
    lastCreatedThumbnailUrl = thumbnailUrl;
    lastCreatedVideoUrl = videoUrl;

    if (createCompleter != null) {
      return await createCompleter!.future;
    }

    if (shouldFailCreate) {
      throw const ApiException('Tạo bản ghi video thất bại');
    }

    return Video(
      id: 999,
      title: title,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds ?? 0,
      viewCount: 0,
      likeCount: 0,
      dislikeCount: 0,
      commentCount: 0,
      publishedAt: '2026-11-08T00:00:00Z',
      channel: kTestChannel,
    );
  }
}

class FakeUploadService extends UploadService {
  FakeUploadService(super.api);

  int uploadCalls = 0;
  final List<String> uploadedPaths = [];
  final List<String> uploadedTypes = [];
  bool shouldFailVideo = false;
  bool shouldFailImage = false;
  Completer<UploadResult>? uploadCompleter;

  @override
  Future<UploadResult> upload(
    String filePath, {
    String type = 'image',
    void Function(double progress)? onProgress,
    dynamic cancelToken,
  }) async {
    uploadCalls++;
    uploadedPaths.add(filePath);
    uploadedTypes.add(type);

    if (uploadCompleter != null) {
      return await uploadCompleter!.future;
    }

    if (cancelToken is CancelToken && cancelToken.isCancelled) {
      throw const ApiException('Đã hủy');
    }

    if (type == 'video' && shouldFailVideo) {
      throw const ApiException('Lỗi tải video');
    }
    if (type == 'image' && shouldFailImage) {
      throw const ApiException('Lỗi tải ảnh');
    }

    onProgress?.call(1.0);
    final url = type == 'video' ? '/uploads/test_video.mp4' : '/uploads/test_thumb.jpg';
    return UploadResult(url, 'file.bin', 1048576);
  }
}

// --- Test Wrapper ---

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
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => child),
      GoRoute(path: '/watch', builder: (_, __) => const Scaffold(body: Text('Watch Screen'))),
      GoRoute(path: '/video/:id', builder: (_, __) => const Scaffold(body: Text('Video Screen'))),
      GoRoute(path: '/channel/:id', builder: (_, __) => const Scaffold(body: Text('Channel Screen'))),
      GoRoute(path: '/shorts', builder: (_, __) => const Scaffold(body: Text('Shorts Screen'))),
      GoRoute(path: '/shorts/:id', builder: (_, __) => const Scaffold(body: Text('Shorts Screen'))),
      GoRoute(path: '/search', builder: (_, __) => const Scaffold(body: Text('Search Screen'))),
      GoRoute(path: '/login-dialog', builder: (_, __) => const Scaffold(body: Text('Login Screen'))),
    ],
  );

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
    child: MaterialApp.router(
      theme: AppTheme.dark(),
      routerConfig: router,
    ),
  );
}
