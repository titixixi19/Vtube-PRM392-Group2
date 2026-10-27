/// Hàm kiểm tra dữ liệu cho các form trong luồng Xác thực (Đăng nhập, Đăng ký).
/// Dùng làm `validator` của TextFormField: trả về câu lỗi, hoặc null nếu hợp lệ.
class AuthValidators {
  AuthValidators._();

  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập email';
    if (!_emailRe.hasMatch(v)) return 'Email không đúng định dạng';
    return null;
  }

  /// Mật khẩu ở màn Đăng nhập: chỉ cần từ 6 ký tự.
  static String? loginPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }
}
