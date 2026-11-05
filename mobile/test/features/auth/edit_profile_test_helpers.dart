import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
import 'package:vtube/data/services/upload_service.dart';
import 'package:vtube/features/auth/edit_profile_screen.dart';
import 'package:vtube/features/auth/widgets/auth_text_field.dart';
import 'package:vtube/features/auth/widgets/avatar_picker.dart';
import 'package:vtube/features/auth/widgets/banner_picker.dart';

/// Hàm và lớp giả cho test màn Chỉnh sửa hồ sơ (Màn 17). Tách riêng để không xung đột với nhánh các màn khác.

const profileEmail = 'demo@vtube.vn';
const profileName = 'Nguyễn Văn A';
const profileChannelName = 'Kênh của A';
const profileHandle = 'nguyenvana';
const profileDescription = 'Chia sẻ mẹo lập trình Flutter mỗi tuần';
const profileChannelId = 7;

const previousLabel = 'MÀN TRƯỚC';
const youLabel = 'TRANG BẠN';
const loginLabel = 'MÀN ĐĂNG NHẬP';

const networkError = ApiException('Không kết nối được máy chủ. Kiểm tra mạng hoặc backend.');

/// Một lần gọi AuthService.updateMe.
typedef UpdateMeCall = ({String? displayName, String? avatarUrl});

/// Một lần gọi ChannelService.updateMine.
typedef UpdateChannelCall = ({String? name, String? description, String? avatarUrl, String? bannerUrl});

/// AuthService giả: giữ một tài khoản trong bộ nhớ, updateMe sửa thẳng vào tài khoản đó.
class FakeProfileAuthService extends AuthService {
  FakeProfileAuthService(super.api);

  /// Đổi id + tên rồi đăng nhập lại để giả lập chuyển sang tài khoản khác.
  int userId = 1;
  String displayName = profileName;
  String? avatarUrl;
  int meCalls = 0;
  final updateCalls = <UpdateMeCall>[];

  /// Gán để lần updateMe tiếp theo lỗi.
  Object? updateError;

  /// Gán để giữ updateMe ở trạng thái "đang lưu".
  Completer<void>? hold;

  Me get user => Me(
        id: userId,
        email: profileEmail,
        displayName: displayName,
        avatarUrl: avatarUrl,
        createdAt: '2026-01-01T00:00:00Z',
        channel:
            ChannelBrief(id: profileChannelId, name: profileChannelName, handle: profileHandle, avatarUrl: avatarUrl),
      );

  @override
  Future<AuthResult> login(String email, String password) async => AuthResult('token-demo', user);

  @override
  Future<Me> me() async {
    meCalls++;
    return user;
  }

  @override
  Future<Me> updateMe({String? displayName, String? avatarUrl}) async {
    updateCalls.add((displayName: displayName, avatarUrl: avatarUrl));
    if (hold != null) await hold!.future;
    final err = updateError;
    if (err != null) {
      updateError = null;
      throw err;
    }
    if (displayName != null) this.displayName = displayName;
    if (avatarUrl != null) this.avatarUrl = avatarUrl;
    return user;
  }

  @override
  Future<void> logout() async {}
}

/// ChannelService giả cho kênh của tài khoản đang sửa.
class FakeProfileChannelService extends ChannelService {
  FakeProfileChannelService(super.api);

  String name = profileChannelName;
  String? description = profileDescription;
  String? bannerUrl;
  final getCalls = <int>[];
  final updateCalls = <UpdateChannelCall>[];

  /// Gán để lần get() tiếp theo lỗi.
  Object? getError;

  /// Gán để giữ get() ở trạng thái "đang tải".
  Completer<void>? getHold;

  /// Gán để lần updateMine tiếp theo lỗi.
  Object? updateError;

  Channel get channel => Channel(
        id: profileChannelId,
        userId: 1,
        name: name,
        handle: profileHandle,
        description: description,
        bannerUrl: bannerUrl,
        createdAt: '2026-01-01T00:00:00Z',
        mine: true,
      );

  @override
  Future<Channel> get(int id) async {
    getCalls.add(id);
    final err = getError;
    final wait = getHold;
    if (wait != null) await wait.future;
    if (err != null) {
      getError = null;
      throw err;
    }
    return channel;
  }

  @override
  Future<Channel> updateMine({String? name, String? description, String? avatarUrl, String? bannerUrl}) async {
    updateCalls.add((name: name, description: description, avatarUrl: avatarUrl, bannerUrl: bannerUrl));
    final err = updateError;
    if (err != null) {
      updateError = null;
      throw err;
    }
    if (name != null) this.name = name;
    if (description != null) this.description = description;
    if (bannerUrl != null) this.bannerUrl = bannerUrl;
    return channel;
  }
}

/// UploadService giả: ghi lại đường dẫn file, mỗi lần upload trả một url mới.
class FakeProfileUploadService extends UploadService {
  FakeProfileUploadService(super.api);

  final uploads = <(String, String)>[]; // (đường dẫn, type)

  /// Gán để lần upload tiếp theo ném lỗi này (vd. lỗi đọc file, không phải ApiException).
  Object? error;

  @override
  Future<UploadResult> upload(String filePath, {String type = 'image', onProgress, cancelToken}) async {
    uploads.add((filePath, type));
    final err = error;
    if (err != null) {
      error = null;
      throw err;
    }
    final name = 'img-${uploads.length}.png';
    return UploadResult('/uploads/$name', name, 100);
  }
}

/// Ảnh PNG 1x1 hợp lệ để giả lập ảnh vừa chọn.
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class EditProfileTestEnv {
  final FakeProfileAuthService authService;
  final FakeProfileChannelService channels;
  final FakeProfileUploadService upload;
  final AuthProvider auth;

  /// Các lần mở camera / thư viện: (ảnh bìa?, nguồn).
  final picks = <(bool, ImageSource)>[];

  /// Ảnh trả về khi chọn. null = người dùng hủy chọn.
  XFile? pickResult = XFile.fromData(tinyPng, name: 'photo.png', path: 'photo.png');

  /// true -> mở camera / thư viện ném PlatformException (vd. bị từ chối quyền).
  bool pickFails = false;

  EditProfileTestEnv._(this.authService, this.channels, this.upload, this.auth);

  factory EditProfileTestEnv() {
    SharedPreferences.setMockInitialValues({});
    final tokens = TokenStorage();
    final api = ApiClient(tokens);
    final authService = FakeProfileAuthService(api);
    return EditProfileTestEnv._(
      authService,
      FakeProfileChannelService(api),
      FakeProfileUploadService(api),
      AuthProvider(authService, tokens, api),
    );
  }

  Future<XFile?> _pick(bool banner, ImageSource source) async {
    picks.add((banner, source));
    if (pickFails) throw PlatformException(code: 'no_access');
    return pickResult;
  }

  Future<XFile?> pickAvatar(ImageSource source) => _pick(false, source);
  Future<XFile?> pickBanner(ImageSource source) => _pick(true, source);
}

Widget _label(String text) => Scaffold(appBar: AppBar(), body: Center(child: Text(text)));

/// Dựng app tối giản: màn trước có nút "MỞ MÀN" push tới màn Chỉnh sửa hồ sơ (để thử nút Back).
/// [signedIn]: đăng nhập trước khi mở. [settle] = false khi còn vòng quay chạy mãi (đang tải / đang lưu).
Future<void> pumpEditProfile(
  WidgetTester tester,
  EditProfileTestEnv env, {
  bool signedIn = true,
  bool settle = true,
}) async {
  // Font test rộng hơn font thật: dùng khung 480 dp, cao để thấy cả form.
  tester.view.physicalSize = const Size(480 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  if (signedIn) await env.auth.login(profileEmail, '123456');

  final router = GoRouter(
    initialLocation: '/prev',
    routes: [
      GoRoute(
        path: '/prev',
        builder: (context, __) => Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(previousLabel),
              TextButton(onPressed: () => context.push(AppRoutes.editProfile), child: const Text('MỞ MÀN')),
            ]),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, __) => EditProfileScreen(pickAvatar: env.pickAvatar, pickBanner: env.pickBanner),
      ),
      GoRoute(path: AppRoutes.you, builder: (_, __) => _label(youLabel)),
      GoRoute(path: AppRoutes.login, builder: (_, __) => _label(loginLabel)),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: env.authService),
        Provider<ChannelService>.value(value: env.channels),
        Provider<UploadService>.value(value: env.upload),
        ChangeNotifierProvider<AuthProvider>.value(value: env.auth),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('MỞ MÀN'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

// ---- Tìm widget ----

/// Ô nhập của AuthTextField theo nhãn, vd. profileField('Tên hiển thị').
Finder profileField(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AuthTextField && w.label == label),
      matching: find.byType(TextFormField),
    );

/// Dòng lỗi [text] nằm đúng dưới ô có nhãn [label].
Finder errorUnder(String label, String text) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AuthTextField && w.label == label),
      matching: find.text(text),
    );

Finder saveButton() => find.widgetWithText(TextButton, 'Lưu');

bool saveEnabled(WidgetTester tester) => tester.widget<TextButton>(saveButton()).onPressed != null;

String fieldText(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(profileField(label)).controller!.text;

Finder backButton() => find.byTooltip('Quay lại');

/// Cuộn tới widget rồi bấm.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Bấm ô ảnh ([banner]: ảnh bìa, không thì avatar) rồi chọn [option] trong bottom sheet.
Future<void> chooseImage(WidgetTester tester, {required bool banner, String option = 'Chọn từ thư viện'}) async {
  final picker = banner ? find.byType(BannerPicker) : find.byType(AvatarPicker);
  await tapVisible(tester, find.descendant(of: picker, matching: find.byType(InkWell)));
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

/// Bấm Lưu và đợi lưu xong.
Future<void> save(WidgetTester tester) async {
  await tester.tap(saveButton());
  await tester.pumpAndSettle();
}
