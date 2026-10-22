/// Lỗi trả về từ backend: { "status": 404, "error": "...", "message": "Không tìm thấy video" }.
/// [message] là tiếng Việt, có thể hiện thẳng lên SnackBar.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}
