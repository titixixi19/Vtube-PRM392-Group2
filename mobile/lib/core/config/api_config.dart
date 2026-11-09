import 'package:flutter/foundation.dart';

/// Cấu hình địa chỉ backend.
///
/// Mặc định:
/// - Trên Web (Chrome/Edge): dùng http://localhost:8080
/// - Trên Android Emulator: dùng http://10.0.2.2:8080
/// Đổi khi chạy máy khác / thiết bị thật:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
class ApiConfig {
  ApiConfig._();

  static const String _envUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (kIsWeb) return 'http://localhost:8080';
    return 'http://10.0.2.2:8080';
  }

  /// Backend có thể trả URL tương đối ("/uploads/abc.mp4") -> ghép với baseUrl.
  static String? resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$baseUrl${url.startsWith('/') ? '' : '/'}$url';
  }
}
