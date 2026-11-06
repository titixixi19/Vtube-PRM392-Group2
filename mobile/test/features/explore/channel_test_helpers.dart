import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/app/routes.dart';
import 'package:vtube/app/theme.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/auth_service.dart';
import 'package:vtube/data/services/channel_service.dart';
import 'package:vtube/data/services/notification_service.dart';
import 'package:vtube/data/services/playlist_service.dart';
import 'package:vtube/data/services/video_service.dart';
import 'package:vtube/features/explore/channel_screen.dart';

const kChannelVTech = Channel(
  id: 2,
  userId: 2,
  name: 'VTech Studio',
  handle: 'vtechstudio',
  description: 'Kênh chia sẻ kiến thức lập trình Fullstack, Mobile App Flutter, DevOps và kiến trúc hệ thống.',
  avatarUrl: 'https://example.com/avatar2.jpg',
  bannerUrl: 'https://example.com/banner2.jpg',
  verified: true,
  subscriberCount: 1500000,
  videoCount: 320,
  totalViews: 45000000,
  createdAt: '2024-01-01T00:00:00Z',
  subscribed: false,
  mine: false,
);

const kChannelMine = Channel(
  id: 1,
  userId: 1,
  name: 'Kênh của tôi',
  handle: 'mychannel',
  description: 'Mô tả kênh cá nhân của tôi.',
  avatarUrl: 'https://example.com/avatar1.jpg',
  bannerUrl: 'https://example.com/banner1.jpg',
  verified: false,
  subscriberCount: 120,
  videoCount: 5,
  totalViews: 1500,
  createdAt: '2025-05-15T00:00:00Z',
  subscribed: false,
  mine: true,
);

const kChannelEmpty = Channel(
  id: 3,
  userId: 3,
  name: 'Kênh trống',
  handle: 'emptychan',
  description: null,
  avatarUrl: null,
  bannerUrl: null,
  verified: false,
  subscriberCount: 0,
  videoCount: 0,
  totalViews: 0,
  createdAt: '2026-01-01T00:00:00Z',
  subscribed: false,
  mine: false,
);

Video sampleVideo(int id, {String title = '', int views = 12000, bool isShort = false}) => Video(
      id: id,
      title: title.isEmpty ? 'Video bài giảng số $id' : title,
      videoUrl: '/media/$id.mp4',
      thumbnailUrl: 'https://example.com/thumb$id.jpg',
      durationSeconds: isShort ? 45 : 620,
      viewCount: views,
      likeCount: 500,
      isLive: false,
      isShort: isShort,
      publishedAt: '2026-10-01T00:00:00Z',
      channel: const ChannelBrief(id: 2, name: 'VTech Studio', handle: 'vtechstudio'),
    );

Playlist samplePlaylist(int id, String title, {int videoCount = 4}) => Playlist(
      id: id,
      title: title,
      videoCount: videoCount,
      visibility: 'public',
      thumbnailUrl: 'https://example.com/playlist$id.jpg',
      updatedAt: '2026-10-15T00:00:00Z',
      ownerUserId: 2,
      ownerName: 'VTech Studio',
      ownerChannelId: 2,
    );

class FakeChannelService extends ChannelService {
  FakeChannelService() : super(ApiClient(TokenStorage()));

  final Map<int, Channel> channels = {
    2: kChannelVTech,
    1: kChannelMine,
    3: kChannelEmpty,
  };

  int getCalls = 0;
  int videosCalls = 0;
  String lastSort = 'newest';
  int shortsCalls = 0;
  int playlistsCalls = 0;
  int updateMineCalls = 0;
  int subscribeCalls = 0;
  int unsubscribeCalls = 0;
  ApiException? error;

  @override
  Future<Channel> get(int id) async {
    getCalls++;
    if (error != null) throw error!;
    final ch = channels[id];
    if (ch == null) throw const ApiException('Kênh này không có sẵn', statusCode: 404);
    return ch;
  }

  @override
  Future<PageResult<Video>> videos(int id, {String sort = 'newest', int page = 0, int size = 20}) async {
    videosCalls++;
    lastSort = sort;
    if (id == 3) return PageResult(items: [], page: page, size: size, hasMore: false);

    final items = [
      sampleVideo(1, title: 'Flutter WebSockets Streaming $sort', views: 45000),
      sampleVideo(2, title: 'Docker & Kubernetes Thực chiến $sort', views: 128000),
      sampleVideo(3, title: 'PostgreSQL High Performance $sort', views: 89000),
    ];
    return PageResult(items: items, page: page, size: size, hasMore: false);
  }

  @override
  Future<PageResult<Video>> shorts(int id, {String sort = 'newest', int page = 0, int size = 30}) async {
    shortsCalls++;
    if (id == 3) return PageResult(items: [], page: page, size: size, hasMore: false);

    final items = [
      sampleVideo(101, title: 'Mẹo tối ưu Flutter 1', views: 25000, isShort: true),
      sampleVideo(102, title: 'Mẹo tối ưu Flutter 2', views: 42000, isShort: true),
      sampleVideo(103, title: 'Mẹo tối ưu Flutter 3', views: 18000, isShort: true),
    ];
    return PageResult(items: items, page: page, size: size, hasMore: false);
  }

  @override
  Future<List<Playlist>> playlists(int id) async {
    playlistsCalls++;
    if (id == 3) return [];
    return [
      samplePlaylist(201, 'Lập trình Flutter Toàn diện'),
      samplePlaylist(202, 'DevOps & CI/CD Thực chiến'),
    ];
  }

  @override
  Future<Channel> updateMine({String? name, String? description, String? avatarUrl, String? bannerUrl}) async {
    updateMineCalls++;
    final cur = channels[1]!;
    final updated = Channel(
      id: cur.id,
      userId: cur.userId,
      name: name ?? cur.name,
      handle: cur.handle,
      description: description ?? cur.description,
      avatarUrl: avatarUrl ?? cur.avatarUrl,
      bannerUrl: bannerUrl ?? cur.bannerUrl,
      verified: cur.verified,
      subscriberCount: cur.subscriberCount,
      videoCount: cur.videoCount,
      totalViews: cur.totalViews,
      createdAt: cur.createdAt,
      subscribed: cur.subscribed,
      mine: true,
    );
    channels[1] = updated;
    return updated;
  }

  @override
  Future<SubscriptionResult> subscribe(int id, {String? notifyMode}) async {
    subscribeCalls++;
    final cur = channels[id]!;
    final newCount = cur.subscriberCount + 1;
    channels[id] = Channel(
      id: cur.id,
      userId: cur.userId,
      name: cur.name,
      handle: cur.handle,
      description: cur.description,
      avatarUrl: cur.avatarUrl,
      bannerUrl: cur.bannerUrl,
      verified: cur.verified,
      subscriberCount: newCount,
      videoCount: cur.videoCount,
      totalViews: cur.totalViews,
      createdAt: cur.createdAt,
      subscribed: true,
      notifyMode: notifyMode ?? 'personalized',
      mine: cur.mine,
    );
    return SubscriptionResult(true, notifyMode ?? 'personalized', newCount);
  }

  @override
  Future<SubscriptionResult> unsubscribe(int id) async {
    unsubscribeCalls++;
    final cur = channels[id]!;
    final newCount = (cur.subscriberCount - 1).clamp(0, 999999999);
    channels[id] = Channel(
      id: cur.id,
      userId: cur.userId,
      name: cur.name,
      handle: cur.handle,
      description: cur.description,
      avatarUrl: cur.avatarUrl,
      bannerUrl: cur.bannerUrl,
      verified: cur.verified,
      subscriberCount: newCount,
      videoCount: cur.videoCount,
      totalViews: cur.totalViews,
      createdAt: cur.createdAt,
      subscribed: false,
      notifyMode: null,
      mine: cur.mine,
    );
    return SubscriptionResult(false, null, newCount);
  }
}

class FakeAuthService extends AuthService {
  FakeAuthService() : super(ApiClient(TokenStorage()));

  @override
  Future<Me> me() async => const Me(
        id: 1,
        email: 'demo@vtube.vn',
        displayName: 'User Demo',
        createdAt: '2026-01-01T00:00:00Z',
        channel: ChannelBrief(id: 1, name: 'Kênh của tôi', handle: 'mychannel'),
      );
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super(ApiClient(TokenStorage()));

  @override
  Future<int> unreadCount() async => 0;
}

class FakePlaylistService extends PlaylistService {
  FakePlaylistService() : super(ApiClient(TokenStorage()));

  @override
  Future<Playlist> addWatchLater(int videoId) async => samplePlaylist(1, 'Xem sau');
}

class FakeVideoService extends VideoService {
  FakeVideoService() : super(ApiClient(TokenStorage()));

  @override
  Future<void> notInterested(int videoId) async {}
}

Future<void> pumpChannelScreen(
  WidgetTester tester, {
  required int channelId,
  FakeChannelService? channelService,
  bool isLoggedIn = true,
  void Function(String route)? onNavigate,
}) async {
  tester.view.physicalSize = const Size(600 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'auth_token': isLoggedIn ? 'mock_token' : ''});
  final storage = TokenStorage();
  if (isLoggedIn) await storage.save('mock_token');

  final fakeChannelService = channelService ?? FakeChannelService();
  final fakeAuthService = FakeAuthService();
  final apiClient = ApiClient(storage);
  final authProvider = AuthProvider(fakeAuthService, storage, apiClient);
  if (isLoggedIn) {
    await authProvider.restoreSession();
  }

  final router = GoRouter(
    initialLocation: AppRoutes.channel(channelId),
    routes: [
      GoRoute(
        path: '/channel/:id',
        builder: (context, state) => ChannelScreen(
          channelId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) {
          onNavigate?.call(AppRoutes.search);
          return const Scaffold(body: Text('MÀN TÌM KIẾM'));
        },
      ),
      GoRoute(
        path: '/video/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          onNavigate?.call('/video/$id');
          return Scaffold(body: Text('MÀN VIDEO $id'));
        },
      ),
      GoRoute(
        path: AppRoutes.shorts,
        builder: (context, state) {
          final start = state.uri.queryParameters['start'];
          onNavigate?.call('${AppRoutes.shorts}?start=$start');
          return Scaffold(body: Text('MÀN SHORTS $start'));
        },
      ),
      GoRoute(
        path: '/playlist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          onNavigate?.call('/playlist/$id');
          return Scaffold(body: Text('MÀN PLAYLIST $id'));
        },
      ),
      GoRoute(
        path: AppRoutes.upload,
        builder: (context, state) {
          onNavigate?.call(AppRoutes.upload);
          return const Scaffold(body: Text('MÀN UPLOAD'));
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          onNavigate?.call(AppRoutes.login);
          return const Scaffold(body: Text('MÀN LOGIN'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        Provider<ChannelService>.value(value: fakeChannelService),
        Provider<AuthService>.value(value: fakeAuthService),
        Provider<NotificationService>.value(value: FakeNotificationService()),
        Provider<PlaylistService>.value(value: FakePlaylistService()),
        Provider<VideoService>.value(value: FakeVideoService()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: router,
      ),
    ),
  );

  await tester.pumpAndSettle();
}
