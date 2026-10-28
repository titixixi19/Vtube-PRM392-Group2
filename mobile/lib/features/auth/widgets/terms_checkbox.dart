import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Ô tick "Tôi đồng ý với Điều khoản dịch vụ và Chính sách quyền riêng tư của VTube".
/// Bấm vào hai cụm chữ màu xanh để mở nội dung.
class TermsCheckbox extends StatefulWidget {
  final bool value;

  /// null -> khóa (đang gửi form).
  final ValueChanged<bool>? onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  @override
  State<TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<TermsCheckbox> {
  late final _terms = TapGestureRecognizer()..onTap = () => widget.onOpenTerms();
  late final _privacy = TapGestureRecognizer()..onTap = () => widget.onOpenPrivacy();

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: AppColors.link, fontWeight: FontWeight.w600);
    final onChanged = widget.onChanged;

    return Material(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChanged == null ? null : () => onChanged(!widget.value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(children: [
            Checkbox(
              value: widget.value,
              activeColor: AppColors.accent,
              onChanged: onChanged == null ? null : (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Tôi đồng ý với '),
                  TextSpan(text: 'Điều khoản dịch vụ', style: link, recognizer: _terms),
                  const TextSpan(text: ' và '),
                  TextSpan(text: 'Chính sách quyền riêng tư', style: link, recognizer: _privacy),
                  const TextSpan(text: ' của VTube.'),
                ]),
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
