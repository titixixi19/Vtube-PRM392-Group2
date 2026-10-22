import '../../core/network/api_client.dart';
import '../models/models.dart';

class AuthResult {
  final String token;
  final Me user;
  const AuthResult(this.token, this.user);
}

/// Màn 2, 3, 4. Thường dùng qua AuthProvider thay vì gọi trực tiếp.
class AuthService {
  final ApiClient _api;
  AuthService(this._api);

  AuthResult _parse(dynamic data) =>
      AuthResult(data['token'] as String, Me.fromJson(data['user'] as Map<String, dynamic>));

  Future<AuthResult> login(String email, String password) async =>
      _parse(await _api.post('/api/auth/login', body: {'email': email, 'password': password}));

  Future<AuthResult> register({
    required String displayName,
    String? channelName,
    required String handle,
    required String email,
    required String password,
    String? avatarUrl,
  }) async =>
      _parse(await _api.post('/api/auth/register', body: {
        'displayName': displayName,
        'channelName': channelName,
        'handle': handle,
        'email': email,
        'password': password,
        'avatarUrl': avatarUrl,
      }));

  Future<void> logout() async => _api.post('/api/auth/logout');

  Future<bool> isHandleAvailable(String handle) async =>
      (await _api.get('/api/users/check-handle', query: {'handle': handle}))['available'] == true;

  Future<Me> me() async => Me.fromJson(await _api.get('/api/me'));

  Future<Me> updateMe({String? displayName, String? avatarUrl}) async =>
      Me.fromJson(await _api.put('/api/me', body: {'displayName': displayName, 'avatarUrl': avatarUrl}));

  Future<Me> setHistoryPaused(bool paused) async =>
      Me.fromJson(await _api.patch('/api/me/settings', body: {'historyPaused': paused}));
}
