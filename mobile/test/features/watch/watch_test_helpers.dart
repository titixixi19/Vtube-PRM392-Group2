import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/app/theme.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/auth_service.dart';
import 'package:vtube/data/services/channel_service.dart';
import 'package:vtube/data/services/comment_service.dart';
import 'package:vtube/data/services/history_service.dart';
import 'package:vtube/data/services/video_service.dart';

const dummyChannel = ChannelBrief(
  id: 1,
  name: 'VTech Studio',
  handle: 'vtechstudio',
  avatarUrl: 'https://i.pravatar.cc/300?img=59',
  subscriberCount: 1500000,
  verified: true,
);

Video createDummyVideo({
  required int id,
  String title = 'Video Tiêu Đề',
  bool isShort = false,
  int likeCount = 100,
  int commentCount = 10,
  ViewerState? viewer,
}) =>
    Video(
      id: id,
      title: title,
      description: 'Mô tả video mẫu #vtube #flutter',
      videoUrl: 'https://example.com/video$id.mp4',
      thumbnailUrl: 'https://example.com/thumb$id.jpg',
      durationSeconds: isShort ? 30 : 600,
      viewCount: 15000,
      likeCount: likeCount,
      dislikeCount: 5,
      commentCount: commentCount,
      isShort: isShort,
      publishedAt: '2026-01-01T00:00:00Z',
      channel: dummyChannel,
      viewer: viewer,
    );

Comment createDummyComment({
  required int id,
  int videoId = 1,
  int? parentId,
  String content = 'Bình luận mẫu',
  int likeCount = 10,
  int replyCount = 0,
  bool pinned = false,
  bool hearted = false,
  int myReaction = 0,
  bool byChannelOwner = false,
}) =>
    Comment(
      id: id,
      videoId: videoId,
      parentId: parentId,
      content: content,
      likeCount: likeCount,
      replyCount: replyCount,
      pinned: pinned,
      hearted: hearted,
      createdAt: '2026-01-01T00:00:00Z',
      author: const CommentAuthor(
        userId: 2,
        channelId: 2,
        name: 'Người xem A',
        handle: 'user_a',
        avatarUrl: 'https://i.pravatar.cc/300?img=12',
      ),
      byChannelOwner: byChannelOwner,
      myReaction: myReaction,
    );

class FakeVideoService extends VideoService {
  FakeVideoService() : super(ApiClient(TokenStorage()));

  int categoriesCalls = 0;
  int feedCalls = 0;
  int shortsCalls = 0;
  int detailCalls = 0;
  int relatedCalls = 0;
  int addViewCalls = 0;
  int reactCalls = 0;
  int notInterestedCalls = 0;

  String? lastFeedCategory;
  int lastFeedPage = 0;
  String? lastRelatedFilter;
  int? lastReactValue;

  List<Category> returnCategories = [
    const Category(id: 1, name: 'Âm nhạc', slug: 'music'),
    const Category(id: 2, name: 'Gaming', slug: 'gaming'),
  ];

  PageResult<Video> returnFeed = PageResult(
    items: [
      createDummyVideo(id: 1, title: 'Video Feed 1'),
      createDummyVideo(id: 2, title: 'Video Feed 2'),
      createDummyVideo(id: 3, title: 'Video Feed 3'),
    ],
    page: 0,
    size: 20,
    hasMore: true,
  );

  PageResult<Video> returnShorts = PageResult(
    items: [
      createDummyVideo(id: 101, title: 'Shorts 1', isShort: true),
      createDummyVideo(id: 102, title: 'Shorts 2', isShort: true),
    ],
    page: 0,
    size: 10,
    hasMore: true,
  );

  PageResult<Video> returnRelated = PageResult(
    items: [
      createDummyVideo(id: 201, title: 'Video Liên Quan 1'),
      createDummyVideo(id: 202, title: 'Video Liên Quan 2'),
    ],
    page: 0,
    size: 20,
    hasMore: false,
  );

  Video returnDetail = createDummyVideo(id: 1, title: 'Video Chi Tiết');

  final Map<String, Completer<PageResult<Video>>> feedCompleters = {};

  @override
  Future<List<Category>> categories() async {
    categoriesCalls++;
    return returnCategories;
  }

  @override
  Future<PageResult<Video>> feed({String? category, int page = 0, int size = 20}) async {
    feedCalls++;
    lastFeedCategory = category;
    lastFeedPage = page;
    final key = '${category}_$page';
    if (feedCompleters.containsKey(key)) {
      return await feedCompleters[key]!.future;
    }
    return returnFeed;
  }

  @override
  Future<PageResult<Video>> shorts({int page = 0, int size = 10}) async {
    shortsCalls++;
    return returnShorts;
  }

  @override
  Future<Video> detail(int id) async {
    detailCalls++;
    return returnDetail;
  }

  @override
  Future<PageResult<Video>> related(int id, {String filter = 'all', int page = 0, int size = 20}) async {
    relatedCalls++;
    lastRelatedFilter = filter;
    return returnRelated;
  }

  @override
  Future<void> addView(int id) async {
    addViewCalls++;
  }

  @override
  Future<ReactionResult> react(int id, int value) async {
    reactCalls++;
    lastReactValue = value;
    return ReactionResult(value == 1 ? 101 : 100, 5, value);
  }

  @override
  Future<void> notInterested(int id) async {
    notInterestedCalls++;
  }
}

class FakeCommentService extends CommentService {
  FakeCommentService() : super(ApiClient(TokenStorage()));

  int listCalls = 0;
  int repliesCalls = 0;
  int createCalls = 0;
  int deleteCalls = 0;
  int reactCalls = 0;
  int togglePinCalls = 0;
  int toggleHeartCalls = 0;

  String? lastSort;
  int lastPage = 0;
  ApiException? reactError;

  PageResult<Comment> returnList = PageResult(
    items: [
      createDummyComment(id: 1, content: 'Bình luận 1', likeCount: 5),
      createDummyComment(id: 2, content: 'Bình luận 2', replyCount: 2),
    ],
    page: 0,
    size: 20,
    hasMore: false,
  );

  PageResult<Comment> returnReplies = PageResult(
    items: [
      createDummyComment(id: 11, parentId: 2, content: 'Câu trả lời con 1'),
    ],
    page: 0,
    size: 20,
    hasMore: false,
  );

  @override
  Future<PageResult<Comment>> list(int videoId, {String sort = 'top', int page = 0, int size = 20}) async {
    listCalls++;
    lastSort = sort;
    lastPage = page;
    return returnList;
  }

  @override
  Future<PageResult<Comment>> replies(int commentId, {int page = 0, int size = 20}) async {
    repliesCalls++;
    return returnReplies;
  }

  @override
  Future<Comment> create(int videoId, String content, {int? parentId}) async {
    createCalls++;
    return createDummyComment(
      id: 999,
      videoId: videoId,
      parentId: parentId,
      content: content,
    );
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
  }

  @override
  Future<Comment> react(int id, int value) async {
    reactCalls++;
    if (reactError != null) throw reactError!;
    return createDummyComment(id: id, likeCount: value == 1 ? 6 : 5, myReaction: value);
  }

  @override
  Future<Comment> togglePin(int id) async {
    togglePinCalls++;
    return createDummyComment(id: id, pinned: true);
  }

  @override
  Future<Comment> toggleHeart(int id) async {
    toggleHeartCalls++;
    return createDummyComment(id: id, hearted: true);
  }
}

class FakeHistoryService extends HistoryService {
  FakeHistoryService() : super(ApiClient(TokenStorage()));

  int saveProgressCalls = 0;
  int lastVideoId = 0;
  int lastProgressSeconds = 0;

  @override
  Future<bool> saveProgress(int videoId, int progressSeconds) async {
    saveProgressCalls++;
    lastVideoId = videoId;
    lastProgressSeconds = progressSeconds;
    return true;
  }
}

class FakeChannelService extends ChannelService {
  FakeChannelService() : super(ApiClient(TokenStorage()));

  int subscribeCalls = 0;
  int unsubscribeCalls = 0;

  @override
  Future<SubscriptionResult> subscribe(int channelId, {String? notifyMode}) async {
    subscribeCalls++;
    return const SubscriptionResult(true, 'all', 1500001);
  }

  @override
  Future<SubscriptionResult> unsubscribe(int channelId) async {
    unsubscribeCalls++;
    return const SubscriptionResult(false, null, 1500000);
  }
}

class FakeAuthService extends AuthService {
  FakeAuthService(super.api);

  @override
  Future<AuthResult> login(String email, String password) async => const AuthResult(
        'fake_token',
        Me(
          id: 1,
          email: 'user@test.vn',
          displayName: 'User Test',
          createdAt: '2026-01-01T00:00:00Z',
          channel: dummyChannel,
        ),
      );

  @override
  Future<Me> me() async => const Me(
        id: 1,
        email: 'user@test.vn',
        displayName: 'User Test',
        createdAt: '2026-01-01T00:00:00Z',
        channel: dummyChannel,
      );
}

class FakeAuthProvider extends AuthProvider {
  final bool _loggedIn;

  FakeAuthProvider({bool isLoggedIn = false, TokenStorage? tokens, ApiClient? api, AuthService? auth})
      : _loggedIn = isLoggedIn,
        super(
          auth ?? FakeAuthService(api ?? ApiClient(tokens ?? TokenStorage())),
          tokens ?? TokenStorage(),
          api ?? ApiClient(tokens ?? TokenStorage()),
        );

  @override
  bool get isLoggedIn => _loggedIn;

  @override
  Me? get user => _loggedIn
      ? const Me(
          id: 1,
          email: 'user@test.vn',
          displayName: 'User Test',
          createdAt: '2026-01-01T00:00:00Z',
          channel: dummyChannel,
        )
      : null;
}

Widget buildTestWatchApp({
  required Widget child,
  FakeVideoService? videoService,
  FakeCommentService? commentService,
  FakeHistoryService? historyService,
  FakeChannelService? channelService,
  AuthProvider? authProvider,
  bool isLoggedIn = false,
}) {
  SharedPreferences.setMockInitialValues({});
  final tokens = TokenStorage();
  final api = ApiClient(tokens);
  final authService = FakeAuthService(api);

  final effectiveAuth = authProvider ??
      (isLoggedIn
          ? FakeAuthProvider(isLoggedIn: true, tokens: tokens, api: api, auth: authService)
          : AuthProvider(authService, tokens, api));

  return MultiProvider(
    providers: [
      Provider<VideoService>.value(value: videoService ?? FakeVideoService()),
      Provider<CommentService>.value(value: commentService ?? FakeCommentService()),
      Provider<HistoryService>.value(value: historyService ?? FakeHistoryService()),
      Provider<ChannelService>.value(value: channelService ?? FakeChannelService()),
      ChangeNotifierProvider<AuthProvider>.value(
        value: effectiveAuth,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: child,
    ),
  );
}
