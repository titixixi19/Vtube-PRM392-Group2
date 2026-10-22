import 'package:shared_preferences/shared_preferences.dart';

/// Lưu token đăng nhập trong shared_preferences.
class TokenStorage {
  static const _key = 'auth_token';
  String? _cached;

  /// Token hiện tại (đọc nhanh, đã nạp bằng [load]).
  String? get token => _cached;

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(_key);
    return _cached;
  }

  Future<void> save(String token) async {
    _cached = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  Future<void> clear() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
