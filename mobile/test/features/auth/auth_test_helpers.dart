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
import 'package:vtube/features/auth/login_screen.dart';

/// Hàm và lớp giả dùng chung cho test của luồng Xác thực (Người 1).

const demoEmail = 'demo@vtube.vn';
const demoPassword = '123456';
const demoToken = 'token-demo';

Me fakeUser() => const Me(
      id: 1,
      email: demoEmail,
      displayName: 'Nguyễn Văn A',
      createdAt: '2026-01-01T00:00:00Z',
      channel: ChannelBrief(id: 1, name: 'Nguyễn Văn A', handle: 'nguyenvana'),
    );

/// AuthService giả, không gọi mạng: chỉ demo@vtube.vn / 123456 đăng nhập được.
class FakeAuthService extends AuthService {
  FakeAuthService(super.api);

  /// Các lần gọi login: (email, mật khẩu).
  final loginCalls = <(String, String)>[];

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
  Future<void> logout() async {}
}

/// AuthProvider thật, chạy trên FakeAuthService và shared_preferences giả (trong bộ nhớ).
class AuthTestEnv {
  final TokenStorage tokens;
  final FakeAuthService service;
  final AuthProvider auth;

  AuthTestEnv._(this.tokens, this.service, this.auth);

  factory AuthTestEnv() {
    SharedPreferences.setMockInitialValues({});
    final tokens = TokenStorage();
    final api = ApiClient(tokens);
    final service = FakeAuthService(api);
    return AuthTestEnv._(tokens, service, AuthProvider(service, tokens, api));
  }
}

const previousScreenLabel = 'MÀN TRƯỚC';
const homeLabel = 'TRANG CHỦ';
const registerLabel = 'MÀN ĐĂNG KÝ';

/// Dựng app tối giản quanh màn Đăng nhập.
/// [fromPreviousScreen]: true -> mở bằng push từ một màn khác (giống dialog requireLogin);
/// false -> mở thẳng, không có màn nào phía sau.
Future<void> pumpLoginScreen(WidgetTester tester, AuthTestEnv env, {bool fromPreviousScreen = false}) async {
  // Font trong test là ô vuông rộng hơn font thật, nên dùng khung 480 dp để chữ không bị tràn giả.
  tester.view.physicalSize = const Size(480 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: fromPreviousScreen ? '/prev' : AppRoutes.login,
    routes: [
      GoRoute(
        path: '/prev',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push(AppRoutes.login),
              child: const Text(previousScreenLabel),
            ),
          ),
        ),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, __) => const Scaffold(body: Text(homeLabel))),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const Scaffold(body: Text(registerLabel))),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: env.auth,
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  if (fromPreviousScreen) {
    await tester.tap(find.text(previousScreenLabel));
    await tester.pumpAndSettle();
  }
}

Finder emailField() => find.byType(TextFormField).at(0);
Finder passwordField() => find.byType(TextFormField).at(1);
Finder loginButton() => find.widgetWithText(FilledButton, 'Đăng nhập');
Finder googleButton() => find.text('Tiếp tục với Google');

String fieldText(WidgetTester tester, Finder field) => tester.widget<TextFormField>(field).controller!.text;

EditableText editableOf(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)));
