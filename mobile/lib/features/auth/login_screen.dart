import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import 'auth_validators.dart';
import 'widgets/auth_logo.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/google_mark.dart';

/// MÀN 2 · ĐĂNG NHẬP · Người 1
/// API: AuthProvider.login(email, password)  ->  POST /api/auth/login
/// Thiết kế: design/stitch/2._ng_nh_p/ (bỏ 2 khối "Bảo mật tài khoản" và "Mã hóa SSL").
///
/// Thành công: mở từ màn khác (vd. dialog requireLogin) -> quay lại màn đó; không có màn trước -> Trang chủ.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // "Tiếp tục với Google" là giả lập: đăng nhập bằng tài khoản demo có sẵn trong seed.
  static const _demoEmail = 'demo@vtube.vn';
  static const _demoPassword = '123456';

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Vẽ lại để cập nhật độ mờ của nút Đăng nhập theo từng ký tự.
    _email.addListener(_onChanged);
    _password.addListener(_onChanged);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _formValid =>
      AuthValidators.email(_email.text) == null && AuthValidators.loginPassword(_password.text) == null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await _login(_email.text, _password.text, clearPasswordOnError: true);
  }

  Future<void> _loginWithGoogle() async {
    FocusScope.of(context).unfocus();
    await _login(_demoEmail, _demoPassword, successMessage: 'Đăng nhập Google (giả lập)');
  }

  Future<void> _login(String email, String password,
      {String? successMessage, bool clearPasswordOnError = false}) async {
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().login(email, password);
      if (!mounted) return;
      if (successMessage != null) showSnack(context, successMessage);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message);
      if (clearPasswordOnError) _password.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initialEmail: _email.text.trim()),
    );
    if (sent == true && mounted) showSnack(context, 'Đã gửi hướng dẫn tới email');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const _Header(),
            _buildCard(),
            const SizedBox(height: 16),
            _buildRegisterRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(children: [
              AuthTextField(
                label: 'Email',
                hint: 'name@example.com',
                icon: Icons.mail_outline,
                controller: _email,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: AuthValidators.email,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                label: 'Mật khẩu',
                hint: 'Nhập mật khẩu của bạn',
                icon: Icons.lock_outline,
                controller: _password,
                focusNode: _passwordFocus,
                obscure: true,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: AuthValidators.loginPassword,
                onFieldSubmitted: (_) => _submit(),
              ),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading ? null : _forgotPassword,
            style: TextButton.styleFrom(foregroundColor: AppColors.link, textStyle: const TextStyle(fontSize: 12)),
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        // Nút mờ khi form chưa hợp lệ nhưng vẫn bấm được, để hiện lỗi dưới từng ô.
        AnimatedOpacity(
          opacity: _formValid || _loading ? 1 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: AppColors.accent,
              disabledForegroundColor: Colors.white,
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Đăng nhập'),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 18),
                  ]),
          ),
        ),
        const _OrDivider(),
        FilledButton.icon(
          onPressed: _loading ? null : _loginWithGoogle,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surfaceContainer,
            foregroundColor: AppColors.textPrimary,
            disabledBackgroundColor: AppColors.surfaceContainer,
          ),
          icon: const GoogleMark(),
          label: const Text('Tiếp tục với Google'),
        ),
      ]),
    );
  }

  Widget _buildRegisterRow() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('Chưa có tài khoản?', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      TextButton(
        onPressed: _loading ? null : () => context.push(AppRoutes.register),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.link,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: const Text('Đăng ký ngay'),
      ),
    ]);
  }
}

/// Logo + tiêu đề, phía sau có quầng sáng đỏ nhạt.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.topCenter, children: [
      IgnorePointer(
        child: Container(
          width: 224,
          height: 160,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [AppColors.accent.withValues(alpha: 0.14), AppColors.accent.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 24),
        child: Column(children: [
          AuthLogo(),
          SizedBox(height: 12),
          Text('Đăng nhập', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          SizedBox(height: 4),
          Text('để tiếp tục với VTube', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
      ),
    ]);
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: AppColors.surfaceHighest)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'HOẶC',
            style: TextStyle(
                fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Divider(color: AppColors.surfaceHighest)),
      ]),
    );
  }
}

/// Dialog "Quên mật khẩu?" (giả lập): nhập email hợp lệ rồi bấm Gửi -> trả về true.
class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    if (_formKey.currentState!.validate()) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quên mật khẩu?'),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Nhập email tài khoản, chúng tôi sẽ gửi hướng dẫn đặt lại mật khẩu.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            validator: AuthValidators.email,
            onFieldSubmitted: (_) => _send(),
            decoration: const InputDecoration(hintText: 'name@example.com', prefixIcon: Icon(Icons.mail_outline)),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        TextButton(onPressed: _send, child: const Text('Gửi')),
      ],
    );
  }
}
