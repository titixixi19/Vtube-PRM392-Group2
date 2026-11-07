import 'dart:async';

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
import 'package:vtube/data/services/playlist_service.dart';
import 'package:vtube/data/services/search_service.dart';
import 'package:vtube/data/services/video_service.dart';
import 'package:vtube/features/explore/search_results_screen.dart';
import 'package:vtube/features/explore/search_screen.dart';

Finder findMainVerticalScrollable() => find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );

Channel testChannel({
  int id = 1,
  int userId = 1,
  String name = 'VTech Studio',
  String handle = 'vtechstudio',
  int subscriberCount = 1500000,
  int videoCount = 42,
  bool subscribed = false,
  bool verified = true,
}) =>
    Channel(
      id: id,
      userId: userId,
      name: name,
      handle: handle,
      subscriberCount: subscriberCount,
      videoCount: videoCount,
      subscribed: subscribed,
      verified: verified,
      createdAt: '2026-01-01T00:00:00Z',
    );

Video testVideo({
  int id = 1,
  String title = 'Học Flutter từ cơ bản đến nâng cao',
  bool isShort = false,
  int duration = 600,
  int viewCount = 120000,
  String channelName = 'VTech Studio',
}) =>
    Video(
      id: id,
      title: title,
      videoUrl: '/videos/$id.mp4',
      thumbnailUrl: '/thumbs/$id.jpg',
      durationSeconds: duration,
      viewCount: viewCount,
      isShort: isShort,
      publishedAt: '2026-10-01T00:00:00Z',
      channel: ChannelBrief(id: 1, name: channelName, handle: 'vtechstudio'),
    );

Playlist testPlaylist({
  int id = 1,
  String title = 'Lập trình Flutter full khóa học',
  int videoCount = 12,
  String ownerName = 'VTech Studio',
}) =>
    Playlist(
      id: id,
      title: title,
      videoCount: videoCount,
      updatedAt: '2026-10-05T00:00:00Z',
      ownerUserId: 1,
      ownerName: ownerName,
      ownerChannelId: 1,
    );

/// Lớp giả lập SearchService cho kiểm thử Màn 9 & 10.
class FakeSearchService extends SearchService {
  FakeSearchService() : super(ApiClient(TokenStorage()));

  int suggestionsCalls = 0;
  String? lastSuggestionsQuery;
  SearchSuggestions returnSuggestions = const SearchSuggestions(
    history: ['flutter', 'vtube', 'react native'],
    suggestions: ['flutter tutorial', 'flutter animation', 'flutter state management'],
  );
  ApiException? suggestionsError;

  final Map<String, Completer<SearchSuggestions>> queryCompleters = {};
  final Map<String, Completer<SearchResult>> searchCompleters = {};

  int deleteCalls = 0;
  String? lastDeletedKeyword;
  ApiException? deleteError;

  int searchCalls = 0;
  String? lastSearchQuery;
  SearchFilters? lastSearchFilters;
  int? lastSearchPage;
  SearchResult returnSearchResult = SearchResult(
    channels: [testChannel()],
    videos: List.generate(6, (i) => testVideo(id: i + 1, title: 'Flutter Video ${i + 1}')),
    shorts: List.generate(3, (i) => testVideo(id: 100 + i, title: 'Flutter Short ${i + 1}', isShort: true)),
    playlists: [testPlaylist()],
    page: 0,
    hasMore: false,
  );
  ApiException? searchError;

  @override
  Future<SearchSuggestions> suggestions(String q) async {
    suggestionsCalls++;
    lastSuggestionsQuery = q;
    if (queryCompleters.containsKey(q)) {
      return await queryCompleters[q]!.future;
    }
    if (suggestionsError != null) throw suggestionsError!;
    return returnSuggestions;
  }

  @override
  Future<void> deleteHistory({String? keyword}) async {
    deleteCalls++;
    lastDeletedKeyword = keyword;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<SearchResult> search(String q,
      {SearchFilters filters = const SearchFilters(), int page = 0, int size = 20}) async {
    searchCalls++;
    lastSearchQuery = q;
    lastSearchFilters = filters;
    lastSearchPage = page;
    if (searchCompleters.containsKey(filters.type)) {
      return await searchCompleters[filters.type]!.future;
    }
    if (searchError != null) throw searchError!;
    return returnSearchResult;
  }
}

class FakeChannelService extends ChannelService {
  FakeChannelService() : super(ApiClient(TokenStorage()));

  int subscribeCalls = 0;
  int unsubscribeCalls = 0;
  int? lastChannelId;
  ApiException? error;

  @override
  Future<SubscriptionResult> subscribe(int id, {String? notifyMode}) async {
    subscribeCalls++;
    lastChannelId = id;
    if (error != null) throw error!;
    return const SubscriptionResult(true, 'all', 1500001);
  }

  @override
  Future<SubscriptionResult> unsubscribe(int id) async {
    unsubscribeCalls++;
    lastChannelId = id;
    if (error != null) throw error!;
    return const SubscriptionResult(false, 'none', 1499999);
  }
}

class FakeVideoService extends VideoService {
  FakeVideoService() : super(ApiClient(TokenStorage()));

  int notInterestedCalls = 0;
  int? lastNotInterestedId;

  @override
  Future<void> notInterested(int videoId) async {
    notInterestedCalls++;
    lastNotInterestedId = videoId;
  }
}

class FakePlaylistService extends PlaylistService {
  FakePlaylistService() : super(ApiClient(TokenStorage()));

  int watchLaterCalls = 0;
  int? lastWatchLaterId;

  @override
  Future<Playlist> addWatchLater(int videoId) async {
    watchLaterCalls++;
    lastWatchLaterId = videoId;
    return testPlaylist();
  }
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

/// Helper bọc MaterialApp và MultiProvider cho SearchScreen (Màn 9).
Widget buildTestSearchScreen({
  required FakeSearchService searchService,
  String? initialQuery,
  void Function(String route)? onPushed,
}) {
  final router = GoRouter(
    initialLocation: initialQuery != null && initialQuery.isNotEmpty
        ? '/search?q=${Uri.encodeQueryComponent(initialQuery)}'
        : AppRoutes.search,
    routes: [
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => SearchScreen(initialQuery: state.uri.queryParameters['q'] ?? initialQuery),
      ),
      GoRoute(
        path: '/search/results',
        builder: (context, state) {
          final q = state.uri.queryParameters['q'] ?? '';
          onPushed?.call(AppRoutes.searchResults(q));
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
            body: Text('Results: $q'),
          );
        },
      ),
    ],
  );

  return MultiProvider(
    providers: [
      Provider<SearchService>.value(value: searchService),
    ],
    child: MaterialApp.router(
      theme: AppTheme.dark(),
      routerConfig: router,
    ),
  );
}

/// Helper bọc MaterialApp và MultiProvider cho SearchResultsScreen (Màn 10).
Widget buildTestSearchResultsScreen({
  required FakeSearchService searchService,
  FakeChannelService? channelService,
  FakeVideoService? videoService,
  FakePlaylistService? playlistService,
  String query = 'flutter',
  bool isLoggedIn = false,
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
    initialLocation: AppRoutes.searchResults(query),
    routes: [
      GoRoute(
        path: '/search/results',
        builder: (context, state) => SearchResultsScreen(
          query: state.uri.queryParameters['q'] ?? query,
        ),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) {
          final q = state.uri.queryParameters['q'] ?? '';
          onPushed?.call('${AppRoutes.search}?q=$q');
          return Scaffold(body: Text('SearchScreen: $q'));
        },
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
        path: AppRoutes.shorts,
        builder: (context, state) {
          final start = state.uri.queryParameters['start'] ?? '';
          onPushed?.call('${AppRoutes.shorts}?start=$start');
          return Scaffold(body: Text('ShortsScreen: $start'));
        },
      ),
      GoRoute(
        path: '/playlist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          onPushed?.call('/playlist/$id');
          return Scaffold(body: Text('PlaylistScreen: $id'));
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const Scaffold(body: Text('LoginScreen')),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      Provider<SearchService>.value(value: searchService),
      Provider<ChannelService>.value(value: channelService ?? FakeChannelService()),
      Provider<VideoService>.value(value: videoService ?? FakeVideoService()),
      Provider<PlaylistService>.value(value: playlistService ?? FakePlaylistService()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.dark(),
      routerConfig: router,
    ),
  );
}
