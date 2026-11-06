import 'package:flutter/material.dart';
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
import 'package:vtube/features/explore/subscriptions_screen.dart';
import 'package:vtube/features/explore/widgets/all_subscriptions_screen.dart';

SubscribedChannel testSubscribedChannel({
  int id = 1,
  String name = 'Vietnam Vibes',
  String handle = 'vietnamvibes',
  bool hasNew = false,
  String notifyMode = 'personalized',
  int subscriberCount = 1200000,
}) =>
    SubscribedChannel(
      channel: ChannelBrief(
        id: id,
        name: name,
        handle: handle,
        avatarUrl: '/avatars/$id.jpg',
        verified: true,
        subscriberCount: subscriberCount,
      ),
      notifyMode: notifyMode,
      hasNew: hasNew,
      lastUploadAt: '2026-10-01T00:00:00Z',
    );

Video testFeedVideo({
  int id = 1,
  String title = 'Khám phá ẩm thực Hà Nội phố cổ',
  bool isLive = false,
  int duration = 900,
  int viewCount = 85000,
  String channelName = 'Ẩm Thực Bụi',
  int channelId = 2,
}) =>
    Video(
      id: id,
      title: title,
      videoUrl: '/videos/$id.mp4',
      thumbnailUrl: '/thumbs/$id.jpg',
      durationSeconds: duration,
      viewCount: viewCount,
      isShort: false,
      isLive: isLive,
      publishedAt: '2026-10-02T00:00:00Z',
      channel: ChannelBrief(id: channelId, name: channelName, handle: 'amthucbui'),
    );

class FakeChannelService extends ChannelService {
  FakeChannelService() : super(ApiClient(TokenStorage()));

  int mySubscriptionsCalls = 0;
  String? lastSubscriptionsSort;
  List<SubscribedChannel> returnSubscriptions = [
    testSubscribedChannel(id: 1, name: 'Vietnam Vibes', hasNew: false),
    testSubscribedChannel(id: 2, name: 'Ẩm Thực Bụi', hasNew: true),
    testSubscribedChannel(id: 3, name: 'Công Nghệ 24h', hasNew: false),
    testSubscribedChannel(id: 4, name: 'Âm Nhạc Trẻ', hasNew: true),
    testSubscribedChannel(id: 5, name: 'Du Lịch 3 Miền', hasNew: false),
  ];
  ApiException? subscriptionsError;

  int subscriptionFeedCalls = 0;
  int? lastFeedChannelId;
  String? lastFeedType;
  int? lastFeedPage;
  PageResult<Video> returnFeed = PageResult(
    items: [
      testFeedVideo(id: 1, title: 'Ẩm thực đêm Hà Nội', isLive: true, channelName: 'Ẩm Thực Bụi', channelId: 2),
      testFeedVideo(id: 2, title: 'Checkin Đà Lạt mùa mưa', channelName: 'Du Lịch 3 Miền', channelId: 5),
      testFeedVideo(id: 3, title: 'Review iPhone mới nhất', channelName: 'Công Nghệ 24h', channelId: 3),
    ],
    page: 0,
    size: 20,
    hasMore: false,
  );
  ApiException? feedError;

  int subscribeCalls = 0;
  int? lastSubscribeId;
  String? lastSubscribeMode;

  int unsubscribeCalls = 0;
  int? lastUnsubscribeId;

  @override
  Future<List<SubscribedChannel>> mySubscriptions({String sort = 'recent'}) async {
    mySubscriptionsCalls++;
    lastSubscriptionsSort = sort;
    if (subscriptionsError != null) throw subscriptionsError!;
    return returnSubscriptions;
  }

  @override
  Future<PageResult<Video>> subscriptionFeed({int? channelId, String type = 'all', int page = 0, int size = 20}) async {
    subscriptionFeedCalls++;
    lastFeedChannelId = channelId;
    lastFeedType = type;
    lastFeedPage = page;
    if (feedError != null) throw feedError!;
    return returnFeed;
  }

  @override
  Future<SubscriptionResult> subscribe(int id, {String? notifyMode}) async {
    subscribeCalls++;
    lastSubscribeId = id;
    lastSubscribeMode = notifyMode;
    return SubscriptionResult(true, notifyMode ?? 'all', 1200001);
  }

  @override
  Future<SubscriptionResult> unsubscribe(int id) async {
    unsubscribeCalls++;
    lastUnsubscribeId = id;
    return const SubscriptionResult(false, 'none', 1199999);
  }
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super(ApiClient(TokenStorage()));

  @override
  Future<int> unreadCount() async => 0;
}

class FakeAuthService extends AuthService {
  FakeAuthService() : super(ApiClient(TokenStorage()));

  @override
  Future<Me> me() async => const Me(
        id: 1,
        email: 'demo@vtube.vn',
        displayName: 'Demo User',
        createdAt: '2026-01-01T00:00:00Z',
        channel: ChannelBrief(id: 1, name: 'Demo Channel', handle: 'demo'),
      );

  @override
  Future<AuthResult> login(String email, String password) async => const AuthResult(
        'fake_token',
        Me(
          id: 1,
          email: 'demo@vtube.vn',
          displayName: 'Demo User',
          createdAt: '2026-01-01T00:00:00Z',
          channel: ChannelBrief(id: 1, name: 'Demo Channel', handle: 'demo'),
        ),
      );
}

class FakePlaylistService extends PlaylistService {
  FakePlaylistService() : super(ApiClient(TokenStorage()));

  @override
  Future<Playlist> addWatchLater(int videoId) async => const Playlist(
        id: 1,
        title: 'Xem sau',
        videoCount: 1,
        updatedAt: '2026-01-01T00:00:00Z',
        ownerUserId: 1,
        ownerName: 'Demo',
        ownerChannelId: 1,
      );
}

class FakeVideoService extends VideoService {
  FakeVideoService() : super(ApiClient(TokenStorage()));

  @override
  Future<void> notInterested(int videoId) async {}
}

Widget buildTestSubscriptionsScreen({
  required FakeChannelService channelService,
  bool isLoggedIn = true,
  void Function(String route)? onPushed,
}) {
  SharedPreferences.setMockInitialValues({});
  final tokens = TokenStorage();
  final authService = FakeAuthService();
  final authProvider = AuthProvider(authService, tokens, ApiClient(tokens));
  if (isLoggedIn) {
    tokens.save('fake_token');
    authProvider.login('demo@vtube.vn', '123456');
  }

  final router = GoRouter(
    initialLocation: AppRoutes.subscriptions,
    routes: [
      GoRoute(
        path: AppRoutes.subscriptions,
        builder: (context, state) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: '/video/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          onPushed?.call('/video/$id');
          return Scaffold(body: Text('VideoScreen: $id'));
        },
      ),
      GoRoute(
        path: '/channel/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          onPushed?.call('/channel/$id');
          return Scaffold(body: Text('ChannelScreen: $id'));
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) {
          onPushed?.call(AppRoutes.search);
          return const Scaffold(body: Text('SearchScreen'));
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          onPushed?.call(AppRoutes.login);
          return const Scaffold(body: Text('LoginScreen'));
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) {
          onPushed?.call(AppRoutes.home);
          return const Scaffold(body: Text('HomeScreen'));
        },
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      Provider<ChannelService>.value(value: channelService),
      Provider<NotificationService>.value(value: FakeNotificationService()),
      Provider<PlaylistService>.value(value: FakePlaylistService()),
      Provider<VideoService>.value(value: FakeVideoService()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.dark(),
      routerConfig: router,
    ),
  );
}

Widget buildTestAllSubscriptionsScreen({
  required FakeChannelService channelService,
  void Function(String route)? onPushed,
}) {
  return MultiProvider(
    providers: [
      Provider<ChannelService>.value(value: channelService),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const AllSubscriptionsScreen(),
    ),
  );
}
