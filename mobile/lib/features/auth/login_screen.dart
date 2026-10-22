import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';

/// MÀN 2 · ĐĂNG NHẬP · Người 1
/// API: AuthProvider.login(email, password)  ->  POST /api/auth/login
///
/// Đã có form tối thiểu để cả nhóm đăng nhập thử (demo@vtube.vn / 123456).
/// TODO(Người 1): làm lại theo Stitch + đặc tả:
///   - Logo, tiêu đề "Đăng nhập", phụ đề "để tiếp tục với VTube"
///   - Kiểm tra email đúng định dạng, mật khẩu >= 6 ký tự, lỗi hiện dưới ô
///   - Nút mờ khi form chưa hợp lệ, vòng quay khi đang gửi, icon ẩn/hiện mật khẩu
///   - "Quên mật khẩu?", "Tiếp tục với Google" (giả lập), "Chưa có tài khoản? Đăng ký"
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().login(_email.text, _password.text);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Đăng nhập', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email')),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'Mật khẩu')),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Đăng nhập'),
          ),
        ),
        TextButton(onPressed: () => context.push(AppRoutes.register), child: const Text('Chưa có tài khoản? Đăng ký')),
      ]),
    );
  }
}
