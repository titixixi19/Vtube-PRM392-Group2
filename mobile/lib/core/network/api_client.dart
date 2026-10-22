import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Lớp gọi HTTP dùng chung. Tự gắn token và chuyển mọi lỗi thành [ApiException].
///
/// Không gọi trực tiếp trong màn hình; hãy dùng các service trong lib/data/services.
class ApiClient {
  final TokenStorage tokenStorage;
  late final Dio dio;

  /// Được gọi khi backend trả 401 (token hết hạn) -> AuthProvider đăng xuất.
  void Function()? onUnauthorized;

  ApiClient(this.tokenStorage) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenStorage.token;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(() => dio.post(path, data: body, queryParameters: _clean(query)));

  Future<dynamic> put(String path, {Object? body}) => _send(() => dio.put(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) => _send(() => dio.patch(path, data: body));

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.delete(path, queryParameters: _clean(query)));

  /// Upload multipart, có callback tiến độ (0.0 -> 1.0).
  Future<dynamic> upload(String path, FormData form, {void Function(double progress)? onProgress, CancelToken? cancelToken}) =>
      _send(() => dio.post(
            path,
            data: form,
            cancelToken: cancelToken,
            options: Options(contentType: 'multipart/form-data', sendTimeout: const Duration(minutes: 10)),
            onSendProgress: (sent, total) {
              if (onProgress != null && total > 0) onProgress(sent / total);
            },
          ));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final res = await request();
      return res.data;
    } on DioException catch (e) {
      final res = e.response;
      if (res == null) {
        if (e.type == DioExceptionType.cancel) {
          throw const ApiException('Đã hủy');
        }
        throw const ApiException('Không kết nối được máy chủ. Kiểm tra mạng hoặc backend.');
      }
      if (res.statusCode == 401) onUnauthorized?.call();
      final data = res.data;
      final message = data is Map && data['message'] is String ? data['message'] as String : 'Lỗi ${res.statusCode}';
      throw ApiException(message, statusCode: res.statusCode);
    }
  }

  /// Bỏ các tham số null để không gửi "?category=null".
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return Map.of(query)..removeWhere((_, v) => v == null);
  }
}
