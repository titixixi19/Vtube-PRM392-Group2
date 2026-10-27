import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtube/app/routes.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/auth/require_login.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/auth_service.dart';

/// requireLogin (dùng chung): dialog "Đăng nhập để tiếp tục" và mở màn Đăng nhập kèm cờ "từ dialog".
/// Chạy: cd mobile && flutter test test/core/auth/require_login_test.dart

/// Đăng nhập giả: tài khoản nào cũng được.
class _FakeAuthService extends AuthService {
  _FakeAuthService(super.api);

  @override
  Future<AuthResult> login(String email, String password) async => AuthResult(
        'token',
        Me(
          id: 1,
          email: email,
          displayName: 'Khách',
          createdAt: '2026-01-01T00:00:00Z',
          channel: const ChannelBrief(id: 1, name: 'Khách', handle: 'khach'),
        ),
      );
}

void main() {
  late AuthProvider auth;
  late List<Uri> loginOpens; // các lần màn Đăng nhập (giả) được mở
  bool? result; // giá trị requireLogin trả về

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final tokens = TokenStorage();
    final api = ApiClient(tokens);
    auth = AuthProvider(_FakeAuthService(api), tokens, api);
    loginOpens = [];
    result = null;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => result = await requireLogin(context),
                child: const Text('Thích'),
              ),
            ),
          ),
        ),
        // Màn Đăng nhập giả: ghi lại đường dẫn được mở, có nút đăng nhập và nút đóng.
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            loginOpens.add(state.uri);
            return Scaffold(
              body: Column(children: [
                TextButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().login('a@b.vn', '123456');
                    if (context.mounted) context.pop();
                  },
                  child: const Text('ĐĂNG NHẬP GIẢ'),
                ),
                TextButton(onPressed: () => context.pop(), child: const Text('ĐÓNG')),
              ]),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(value: auth, child: MaterialApp.router(routerConfig: router)),
    );
  }

  testWidgets('đã đăng nhập: trả về true ngay, không hiện dialog', (tester) async {
    await auth.login('a@b.vn', '123456');
    await pumpApp(tester);

    await tester.tap(find.text('Thích'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('khách bấm "Để sau": đóng dialog, không mở Đăng nhập, trả về false', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Thích'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);

    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();

    expect(loginOpens, isEmpty);
    expect(result, isFalse);
  });

  testWidgets('khách bấm "Đăng nhập": mở màn Đăng nhập kèm cờ from=dialog', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Thích'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(loginOpens.single.path, AppRoutes.login);
    expect(loginOpens.single.queryParameters[AppRoutes.loginFromParam], AppRoutes.loginFromDialogValue);
    expect(Uri.parse(AppRoutes.loginFromDialog), loginOpens.single);
  });

  testWidgets('đăng nhập xong rồi quay lại: requireLogin trả về true', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Thích'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ĐĂNG NHẬP GIẢ'));
    await tester.pumpAndSettle();

    expect(find.text('Thích'), findsOneWidget);
    expect(result, isTrue);
  });

  testWidgets('đóng màn Đăng nhập mà không đăng nhập: requireLogin trả về false', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Thích'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ĐÓNG'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
