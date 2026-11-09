import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/comment_service.dart';
import '../../shared/widgets/state_views.dart';
import 'widgets/comment_input_box.dart';
import 'widgets/comment_item_tile.dart';

/// MÀN 7 · BÌNH LUẬN (bottom sheet) · Người 2
Future<int?> showCommentsSheet(
  BuildContext context,
  int videoId, {
  int? channelId,
  bool commentsEnabled = true,
  int? totalCommentCount,
  void Function(int newCount, Comment? latestComment)? onCommentCountChanged,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CommentsSheetContent(
      videoId: videoId,
      channelId: channelId,
      commentsEnabled: commentsEnabled,
      totalCommentCount: totalCommentCount,
      onCommentCountChanged: onCommentCountChanged,
    ),
  );
}

class CommentsSheetContent extends StatefulWidget {
  final int videoId;
  final int? channelId;
  final bool commentsEnabled;
  final int? totalCommentCount;
  final void Function(int newCount, Comment? latestComment)? onCommentCountChanged;

  const CommentsSheetContent({
    super.key,
    required this.videoId,
    this.channelId,
    this.commentsEnabled = true,
    this.totalCommentCount,
    this.onCommentCountChanged,
  });

  @override
  State<CommentsSheetContent> createState() => _CommentsSheetContentState();
}

class _CommentsSheetContentState extends State<CommentsSheetContent> {
  String _sort = 'top'; // top | new
  final _comments = <Comment>[];
  final Map<int, GlobalKey<CommentItemTileState>> _tileKeys = {};
  int _totalCount = 0;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _reqId = 0;

  Comment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _totalCount = widget.totalCommentCount ?? 0;
    _loadComments(initial: true);
  }

  Future<void> _loadComments({bool initial = false}) async {
    if (!initial && _loading) return;
    final curReq = ++_reqId;

    if (initial) {
      setState(() {
        _comments.clear();
        _page = 0;
        _hasMore = true;
        _error = null;
        _loading = true;
      });
    } else {
      if (!_hasMore) return;
      setState(() => _loading = true);
    }

    try {
      final res = await context.read<CommentService>().list(
            widget.videoId,
            sort: _sort,
            page: _page,
            size: 20,
          );

      if (!mounted || curReq != _reqId) return;

      setState(() {
        _comments.addAll(res.items);
        _hasMore = res.hasMore;
        _page++;
        _loading = false;
        if (_totalCount == 0 && initial && _comments.isNotEmpty) {
          _totalCount = (widget.totalCommentCount != null && widget.totalCommentCount! > 0)
              ? widget.totalCommentCount!
              : _comments.length;
        } else if (_comments.length > _totalCount) {
          _totalCount = _comments.length;
        }
      });
      if (initial && _totalCount > 0 && (widget.totalCommentCount == null || widget.totalCommentCount == 0)) {
        widget.onCommentCountChanged?.call(_totalCount, _comments.isNotEmpty ? _comments.first : null);
      }
    } on ApiException catch (e) {
      if (!mounted || curReq != _reqId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || curReq != _reqId) return;
      setState(() {
        _error = 'Không thể tải bình luận';
        _loading = false;
      });
    }
  }

  void _onSortChanged(String newSort) {
    if (_sort == newSort) return;
    setState(() => _sort = newSort);
    _loadComments(initial: true);
  }

  Future<void> _submitComment(String content, int? parentId) async {
    try {
      final newComment = await context.read<CommentService>().create(
            widget.videoId,
            content,
            parentId: parentId,
          );

      if (!mounted) return;

      setState(() {
        if (parentId == null) {
          // Bình luận gốc: chèn lên đầu
          _comments.insert(0, newComment);
          _totalCount++;
        } else {
          // Cập nhật số phản hồi của bình luận gốc:
          // Nếu người dùng trả lời một reply con, rootId sẽ lấy từ newComment.parentId hoặc _replyingTo?.parentId
          final rootId = newComment.parentId ?? _replyingTo?.parentId ?? parentId;
          final parentIdx = _comments.indexWhere((c) => c.id == rootId);
          if (parentIdx != -1) {
            final p = _comments[parentIdx];
            _comments[parentIdx] = Comment(
              id: p.id,
              videoId: p.videoId,
              parentId: p.parentId,
              content: p.content,
              likeCount: p.likeCount,
              replyCount: p.replyCount + 1,
              pinned: p.pinned,
              hearted: p.hearted,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt,
              author: p.author,
              byChannelOwner: p.byChannelOwner,
              myReaction: p.myReaction,
            );
          }
          // Thêm reply vào thread của comment gốc
          _tileKeys[rootId]?.currentState?.addReply(newComment);
          _totalCount++;
        }
        _replyingTo = null;
      });
      widget.onCommentCountChanged?.call(_totalCount, parentId == null ? newComment : null);
      showSnack(context, 'Đã gửi bình luận');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  void _onCommentUpdated(Comment updated) {
    final idx = _comments.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      setState(() {
        if (updated.pinned) {
          // Bỏ ghim các bình luận khác
          for (int i = 0; i < _comments.length; i++) {
            if (_comments[i].id != updated.id && _comments[i].pinned) {
              final old = _comments[i];
              _comments[i] = Comment(
                id: old.id,
                videoId: old.videoId,
                parentId: old.parentId,
                content: old.content,
                likeCount: old.likeCount,
                replyCount: old.replyCount,
                pinned: false,
                hearted: old.hearted,
                createdAt: old.createdAt,
                updatedAt: old.updatedAt,
                author: old.author,
                byChannelOwner: old.byChannelOwner,
                myReaction: old.myReaction,
              );
            }
          }
          _comments[idx] = updated;
          // Đưa bình luận ghim lên đầu
          _comments.removeAt(idx);
          _comments.insert(0, updated);
        } else {
          _comments[idx] = updated;
        }
      });
    }
  }

  /// Trạng thái trống / lỗi / đang tải nằm giữa vùng danh sách nhưng vẫn cuộn được.
  /// Khi bàn phím mở, vùng này co lại rất thấp; dùng Center thường sẽ bị
  /// "BOTTOM OVERFLOWED". Gắn scrollController của sheet để vẫn kéo sheet được.
  Widget _scrollableState(ScrollController controller, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isChannelOwner = auth.isLoggedIn && widget.channelId != null && auth.user?.channel.id == widget.channelId;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header bình luận
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    const Text(
                      'Bình luận',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Fmt.count(_totalCount),
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, _totalCount),
                    ),
                  ],
                ),
              ),
              // Hàng chip sắp xếp: Hàng đầu / Mới nhất
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Hàng đầu'),
                      selected: _sort == 'top',
                      onSelected: (_) => _onSortChanged('top'),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: _sort == 'top' ? AppColors.chipSelectedFg : AppColors.textPrimary,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Mới nhất'),
                      selected: _sort == 'new',
                      onSelected: (_) => _onSortChanged('new'),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: _sort == 'new' ? AppColors.chipSelectedFg : AppColors.textPrimary,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 8),
              // Danh sách bình luận
              Expanded(
                child: _loading && _comments.isEmpty
                    ? _scrollableState(scrollController, const LoadingView())
                    : _error != null && _comments.isEmpty
                        ? _scrollableState(
                            scrollController,
                            ErrorView(message: _error!, onRetry: () => _loadComments(initial: true)),
                          )
                        : _comments.isEmpty
                            ? _scrollableState(
                                scrollController,
                                const EmptyView(
                                  icon: Icons.chat_bubble_outline,
                                  title: 'Chưa có bình luận nào',
                                  message: 'Hãy là người đầu tiên bình luận!',
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _comments.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _comments.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: _loading
                                            ? const LoadingView()
                                            : TextButton(
                                                onPressed: () => _loadComments(initial: false),
                                                child: const Text('Tải thêm bình luận'),
                                              ),
                                      ),
                                    );
                                  }

                                  final comment = _comments[index];
                                  return CommentItemTile(
                                    key: _tileKeys.putIfAbsent(comment.id, () => GlobalKey<CommentItemTileState>()),
                                    comment: comment,
                                    isChannelOwner: isChannelOwner,
                                    onReply: (target) {
                                      setState(() => _replyingTo = target);
                                    },
                                    onDelete: (id) {
                                      final idx = _comments.indexWhere((c) => c.id == id);
                                      final removedCount = idx != -1 ? (1 + _comments[idx].replyCount) : 1;
                                      setState(() {
                                        _comments.removeWhere((c) => c.id == id);
                                        _totalCount = math.max(0, _totalCount - removedCount);
                                      });
                                      widget.onCommentCountChanged?.call(
                                        _totalCount,
                                        _comments.isNotEmpty ? _comments.first : null,
                                      );
                                    },
                                    onReplyDeleted: (id) {
                                      setState(() {
                                        _totalCount = math.max(0, _totalCount - 1);
                                      });
                                      widget.onCommentCountChanged?.call(
                                        _totalCount,
                                        _comments.isNotEmpty ? _comments.first : null,
                                      );
                                    },
                                    onUpdated: _onCommentUpdated,
                                  );
                                },
                              ),
              ),
              // Ô nhập bình luận cố định ở đáy (hoặc thông báo nếu bình luận bị tắt)
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: widget.commentsEnabled
                    ? CommentInputBox(
                        replyingTo: _replyingTo,
                        onCancelReply: () => setState(() => _replyingTo = null),
                        onSubmit: _submitComment,
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        color: AppColors.surfaceHigh,
                        child: const Center(
                          child: Text(
                            'Tính năng bình luận đã bị tắt cho video này.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
