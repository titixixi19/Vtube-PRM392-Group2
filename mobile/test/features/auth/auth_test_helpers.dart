import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/app/routes.dart';
import 'package:vtube/app/theme.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/auth/require_login.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/auth_service.dart';
import 'package:vtube/data/services/upload_service.dart';
import 'package:vtube/features/auth/login_screen.dart';
import 'package:vtube/features/auth/register_screen.dart';
import 'package:vtube/features/auth/widgets/auth_text_field.dart';

/// Hàm và lớp giả dùng chung cho test của luồng Xác thực (Người 1).

const demoEmail = 'demo@vtube.vn';
const demoPassword = '123456';
const demoToken = 'token-demo';
const newUserToken = 'token-new';
const takenHandle = 'vtechstudio';
const uploadedAvatarUrl = '/uploads/avatar-1.png';

Me fakeUser() => const Me(
      id: 1,
      email: demoEmail,
      displayName: 'Nguyễn Văn A',
      createdAt: '2026-01-01T00:00:00Z',
      channel: ChannelBrief(id: 1, name: 'Nguyễn Văn A', handle: 'nguyenvana'),
    );

/// Một lần gọi AuthService.register.
typedef RegisterCall = ({
  String displayName,
  String? channelName,
  String handle,
  String email,
  String password,
  String? avatarUrl,
});

/// AuthService giả, không gọi mạng.
/// - Đăng nhập: chỉ demo@vtube.vn / 123456.
/// - Đăng ký: email demo@vtube.vn và handle "vtechstudio" đã có người dùng (409).
class FakeAuthService extends AuthService {
  FakeAuthService(super.api);

  final loginCalls = <(String, String)>[];
  final registerCalls = <RegisterCall>[];
  final handleChecks = <String>[];

  /// true -> kiểm tra handle ném lỗi mạng.
  bool handleCheckFails = false;

  /// Gán Completer để giữ request ở trạng thái "đang gửi" cho tới khi complete().
  Completer<void>? hold;

  @override
  Future<AuthResult> login(String email, String password) async {
    loginCalls.add((email, password));
    if (hold != null) await hold!.future;
    if (email == demoEmail && password == demoPassword) return AuthResult(demoToken, fakeUser());
    throw const ApiException('Email hoặc mật khẩu không đúng', statusCode: 401);
  }

  @override
  Future<bool> isHandleAvailable(String handle) async {
    handleChecks.add(handle);
    if (handleCheckFails) throw const ApiException('Không có kết nối mạng');
    return handle != takenHandle;
  }

  @override
  Future<AuthResult> register({
    required String displayName,
    String? channelName,
    required String handle,
    required String email,
    required String password,
    String? avatarUrl,
  }) async {
    registerCalls.add((
      displayName: displayName,
      channelName: channelName,
      handle: handle,
      email: email,
      password: password,
      avatarUrl: avatarUrl,
    ));
    if (hold != null) await hold!.future;
    if (email == demoEmail) throw const ApiException('Email đã được sử dụng', statusCode: 409);
    if (handle == takenHandle) throw ApiException('Handle @$handle đã có người sử dụng', statusCode: 409);
    final user = Me(
      id: 2,
      email: email,
      displayName: displayName,
      avatarUrl: avatarUrl,
      createdAt: '2026-10-27T00:00:00Z',
      channel: ChannelBrief(id: 9, name: channelName ?? displayName, handle: handle, avatarUrl: avatarUrl),
    );
    return AuthResult(newUserToken, user);
  }

  @override
  Future<void> logout() async {}
}

/// UploadService giả: ghi lại đường dẫn file, trả về url cố định.
class FakeUploadService extends UploadService {
  FakeUploadService(super.api);

  final uploads = <(String, String)>[]; // (đường dẫn, type)

  /// Gán để upload ném lỗi này (vd. lỗi đọc file, không phải ApiException).
  Object? error;

  @override
  Future<UploadResult> upload(String filePath, {String type = 'image', onProgress, cancelToken}) async {
    uploads.add((filePath, type));
    if (error != null) throw error!;
    return const UploadResult(uploadedAvatarUrl, 'avatar-1.png', 100);
  }
}

/// Ảnh PNG 1x1 hợp lệ để giả lập ảnh vừa chọn.
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// AuthProvider thật, chạy trên service giả và shared_preferences giả (trong bộ nhớ).
class AuthTestEnv {
  final TokenStorage tokens;
  final FakeAuthService service;
  final FakeUploadService upload;
  final AuthProvider auth;

  /// Các lần mở camera / thư viện. Gán [pickResult] = null để giả lập người dùng hủy chọn.
  final pickedSources = <ImageSource>[];
  XFile? pickResult = XFile.fromData(tinyPng, name: 'avatar.png', path: 'avatar.png');

  AuthTestEnv._(this.tokens, this.service, this.upload, this.auth);

  factory AuthTestEnv() {
    SharedPreferences.setMockInitialValues({});
    final tokens = TokenStorage();
    final api = ApiClient(tokens);
    final service = FakeAuthService(api);
    return AuthTestEnv._(tokens, service, FakeUploadService(api), AuthProvider(service, tokens, api));
  }

  Future<XFile?> pickImage(ImageSource source) async {
    pickedSources.add(source);
    return pickResult;
  }
}

const previousScreenLabel = 'MÀN TRƯỚC';
const homeLabel = 'TRANG CHỦ';

/// Màn cần test được mở bằng cách nào.
enum LoginEntry {
  /// Mở thẳng, không có màn nào phía sau.
  direct,

  /// Khách bấm Like... -> dialog requireLogin (code thật) -> "Đăng nhập". Chỉ dùng cho màn Đăng nhập.
  requireLoginDialog,

  /// Mở từ chỗ khác bằng push, vd. nút "Đăng nhập" ở tab Bạn.
  otherScreen,
}

/// Dòng chữ màn trước hiện ra sau khi requireLogin trả kết quả.
String requireLoginResult(bool loggedIn) => 'requireLogin: $loggedIn';

/// Màn trước: một nút gọi requireLogin thật, một nút push thẳng tới [route].
class _PreviousScreen extends StatefulWidget {
  final String route;

  const _PreviousScreen({required this.route});

  @override
  State<_PreviousScreen> createState() => _PreviousScreenState();
}

class _PreviousScreenState extends State<_PreviousScreen> {
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(previousScreenLabel),
          TextButton(
            onPressed: () async {
              final ok = await requireLogin(context);
              if (mounted) setState(() => _result = requireLoginResult(ok));
            },
            child: const Text('THÍCH VIDEO'),
          ),
          TextButton(onPressed: () => context.push(widget.route), child: const Text('MỞ MÀN')),
          Text(_result),
        ]),
      ),
    );
  }
}

/// Dựng app tối giản quanh một màn của luồng Xác thực ([route]: AppRoutes.login / AppRoutes.register),
/// mở theo [entry].
Future<void> pumpAuthScreen(
  WidgetTester tester,
  AuthTestEnv env, {
  required String route,
  LoginEntry entry = LoginEntry.direct,
}) async {
  // Font trong test là ô vuông rộng hơn font thật, nên dùng khung 480 dp để chữ không bị tràn giả.
  tester.view.physicalSize = const Size(480 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: entry == LoginEntry.direct ? route : '/prev',
    routes: [
      GoRoute(path: '/prev', builder: (_, __) => _PreviousScreen(route: route)),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => RegisterScreen(pickImage: env.pickImage)),
      GoRoute(path: AppRoutes.home, builder: (_, __) => const Scaffold(body: Text(homeLabel))),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: env.service),
        Provider<UploadService>.value(value: env.upload),
        ChangeNotifierProvider<AuthProvider>.value(value: env.auth),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  switch (entry) {
    case LoginEntry.direct:
      break;
    case LoginEntry.requireLoginDialog:
      await tester.tap(find.text('THÍCH VIDEO'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Đăng nhập')));
      await tester.pumpAndSettle();
    case LoginEntry.otherScreen:
      await tester.tap(find.text('MỞ MÀN'));
      await tester.pumpAndSettle();
  }
}

Future<void> pumpLoginScreen(WidgetTester tester, AuthTestEnv env, {LoginEntry entry = LoginEntry.direct}) =>
    pumpAuthScreen(tester, env, route: AppRoutes.login, entry: entry);

/// [fromPreviousScreen]: true -> push từ một màn khác (để thử nút Back), false -> mở thẳng.
Future<void> pumpRegisterScreen(WidgetTester tester, AuthTestEnv env, {bool fromPreviousScreen = false}) =>
    pumpAuthScreen(
      tester,
      env,
      route: AppRoutes.register,
      entry: fromPreviousScreen ? LoginEntry.otherScreen : LoginEntry.direct,
    );

// ---- Tìm widget ----

Finder emailField() => find.byType(TextFormField).at(0);
Finder passwordField() => find.byType(TextFormField).at(1);
Finder loginButton() => find.widgetWithText(FilledButton, 'Đăng nhập');
Finder googleButton() => find.text('Tiếp tục với Google');

/// Ô nhập của AuthTextField theo nhãn, vd. authField('Họ và tên').
Finder authField(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AuthTextField && w.label == label),
      matching: find.byType(TextFormField),
    );

Finder registerButton() => find.widgetWithText(FilledButton, 'Đăng ký');

/// Dòng lỗi [text] nằm đúng dưới ô có nhãn [label] (không phải ở SnackBar hay ô khác).
Finder errorUnder(String label, String text) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AuthTextField && w.label == label),
      matching: find.text(text),
    );

String fieldText(WidgetTester tester, Finder field) => tester.widget<TextFormField>(field).controller!.text;

EditableText editableOf(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)));

/// Cuộn tới widget rồi bấm (form Đăng ký dài hơn màn hình).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Nhập ô Handle và đợi qua thời gian debounce 500 ms để app kiểm tra handle.
Future<void> enterHandle(WidgetTester tester, String handle) async {
  await tester.enterText(authField('Handle'), handle);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

/// Điền đủ form Đăng ký hợp lệ và tick điều khoản. Truyền tham số để thay từng ô.
Future<void> fillRegisterForm(
  WidgetTester tester, {
  String name = 'Trần Văn Bình',
  String? channel,
  String handle = 'binhtran',
  String email = 'binh@vtube.vn',
  String password = 'matkhau123',
  String? confirm,
  bool agree = true,
}) async {
  await tester.enterText(authField('Họ và tên'), name);
  if (channel != null) await tester.enterText(authField('Tên kênh'), channel);
  await enterHandle(tester, handle);
  await tester.enterText(authField('Địa chỉ Email'), email);
  await tester.enterText(authField('Mật khẩu'), password);
  await tester.enterText(authField('Xác nhận mật khẩu'), confirm ?? password);
  if (agree) await tapVisible(tester, find.byType(Checkbox));
  await tester.pumpAndSettle();
}
