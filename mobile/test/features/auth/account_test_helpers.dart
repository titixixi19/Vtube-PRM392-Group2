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
import 'package:vtube/data/services/history_service.dart';
import 'package:vtube/data/services/notification_service.dart';
import 'package:vtube/data/services/playlist_service.dart';
import 'package:vtube/features/auth/account_screen.dart';

/// Hàm và lớp giả cho test màn Trang "Bạn" (Màn 4). Tách riêng để không xung đột với nhánh các màn khác.

const accountEmail = 'demo@vtube.vn';
const accountPassword = '123456';
const accountName = 'Nguyễn Văn A';
const accountHandle = 'nguyenvana';
const accountChannelId = 7;

/// Nhãn của các màn đích trong router giả, để kiểm tra điều hướng.
const homeLabel = 'TRANG CHỦ';
const loginLabel = 'MÀN ĐĂNG NHẬP';
const historyLabel = 'MÀN LỊCH SỬ';
String playlistLabel(int id) => 'MÀN PLAYLIST $id';
String channelLabel(int id) => 'MÀN KÊNH $id';
String videoLabel(int id) => 'MÀN VIDEO $id';

const networkError = ApiException('Không kết nối được máy chủ. Kiểm tra mạng hoặc backend.');

Me accountUser({int id = 1, String name = accountName, int subscribers = 1200}) => Me(
      id: id,
      email: accountEmail,
      displayName: name,
      createdAt: '2026-01-01T00:00:00Z',
      channel:
          ChannelBrief(id: accountChannelId, name: accountName, handle: accountHandle, subscriberCount: subscribers),
    );

Video sampleVideo(int id, {int duration = 600}) => Video(
      id: id,
      title: 'Video số $id',
      videoUrl: '/media/$id.mp4',
      durationSeconds: duration,
      publishedAt: '2026-10-01T00:00:00Z',
      channel: const ChannelBrief(id: 2, name: 'VTech Studio', handle: 'vtechstudio'),
    );

HistoryItem sampleHistory(int id, {int progress = 300}) =>
    HistoryItem(watchedAt: '2026-10-20T00:00:00Z', progressSeconds: progress, video: sampleVideo(id));

Playlist samplePlaylist(int id, String title,
        {String kind = 'custom', int videoCount = 3, String visibility = 'private'}) =>
    Playlist(
      id: id,
      title: title,
      kind: kind,
      videoCount: videoCount,
      visibility: visibility,
      updatedAt: '2026-10-20T00:00:00Z',
      ownerUserId: 1,
      ownerName: accountName,
      ownerChannelId: accountChannelId,
    );

/// Playlist của tài khoản demo: 2 playlist hệ thống + 1 playlist tự tạo.
List<Playlist> samplePlaylists() => [
      samplePlaylist(1, 'Video đã thích', kind: 'liked', videoCount: 5),
      samplePlaylist(2, 'Xem sau', kind: 'watch_later', videoCount: 2),
      samplePlaylist(10, 'Học Flutter', videoCount: 3, visibility: 'public'),
    ];

class FakeAccountAuthService extends AuthService {
  FakeAccountAuthService(super.api);

  Me user = accountUser();
  int meCalls = 0;
  int logoutCalls = 0;

  @override
  Future<AuthResult> login(String email, String password) async => AuthResult('token-demo', user);

  @override
  Future<Me> me() async {
    meCalls++;
    return user;
  }

  @override
  Future<void> logout() async => logoutCalls++;
}

class FakeHistoryService extends HistoryService {
  FakeHistoryService(super.api);

  List<HistoryItem> items = [for (var i = 1; i <= 6; i++) sampleHistory(i)];

  /// Gán để lần gọi tiếp theo lỗi.
  Object? error;

  /// Gán để giữ request ở trạng thái "đang tải".
  Completer<void>? hold;

  /// Tham số size của từng lần gọi list().
  final sizes = <int>[];

  @override
  Future<PageResult<HistoryItem>> list({String type = 'all', String? q, int page = 0, int size = 20}) async {
    sizes.add(size);
    // Chốt dữ liệu, lỗi và Completer tại lúc gọi, để mỗi request trả kết quả của riêng nó (dù xong muộn).
    final result = items.take(size).toList();
    final err = error;
    final wait = hold;
    if (wait != null) await wait.future;
    if (err != null) throw err;
    return PageResult(items: result, page: page, size: size, hasMore: false);
  }
}

class FakePlaylistService extends PlaylistService {
  FakePlaylistService(super.api);

  List<Playlist> playlists = samplePlaylists();
  Object? mineError;
  Object? writeError;
  int mineCalls = 0;
  int _nextId = 100;

  final created = <(String, String)>[]; // (tên, chế độ hiển thị)
  final renamed = <(int, String)>[];
  final deleted = <int>[];

  @override
  Future<List<Playlist>> mine({int? videoId}) async {
    mineCalls++;
    if (mineError != null) throw mineError!;
    return [...playlists];
  }

  @override
  Future<Playlist> create(String title, {String? description, String visibility = 'private'}) async {
    if (writeError != null) throw writeError!;
    created.add((title, visibility));
    final p = samplePlaylist(_nextId++, title, videoCount: 0, visibility: visibility);
    playlists.add(p);
    return p;
  }

  @override
  Future<Playlist> update(int id, {String? title, String? description, String? visibility}) async {
    if (writeError != null) throw writeError!;
    renamed.add((id, title!));
    final old = playlists.firstWhere((p) => p.id == id);
    final p = samplePlaylist(id, title, videoCount: old.videoCount, visibility: old.visibility);
    playlists = [for (final x in playlists) x.id == id ? p : x];
    return p;
  }

  @override
  Future<void> delete(int id) async {
    if (writeError != null) throw writeError!;
    deleted.add(id);
    playlists.removeWhere((p) => p.id == id);
  }
}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService(super.api);

  @override
  Future<int> unreadCount() async => 0;
}

class AccountTestEnv {
  final FakeAccountAuthService authService;
  final FakeHistoryService history;
  final FakePlaylistService playlists;
  final NotificationService notifications;
  final AuthProvider auth;

  AccountTestEnv._(this.authService, this.history, this.playlists, this.notifications, this.auth);

  factory AccountTestEnv() {
    SharedPreferences.setMockInitialValues({});
    final tokens = TokenStorage();
    final api = ApiClient(tokens);
    final authService = FakeAccountAuthService(api);
    return AccountTestEnv._(
      authService,
      FakeHistoryService(api),
      FakePlaylistService(api),
      _FakeNotificationService(api),
      AuthProvider(authService, tokens, api),
    );
  }

  Future<void> signIn() => auth.login(accountEmail, accountPassword);
}

Widget _label(String text) => Scaffold(appBar: AppBar(), body: Center(child: Text(text)));

/// Dựng app tối giản quanh màn Bạn. [signedIn]: đăng nhập trước khi mở màn.
/// [settle] = false khi còn vòng quay chạy mãi (đang tải): chỉ vẽ vài khung hình.
Future<void> pumpAccount(WidgetTester tester, AccountTestEnv env, {bool signedIn = true, bool settle = true}) async {
  // Font test rộng hơn font thật: dùng khung 480 dp, cao để thấy cả màn.
  tester.view.physicalSize = const Size(480 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  if (signedIn) await env.signIn();

  final router = GoRouter(
    initialLocation: AppRoutes.you,
    routes: [
      GoRoute(path: AppRoutes.you, builder: (_, __) => const AccountScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, __) => _label(homeLabel)),
      GoRoute(path: AppRoutes.login, builder: (_, __) => _label(loginLabel)),
      GoRoute(path: AppRoutes.history, builder: (_, __) => _label(historyLabel)),
      GoRoute(path: AppRoutes.search, builder: (_, __) => _label('MÀN TÌM KIẾM')),
      GoRoute(path: AppRoutes.notifications, builder: (_, __) => _label('MÀN THÔNG BÁO')),
      GoRoute(path: '/playlist/:id', builder: (_, s) => _label(playlistLabel(int.parse(s.pathParameters['id']!)))),
      GoRoute(path: '/channel/:id', builder: (_, s) => _label(channelLabel(int.parse(s.pathParameters['id']!)))),
      GoRoute(path: '/video/:id', builder: (_, s) => _label(videoLabel(int.parse(s.pathParameters['id']!)))),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<HistoryService>.value(value: env.history),
        Provider<PlaylistService>.value(value: env.playlists),
        Provider<NotificationService>.value(value: env.notifications),
        ChangeNotifierProvider<AuthProvider>.value(value: env.auth),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }
}

/// Cuộn tới widget rồi bấm.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Nhấn giữ thẻ playlist có tên [title].
Future<void> longPressPlaylist(WidgetTester tester, String title) async {
  final card = find.text(title).first;
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.longPress(card);
  await tester.pumpAndSettle();
}

Finder dialogField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));

Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.text(text));
