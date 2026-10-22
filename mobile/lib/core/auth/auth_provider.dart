import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/services/auth_service.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/token_storage.dart';

/// Trạng thái đăng nhập dùng chung toàn app.
///
///   final auth = context.watch<AuthProvider>();
///   if (auth.isLoggedIn) Text(auth.user!.displayName);
///   await context.read<AuthProvider>().login(email, pass);
class AuthProvider extends ChangeNotifier {
  final AuthService _service;
  final TokenStorage _tokens;

  AuthProvider(this._service, this._tokens, ApiClient api) {
    api.onUnauthorized = _onUnauthorized;
  }

  Me? _user;
  Me? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Gọi ở Splash: đọc token đã lưu, hỏi /api/me. Lỗi 401 -> xóa token (chế độ khách).
  Future<void> restoreSession() async {
    final token = await _tokens.load();
    if (token == null) return;
    try {
      _user = await _service.me();
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _tokens.clear();
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await _service.login(email.trim(), password);
    await _tokens.save(res.token);
    _user = res.user;
    notifyListeners();
  }

  Future<void> register({
    required String displayName,
    String? channelName,
    required String handle,
    required String email,
    required String password,
    String? avatarUrl,
  }) async {
    final res = await _service.register(
      displayName: displayName,
      channelName: channelName,
      handle: handle,
      email: email,
      password: password,
      avatarUrl: avatarUrl,
    );
    await _tokens.save(res.token);
    _user = res.user;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _service.logout();
    } catch (_) {
      // Bỏ qua lỗi mạng khi đăng xuất
    }
    await _tokens.clear();
    _user = null;
    notifyListeners();
  }

  /// Gọi lại sau khi sửa hồ sơ / kênh.
  Future<void> refreshMe() async {
    _user = await _service.me();
    notifyListeners();
  }

  void _onUnauthorized() {
    if (_user == null) return;
    _tokens.clear();
    _user = null;
    notifyListeners();
  }
}
