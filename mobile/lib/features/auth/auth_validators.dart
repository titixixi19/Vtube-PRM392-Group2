/// Hàm kiểm tra dữ liệu cho các form trong luồng Xác thực (Đăng nhập, Đăng ký).
/// Dùng làm `validator` của TextFormField: trả về câu lỗi, hoặc null nếu hợp lệ.
class AuthValidators {
  AuthValidators._();

  // Chặt hơn @Email của backend để email nào qua được app thì server cũng nhận:
  // phần trước @ không có dấu chấm ở đầu/cuối/liền nhau; tên miền chỉ gồm chữ, số, "-" (không ở đầu/cuối nhãn).
  static final _emailRe = RegExp(
    r'^[\w+-]+(\.[\w+-]+)*@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$',
  );
  static final _handleRe = RegExp(r'^[a-z0-9._]{3,30}$');
  static final _letterRe = RegExp(r'\p{L}', unicode: true); // mọi chữ cái, kể cả có dấu tiếng Việt
  static final _digitRe = RegExp(r'\d');

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

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập họ tên';
    if (v.length < 2 || v.length > 50) return 'Họ tên phải từ 2 đến 50 ký tự';
    return null;
  }

  static String? channelName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập tên kênh';
    if (v.length < 2 || v.length > 50) return 'Tên kênh phải từ 2 đến 50 ký tự';
    return null;
  }

  /// Handle (không gồm "@"): 3–30 ký tự, chỉ chữ thường, số, "." và "_".
  static String? handle(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập handle';
    if (!_handleRe.hasMatch(v)) return 'Handle gồm 3–30 ký tự: chữ thường, số, dấu . hoặc _';
    return null;
  }

  /// Mật khẩu ở màn Đăng ký: từ 8 ký tự, có cả chữ và số.
  static String? registerPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
    if (!_letterRe.hasMatch(v) || !_digitRe.hasMatch(v)) return 'Mật khẩu phải có cả chữ và số';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập lại mật khẩu';
    if (v != password) return 'Mật khẩu xác nhận không khớp';
    return null;
  }

  /// Độ mạnh mật khẩu, cập nhật theo từng ký tự.
  /// Chưa đạt yêu cầu tối thiểu -> Yếu. Đạt yêu cầu -> Trung bình, thêm ít nhất 2 trong 3 điểm
  /// (có cả chữ hoa và chữ thường, có ký tự đặc biệt, dài từ 12 ký tự) -> Mạnh.
  static PasswordStrength passwordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    if (registerPassword(password) != null) return PasswordStrength.weak;
    var bonus = 0;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) bonus++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) bonus++;
    if (password.length >= 12) bonus++;
    return bonus >= 2 ? PasswordStrength.strong : PasswordStrength.medium;
  }
}

enum PasswordStrength {
  none(''),
  weak('Yếu'),
  medium('Trung bình'),
  strong('Mạnh');

  final String label;

  const PasswordStrength(this.label);
}
