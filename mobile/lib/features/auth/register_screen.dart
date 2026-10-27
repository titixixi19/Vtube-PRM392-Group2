import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/upload_service.dart';
import 'auth_validators.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/avatar_picker.dart';
import 'widgets/password_strength_bar.dart';
import 'widgets/terms_checkbox.dart';

/// Mở camera hoặc thư viện để chọn ảnh. Tách thành tham số để test truyền hàm giả.
typedef PickImage = Future<XFile?> Function(ImageSource source);

Future<XFile?> _pickImageFromDevice(ImageSource source) =>
    ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);

/// MÀN 3 · ĐĂNG KÝ · Người 1
/// API:
///   - AuthService.isHandleAvailable(handle)   (sau khi ngừng gõ 500 ms)
///   - UploadService.upload(path, type: 'image') -> url avatar (nếu có chọn ảnh)
///   - AuthProvider.register(...)               (409: email hoặc handle trùng -> lỗi dưới ô tương ứng)
/// Thiết kế: design/stitch/3._ng_k/ (bỏ "Bước 1/2" và khối "Đặc quyền tài khoản mới";
/// tách riêng ô "Tên kênh" và "Handle").
class RegisterScreen extends StatefulWidget {
  final PickImage pickImage;

  const RegisterScreen({super.key, this.pickImage = _pickImageFromDevice});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum _HandleStatus { idle, checking, available, taken }

enum _AvatarAction { camera, gallery, remove }

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _channel = TextEditingController();
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // Để cuộn tới ô lỗi đầu tiên.
  final _nameKey = GlobalKey();
  final _channelKey = GlobalKey();
  final _handleKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _confirmKey = GlobalKey();

  Timer? _handleDebounce;
  _HandleStatus _handleStatus = _HandleStatus.idle;
  bool _channelEdited = false;
  bool _agreed = false;
  bool _loading = false;
  bool _registered = false;

  XFile? _avatar;
  Uint8List? _avatarBytes;
  String? _uploadedAvatarUrl; // url của _avatar đã upload, để không upload lại khi đăng ký lỗi

  // Lỗi 409 từ server, xóa khi người dùng sửa ô đó.
  String? _emailError;
  String? _handleError;

  List<TextEditingController> get _controllers => [_name, _channel, _handle, _email, _password, _confirm];

  bool get _dirty => _avatar != null || _controllers.any((c) => c.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    // Vẽ lại theo từng ký tự: thanh độ mạnh mật khẩu và trạng thái "đã nhập dở" của PopScope.
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _handleDebounce?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _onNameChanged(String value) {
    if (!_channelEdited) _channel.text = value;
  }

  void _onHandleChanged(String value) {
    _handleDebounce?.cancel();
    setState(() {
      _handleError = null;
      _handleStatus = _HandleStatus.idle;
    });
    if (AuthValidators.handle(value) != null) return;
    _handleDebounce = Timer(const Duration(milliseconds: 500), () => _checkHandle(value.trim()));
  }

  Future<void> _checkHandle(String handle) async {
    setState(() => _handleStatus = _HandleStatus.checking);
    try {
      final available = await context.read<AuthService>().isHandleAvailable(handle);
      if (!mounted || _handle.text.trim() != handle) return;
      setState(() => _handleStatus = available ? _HandleStatus.available : _HandleStatus.taken);
    } on ApiException {
      // Không kiểm tra được (vd. mất mạng): để server quyết định khi bấm Đăng ký.
      if (mounted && _handle.text.trim() == handle) setState(() => _handleStatus = _HandleStatus.idle);
    }
  }

  Future<void> _pickAvatar() async {
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(ctx, _AvatarAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(ctx, _AvatarAction.gallery),
          ),
          if (_avatar != null)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Xóa ảnh'),
              onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
            ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _AvatarAction.remove) {
      setState(() {
        _avatar = null;
        _avatarBytes = null;
        _uploadedAvatarUrl = null;
      });
      return;
    }
    final fromCamera = action == _AvatarAction.camera;
    try {
      final file = await widget.pickImage(fromCamera ? ImageSource.camera : ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatar = file;
        _avatarBytes = bytes;
        _uploadedAvatarUrl = null;
      });
    } on PlatformException {
      if (mounted) showSnack(context, fromCamera ? 'Không mở được camera' : 'Không mở được thư viện ảnh');
    }
  }

  Future<String?> _uploadAvatar() async {
    final avatar = _avatar;
    if (avatar == null) return null;
    return _uploadedAvatarUrl ??= (await context.read<UploadService>().upload(avatar.path, type: 'image')).url;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    // Handle trùng đã làm ô Handle báo lỗi (errorText) nên validate() trả về false.
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final avatarUrl = await _uploadAvatar();
      await auth.register(
        displayName: _name.text.trim(),
        channelName: _channel.text.trim(),
        handle: _handle.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      _registered = true;
      showSnack(context, 'Tạo tài khoản thành công');
      context.go(AppRoutes.home);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409 && e.message.startsWith('Email')) {
        setState(() => _emailError = e.message);
        _scrollTo(_emailKey);
      } else if (e.statusCode == 409 && e.message.startsWith('Handle')) {
        setState(() {
          _handleError = e.message;
          _handleStatus = _HandleStatus.taken;
        });
        _scrollTo(_handleKey);
      } else {
        showSnack(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToFirstError() {
    final errors = <GlobalKey, String?>{
      _nameKey: AuthValidators.displayName(_name.text),
      _channelKey: AuthValidators.channelName(_channel.text),
      _handleKey: AuthValidators.handle(_handle.text) ?? _handleErrorText,
      _emailKey: AuthValidators.email(_email.text) ?? _emailError,
      _passwordKey: AuthValidators.registerPassword(_password.text),
      _confirmKey: AuthValidators.confirmPassword(_confirm.text, _password.text),
    };
    final first = errors.entries.where((e) => e.value != null).firstOrNull;
    if (first != null) _scrollTo(first.key);
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut, alignment: 0.1);
  }

  String? get _handleErrorText => _handleError ?? (_handleStatus == _HandleStatus.taken ? 'Đã có người sử dụng' : null);

  /// Hỏi lại trước khi rời màn khi đã nhập dở. Trả về true nếu được rời.
  Future<bool> _confirmDiscard() async {
    if (!_dirty || _registered) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đăng ký?'),
        content: const Text('Thông tin đã nhập sẽ bị mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tiếp tục nhập')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Hủy đăng ký'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _goToLogin() async {
    if (!await _confirmDiscard() || !mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  void _showPolicy(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body, style: const TextStyle(fontSize: 13, height: 1.5))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _registered,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Tạo tài khoản')),
        body: SafeArea(
          top: false,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              // Không dùng ListView: ô cuộn khuất sẽ bị gỡ khỏi cây và Form.validate() bỏ qua nó.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const _Hero(),
                  const SizedBox(height: 20),
                  Center(child: AvatarPicker(imageBytes: _avatarBytes, onTap: _loading ? null : _pickAvatar)),
                  const SizedBox(height: 20),
                  ..._buildFields(),
                  const SizedBox(height: 16),
                  TermsCheckbox(
                    value: _agreed,
                    onChanged: _loading ? null : (v) => setState(() => _agreed = v),
                    onOpenTerms: () => _showPolicy('Điều khoản dịch vụ', _termsText),
                    onOpenPrivacy: () => _showPolicy('Chính sách quyền riêng tư', _privacyText),
                  ),
                  const SizedBox(height: 16),
                  _buildSubmitButton(),
                  const SizedBox(height: 8),
                  const Text(
                    'Bằng cách nhấp vào Đăng ký, bạn cam kết duy trì chuẩn mực nội dung VTube',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Đã có tài khoản?', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: _loading ? null : _goToLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.link,
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Đăng nhập'),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    const gap = SizedBox(height: 12);
    return [
      KeyedSubtree(
        key: _nameKey,
        child: AuthTextField(
          label: 'Họ và tên',
          labelTrailing: const Text('Bắt buộc'),
          hint: 'Ví dụ: Nguyễn Văn An',
          icon: Icons.badge_outlined,
          controller: _name,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          validator: AuthValidators.displayName,
          onChanged: _onNameChanged,
        ),
      ),
      gap,
      KeyedSubtree(
        key: _channelKey,
        child: AuthTextField(
          label: 'Tên kênh',
          hint: 'Tên hiển thị của kênh',
          icon: Icons.smart_display_outlined,
          controller: _channel,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.channelName,
          // Người dùng tự sửa thì thôi tự điền theo Họ tên; xóa trắng thì tự điền lại.
          onChanged: (v) => _channelEdited = v.trim().isNotEmpty,
        ),
      ),
      gap,
      KeyedSubtree(
        key: _handleKey,
        child: AuthTextField(
          label: 'Handle',
          labelTrailing: switch (_handleStatus) {
            _HandleStatus.checking => const Text('Đang kiểm tra...'),
            _HandleStatus.available => const Text('Có thể sử dụng', style: TextStyle(color: AppColors.link)),
            _ => null,
          },
          hint: 'ten.kenh_cua_ban',
          prefixText: '@',
          icon: Icons.alternate_email,
          controller: _handle,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[@\s]')), _LowerCaseFormatter()],
          validator: AuthValidators.handle,
          errorText: _handleErrorText,
          suffix: _handleStatus == _HandleStatus.available
              ? const Icon(Icons.check_circle, key: ValueKey('handle-available'), color: AppColors.link, size: 20)
              : null,
          onChanged: _onHandleChanged,
        ),
      ),
      gap,
      KeyedSubtree(
        key: _emailKey,
        child: AuthTextField(
          label: 'Địa chỉ Email',
          hint: 'tenban@domain.com',
          icon: Icons.mail_outline,
          controller: _email,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: AuthValidators.email,
          errorText: _emailError,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
      ),
      gap,
      KeyedSubtree(
        key: _passwordKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AuthTextField(
            label: 'Mật khẩu',
            labelTrailing: const Text('Tối thiểu 8 ký tự', style: TextStyle(color: AppColors.link)),
            hint: 'Nhập mật khẩu an toàn',
            icon: Icons.lock_outline,
            controller: _password,
            obscure: true,
            enabled: !_loading,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: AuthValidators.registerPassword,
          ),
          PasswordStrengthBar(strength: AuthValidators.passwordStrength(_password.text)),
        ]),
      ),
      gap,
      KeyedSubtree(
        key: _confirmKey,
        child: AuthTextField(
          label: 'Xác nhận mật khẩu',
          hint: 'Nhập lại mật khẩu',
          icon: Icons.lock_reset,
          controller: _confirm,
          obscure: true,
          enabled: !_loading,
          textInputAction: TextInputAction.done,
          validator: (v) => AuthValidators.confirmPassword(v, _password.text),
          onFieldSubmitted: (_) {
            if (_agreed) _submit();
          },
        ),
      ),
    ];
  }

  Widget _buildSubmitButton() {
    return AnimatedOpacity(
      // Chưa đồng ý điều khoản -> nút mờ và không bấm được.
      opacity: _agreed || _loading ? 1 : 0.5,
      duration: const Duration(milliseconds: 150),
      child: FilledButton(
        onPressed: _agreed && !_loading ? _submit : null,
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
                Text('Đăng ký'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 18),
              ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceHigh, AppColors.surfaceLow],
        ),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bắt đầu hành trình sáng tạo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text(
          'Khám phá hàng triệu video, chia sẻ câu chuyện và kết nối cộng đồng người xem trên toàn thế giới.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
        ),
      ]),
    );
  }
}

/// Handle luôn là chữ thường.
class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toLowerCase());
}

const _termsText = '1. Bạn chịu trách nhiệm về nội dung mình tải lên VTube.\n'
    '2. Không đăng nội dung vi phạm pháp luật, bạo lực, thù ghét hoặc vi phạm bản quyền.\n'
    '3. VTube có quyền gỡ nội dung hoặc khóa tài khoản vi phạm.\n'
    '4. Điều khoản có thể được cập nhật; tiếp tục sử dụng nghĩa là bạn đồng ý với bản mới.';

const _privacyText = '1. VTube lưu email, họ tên, ảnh đại diện và lịch sử xem để vận hành dịch vụ.\n'
    '2. Mật khẩu được mã hóa, không ai đọc được.\n'
    '3. Bạn có thể tạm dừng hoặc xóa lịch sử xem trong Cài đặt.\n'
    '4. VTube không bán dữ liệu cá nhân cho bên thứ ba.';
