/// Cấu hình địa chỉ backend.
///
/// Mặc định dùng 10.0.2.2 (máy tính chạy backend, nhìn từ Android Emulator).
/// Đổi khi chạy máy khác:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Backend có thể trả URL tương đối ("/uploads/abc.mp4") -> ghép với baseUrl.
  static String? resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$baseUrl${url.startsWith('/') ? '' : '/'}$url';
  }
}
