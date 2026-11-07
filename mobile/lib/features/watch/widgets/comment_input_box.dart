import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/require_login.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/channel_avatar.dart';

/// Ô nhập bình luận cố định ở đáy bottom sheet.
class CommentInputBox extends StatefulWidget {
  final Comment? replyingTo;
  final VoidCallback onCancelReply;
  final Future<void> Function(String content, int? parentId) onSubmit;

  const CommentInputBox({
    super.key,
    this.replyingTo,
    required this.onCancelReply,
    required this.onSubmit,
  });

  @override
  State<CommentInputBox> createState() => CommentInputBoxState();
}

class CommentInputBoxState extends State<CommentInputBox> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant CommentInputBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyingTo != null && oldWidget.replyingTo?.id != widget.replyingTo?.id) {
      final prefix = '@${widget.replyingTo!.author.handle} ';
      if (!_textController.text.startsWith(prefix)) {
        _textController.text = prefix;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );
      }
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await widget.onSubmit(text, widget.replyingTo?.id);
      if (!mounted) return;
      _textController.clear();
      _focusNode.unfocus();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Container(
        color: AppColors.surfaceContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: InkWell(
            onTap: () => requireLogin(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.login, size: 18, color: AppColors.accent),
                  SizedBox(width: 10),
                  Text(
                    'Đăng nhập để bình luận...',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner khi đang trả lời
            if (widget.replyingTo != null)
              Container(
                color: AppColors.surfaceHigh,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'Đang trả lời @${widget.replyingTo!.author.handle}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onCancelReply,
                      child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            // Ô nhập chính
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ChannelAvatar(url: auth.user?.avatarUrl, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLength: 500,
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(fontSize: 14),
                      buildCounter: (_, {required currentLength, required isFocused, required maxLength}) {
                        // Chỉ hiện bộ đếm khi sắp đầy (>= 400 ký tự)
                        return currentLength >= 400
                            ? Text(
                                '$currentLength/$maxLength',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              )
                            : null;
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        hintText: widget.replyingTo != null ? 'Thêm câu trả lời...' : 'Thêm bình luận...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surfaceHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          )
                        : Icon(
                            Icons.send,
                            size: 20,
                            color: hasText ? AppColors.accent : Colors.white24,
                          ),
                    onPressed: hasText && !_isSending ? _submit : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
