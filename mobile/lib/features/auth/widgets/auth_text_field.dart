import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Ô nhập của các form Đăng nhập / Đăng ký: nhãn phía trên, icon bên trái (đổi màu khi focus),
/// lỗi hiện dưới ô và được kiểm tra khi rời ô. `obscure: true` thêm nút con mắt ẩn/hiện.
class AuthTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  /// Widget bên phải ô (bị thay bằng nút con mắt khi `obscure`).
  final Widget? suffix;

  /// Lỗi từ server (vd. 409 email đã dùng), hiện đè lên lỗi của validator.
  final String? errorText;

  const AuthTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.hint,
    this.focusNode,
    this.validator,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.suffix,
    this.errorText,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  static final _iconColor = WidgetStateColor.resolveWith(
    (states) => states.contains(WidgetState.focused) ? AppColors.link : AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final suffix = widget.obscure
        ? IconButton(
            tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
            icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
            color: _hidden ? AppColors.textSecondary : AppColors.link,
            onPressed: () => setState(() => _hidden = !_hidden),
          )
        : widget.suffix;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        widget.label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        validator: widget.validator,
        autovalidateMode: AutovalidateMode.onUnfocus,
        enabled: widget.enabled,
        obscureText: _hidden,
        enableSuggestions: !widget.obscure,
        autocorrect: !widget.obscure,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onFieldSubmitted: widget.onFieldSubmitted,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: widget.errorText,
          errorMaxLines: 2,
          fillColor: AppColors.surfaceContainer,
          prefixIcon: Icon(widget.icon, size: 20),
          prefixIconColor: _iconColor,
          suffixIcon: suffix,
        ),
      ),
    ]);
  }
}
