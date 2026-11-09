import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/models.dart';
import '../../../data/services/playlist_service.dart';

/// Hộp thoại chỉnh sửa thông tin playlist (tiêu đề, mô tả, quyền riêng tư).
class PlaylistEditDialog extends StatefulWidget {
  final Playlist playlist;

  const PlaylistEditDialog({super.key, required this.playlist});

  static Future<Playlist?> show(BuildContext context, Playlist playlist) {
    return showDialog<Playlist>(
      context: context,
      builder: (ctx) => PlaylistEditDialog(playlist: playlist),
    );
  }

  @override
  State<PlaylistEditDialog> createState() => _PlaylistEditDialogState();
}

class _PlaylistEditDialogState extends State<PlaylistEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late String _visibility;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.playlist.title);
    _descController = TextEditingController(text: widget.playlist.description ?? '');
    _visibility = widget.playlist.visibility;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final desc = _descController.text.trim();
      final updated = await context.read<PlaylistService>().update(
            widget.playlist.id,
            title: title,
            description: desc,
            visibility: _visibility,
          );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : 'Không thể cập nhật danh sách phát';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa danh sách phát'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _titleController,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                hintText: 'Nhập tiêu đề danh sách phát...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                hintText: 'Nhập mô tả danh sách phát...',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Quyền riêng tư', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'private',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Riêng tư'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'unlisted',
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 18),
                      SizedBox(width: 8),
                      Text('Không công khai'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'public',
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 18),
                      SizedBox(width: 8),
                      Text('Công khai'),
                    ],
                  ),
                ),
              ],
              onChanged: _submitting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _visibility = val);
                      }
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
