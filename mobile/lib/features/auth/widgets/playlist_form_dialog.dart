import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_exception.dart';

/// Chế độ hiển thị playlist: giá trị gửi API -> nhãn tiếng Việt.
const playlistVisibilityLabels = {
  'public': 'Công khai',
  'unlisted': 'Không công khai',
  'private': 'Riêng tư',
};

/// Dialog tạo playlist (tên + chế độ hiển thị) hoặc đổi tên (chỉ tên, khi [initialTitle] khác null).
/// Gọi [onSubmit]; lỗi API hiện ngay trong dialog để không mất chữ đã nhập, thành công thì tự đóng và trả về true.
class PlaylistFormDialog extends StatefulWidget {
  static const maxTitleLength = 150;

  final String? initialTitle;
  final Future<void> Function(String title, String visibility) onSubmit;

  const PlaylistFormDialog({super.key, this.initialTitle, required this.onSubmit});

  bool get isRename => initialTitle != null;

  /// Kiểm tra tên: bắt buộc, tối đa 150 ký tự (không tính khoảng trắng hai đầu).
  static String? validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Vui lòng nhập tên danh sách phát';
    if (title.length > maxTitleLength) return 'Tên tối đa $maxTitleLength ký tự';
    return null;
  }

  @override
  State<PlaylistFormDialog> createState() => _PlaylistFormDialogState();
}

class _PlaylistFormDialogState extends State<PlaylistFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initialTitle);
  String _visibility = 'private';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_title.text.trim(), _visibility);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.isRename ? 'Đổi tên danh sách phát' : 'Danh sách phát mới'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                enabled: !_saving,
                maxLength: PlaylistFormDialog.maxTitleLength,
                textInputAction: TextInputAction.done,
                validator: PlaylistFormDialog.validateTitle,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Tên'),
              ),
              if (!widget.isRename) ...[
                const SizedBox(height: 8),
                const Text('Chế độ hiển thị', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                RadioGroup<String>(
                  groupValue: _visibility,
                  onChanged: (v) {
                    if (!_saving && v != null) setState(() => _visibility = v);
                  },
                  child: Column(children: [
                    for (final e in playlistVisibilityLabels.entries)
                      RadioListTile<String>(
                        value: e.key,
                        title: Text(e.value),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ]),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.isRename ? 'Lưu' : 'Tạo'),
          ),
        ],
      ),
    );
  }
}
