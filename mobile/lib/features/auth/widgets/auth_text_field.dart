import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Chữ nhỏ bên phải nhãn, vd. "Bắt buộc", "Tối thiểu 8 ký tự", "Đang kiểm tra...".
  final Widget? labelTrailing;

  /// Tiền tố trong ô, vd. "@" cho handle.
  final String? prefixText;

  final List<TextInputFormatter>? inputFormatters;

  /// Lỗi từ server (vd. 409 email đã dùng): hiện đè lên lỗi của validator và làm form không hợp lệ.
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
    this.labelTrailing,
    this.prefixText,
    this.inputFormatters,
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
      Row(children: [
        Expanded(
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
        ),
        if (widget.labelTrailing != null)
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            child: widget.labelTrailing!,
          ),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        validator: widget.validator,
        forceErrorText: widget.errorText,
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
        inputFormatters: widget.inputFormatters,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixText: widget.prefixText,
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
