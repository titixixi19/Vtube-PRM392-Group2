import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/require_login.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/services/comment_service.dart';
import '../../../shared/widgets/app_network_image.dart';

/// Hiển thị 1 bình luận kèm các phản hồi con (nếu có).
class CommentItemTile extends StatefulWidget {
  final Comment comment;
  final bool isChannelOwner;
  final void Function(Comment targetComment) onReply;
  final void Function(int commentId) onDelete;
  final void Function(Comment updatedComment)? onUpdated;

  const CommentItemTile({
    super.key,
    required this.comment,
    required this.isChannelOwner,
    required this.onReply,
    required this.onDelete,
    this.onUpdated,
  });

  @override
  State<CommentItemTile> createState() => _CommentItemTileState();
}

class _CommentItemTileState extends State<CommentItemTile> {
  late Comment _comment;
  bool _expandedText = false;
  bool _showReplies = false;
  bool _loadingReplies = false;
  final _replies = <Comment>[];

  @override
  void initState() {
    super.initState();
    _comment = widget.comment;
  }

  @override
  void didUpdateWidget(covariant CommentItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment != widget.comment) {
      _comment = widget.comment;
    }
  }

  Future<void> _handleReaction(int targetValue) async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;

    final prevReaction = _comment.myReaction;
    final prevLikes = _comment.likeCount;

    int nextReaction = (prevReaction == targetValue) ? 0 : targetValue;
    int nextLikes = prevLikes;

    if (targetValue == 1) {
      nextLikes = (prevReaction == 1) ? (prevLikes > 0 ? prevLikes - 1 : 0) : prevLikes + 1;
    } else if (prevReaction == 1 && prevLikes > 0) {
      nextLikes = prevLikes - 1;
    }

    // Optimistic update
    final updated = Comment(
      id: _comment.id,
      videoId: _comment.videoId,
      parentId: _comment.parentId,
      content: _comment.content,
      likeCount: nextLikes,
      replyCount: _comment.replyCount,
      pinned: _comment.pinned,
      hearted: _comment.hearted,
      createdAt: _comment.createdAt,
      updatedAt: _comment.updatedAt,
      author: _comment.author,
      byChannelOwner: _comment.byChannelOwner,
      myReaction: nextReaction,
    );

    setState(() => _comment = updated);
    widget.onUpdated?.call(updated);

    try {
      final res = await context.read<CommentService>().react(_comment.id, nextReaction);
      if (!mounted) return;
      setState(() => _comment = res);
      widget.onUpdated?.call(res);
    } catch (_) {
      if (!mounted) return;
      setState(() => _comment = widget.comment);
      widget.onUpdated?.call(widget.comment);
    }
  }

  Future<void> _toggleReplies() async {
    if (_showReplies) {
      setState(() => _showReplies = false);
      return;
    }

    if (_replies.isNotEmpty) {
      setState(() => _showReplies = true);
      return;
    }

    setState(() {
      _loadingReplies = true;
      _showReplies = true;
    });

    try {
      final res = await context.read<CommentService>().replies(_comment.id);
      if (!mounted) return;
      setState(() {
        _replies
          ..clear()
          ..addAll(res.items);
        _loadingReplies = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReplies = false);
    }
  }

  void _showCommentMenu() {
    final auth = context.read<AuthProvider>();
    final isMyComment = auth.isLoggedIn && auth.user?.id == _comment.author.userId;
    final isChannelOwner = widget.isChannelOwner;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyComment) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Chỉnh sửa bình luận'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Xóa bình luận', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete();
                },
              ),
            ],
            if (isChannelOwner) ...[
              ListTile(
                leading: Icon(_comment.pinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(_comment.pinned ? 'Bỏ ghim bình luận' : 'Ghim bình luận'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final res = await context.read<CommentService>().togglePin(_comment.id);
                    if (!mounted) return;
                    setState(() => _comment = res);
                    widget.onUpdated?.call(res);
                  } on ApiException catch (e) {
                    if (mounted) showSnack(context, e.message);
                  }
                },
              ),
              ListTile(
                leading: Icon(_comment.hearted ? Icons.favorite_border : Icons.favorite, color: Colors.red),
                title: Text(_comment.hearted ? 'Bỏ thả tim' : 'Thả tim'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final res = await context.read<CommentService>().toggleHeart(_comment.id);
                    if (!mounted) return;
                    setState(() => _comment = res);
                    widget.onUpdated?.call(res);
                  } on ApiException catch (e) {
                    if (mounted) showSnack(context, e.message);
                  }
                },
              ),
            ],
            if (!isMyComment)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Báo cáo vi phạm'),
                onTap: () {
                  Navigator.pop(ctx);
                  showSnack(context, 'Cảm ơn bạn đã báo cáo bình luận này');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: _comment.content);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa bình luận'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Nhập nội dung...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final res = await context.read<CommentService>().update(_comment.id, newContent);
                if (!mounted) return;
                setState(() => _comment = res);
                widget.onUpdated?.call(res);
                showSnack(context, 'Đã cập nhật bình luận');
              } on ApiException catch (e) {
                if (mounted) showSnack(context, e.message);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bình luận?'),
        content: const Text('Bình luận này và các câu trả lời sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<CommentService>().delete(_comment.id);
                if (!mounted) return;
                widget.onDelete(_comment.id);
                showSnack(context, 'Đã xóa bình luận');
              } on ApiException catch (e) {
                if (mounted) showSnack(context, e.message);
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng ghim
          if (_comment.pinned) ...[
            const Row(
              children: [
                Icon(Icons.push_pin, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text(
                  'Được ghim bởi chủ kênh',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Avatar + Nội dung
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.channel(_comment.author.channelId)),
                child: ClipOval(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: AppNetworkImage(url: _comment.author.avatarUrl),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: @handle · thời gian
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: _comment.byChannelOwner
                                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
                                : EdgeInsets.zero,
                            decoration: _comment.byChannelOwner
                                ? BoxDecoration(
                                    color: AppColors.surfaceHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  )
                                : null,
                            child: Text(
                              '@${_comment.author.handle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _comment.byChannelOwner ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          Fmt.timeAgo(_comment.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        if (_comment.updatedAt != null) ...[
                          const SizedBox(width: 4),
                          const Text('(đã sửa)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Nội dung bình luận
                    Text(
                      _comment.content,
                      maxLines: _expandedText ? null : 4,
                      overflow: _expandedText ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.textPrimary),
                    ),
                    if (_comment.content.length > 150)
                      GestureDetector(
                        onTap: () => setState(() => _expandedText = !_expandedText),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _expandedText ? 'Ẩn bớt' : 'Đọc thêm',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Hàng tương tác Like / Dislike / Trả lời
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _handleReaction(1),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Icon(
                                  _comment.myReaction == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
                                  size: 15,
                                  color: _comment.myReaction == 1 ? AppColors.accent : AppColors.textSecondary,
                                ),
                                if (_comment.likeCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    Fmt.count(_comment.likeCount),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _comment.myReaction == 1 ? AppColors.accent : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _handleReaction(-1),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _comment.myReaction == -1 ? Icons.thumb_down : Icons.thumb_down_outlined,
                              size: 15,
                              color: _comment.myReaction == -1 ? AppColors.accent : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (_comment.hearted) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.favorite, size: 14, color: Colors.red),
                        ],
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => widget.onReply(_comment),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              'Trả lời',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Xem câu trả lời con
                    if (_comment.replyCount > 0) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: _toggleReplies,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showReplies ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                size: 18,
                                color: AppColors.link,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_comment.replyCount} phản hồi',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.link),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showReplies) ...[
                        if (_loadingReplies)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Column(
                              children: _replies
                                  .map((rep) => CommentItemTile(
                                        comment: rep,
                                        isChannelOwner: widget.isChannelOwner,
                                        onReply: widget.onReply,
                                        onDelete: (id) => setState(() => _replies.removeWhere((r) => r.id == id)),
                                      ))
                                  .toList(),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                onPressed: _showCommentMenu,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

