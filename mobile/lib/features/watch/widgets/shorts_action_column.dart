import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/auth/require_login.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/services/video_service.dart';
import '../../../shared/widgets/app_network_image.dart';

/// Cột tác vụ bên phải của màn hình Shorts kèm đĩa nhạc xoay.
class ShortsActionColumn extends StatefulWidget {
  final Video short;
  final VoidCallback onOpenComments;
  final int? initialReaction;
  final int? initialLikeCount;
  final void Function(int nextReaction, int nextLikes)? onReactionChanged;

  const ShortsActionColumn({
    super.key,
    required this.short,
    required this.onOpenComments,
    this.initialReaction,
    this.initialLikeCount,
    this.onReactionChanged,
  });

  @override
  State<ShortsActionColumn> createState() => ShortsActionColumnState();
}

class ShortsActionColumnState extends State<ShortsActionColumn> with SingleTickerProviderStateMixin {
  late int _myReaction;
  late int _likeCount;
  late AnimationController _discAnimController;

  @override
  void initState() {
    super.initState();
    _myReaction = widget.initialReaction ?? widget.short.viewer?.myReaction ?? 0;
    _likeCount = widget.initialLikeCount ?? widget.short.likeCount;

    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant ShortsActionColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.short.id != widget.short.id ||
        oldWidget.initialReaction != widget.initialReaction ||
        oldWidget.initialLikeCount != widget.initialLikeCount) {
      _myReaction = widget.initialReaction ?? widget.short.viewer?.myReaction ?? 0;
      _likeCount = widget.initialLikeCount ?? widget.short.likeCount;
    }
  }

  @override
  void dispose() {
    _discAnimController.dispose();
    super.dispose();
  }

  void triggerLikeFromDoubleTap() {
    if (_myReaction != 1) {
      _handleReaction(1);
    }
  }

  Future<void> _handleReaction(int targetValue) async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;

    final prevReaction = _myReaction;
    final prevLikes = _likeCount;

    int nextReaction;
    int nextLikes = prevLikes;

    if (targetValue == 1) {
      if (prevReaction == 1) {
        nextReaction = 0;
        nextLikes = prevLikes > 0 ? prevLikes - 1 : 0;
      } else {
        nextReaction = 1;
        nextLikes = prevLikes + 1;
      }
    } else {
      if (prevReaction == -1) {
        nextReaction = 0;
      } else {
        nextReaction = -1;
        if (prevReaction == 1 && prevLikes > 0) {
          nextLikes = prevLikes - 1;
        }
      }
    }

    setState(() {
      _myReaction = nextReaction;
      _likeCount = nextLikes;
    });
    widget.onReactionChanged?.call(nextReaction, nextLikes);

    try {
      final res = await context.read<VideoService>().react(widget.short.id, nextReaction);
      if (!mounted) return;
      setState(() {
        _myReaction = res.myReaction;
        _likeCount = res.likeCount;
      });
      widget.onReactionChanged?.call(res.myReaction, res.likeCount);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _myReaction = prevReaction;
        _likeCount = prevLikes;
      });
      widget.onReactionChanged?.call(prevReaction, prevLikes);
      showSnack(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myReaction = prevReaction;
        _likeCount = prevLikes;
      });
      widget.onReactionChanged?.call(prevReaction, prevLikes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final short = widget.short;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like
        _buildActionItem(
          icon: _myReaction == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
          color: _myReaction == 1 ? AppColors.accent : Colors.white,
          label: Fmt.count(_likeCount),
          onTap: () => _handleReaction(1),
        ),
        const SizedBox(height: 16),
        // Dislike
        _buildActionItem(
          icon: _myReaction == -1 ? Icons.thumb_down : Icons.thumb_down_outlined,
          color: _myReaction == -1 ? AppColors.accent : Colors.white,
          label: 'Không thích',
          onTap: () => _handleReaction(-1),
        ),
        const SizedBox(height: 16),
        // Bình luận
        _buildActionItem(
          icon: Icons.comment_outlined,
          label: Fmt.count(short.commentCount),
          onTap: widget.onOpenComments,
        ),
        const SizedBox(height: 16),
        // Chia sẻ
        _buildActionItem(
          icon: Icons.share_outlined,
          label: 'Chia sẻ',
          onTap: () {
            Share.share('${short.title}\nhttps://vtube.vn/shorts/${short.id}');
          },
        ),
        const SizedBox(height: 16),
        // Remix (giả lập)
        _buildActionItem(
          icon: Icons.sync,
          label: 'Remix',
          onTap: () => showSnack(context, 'Tính năng Remix đang phát triển'),
        ),
        const SizedBox(height: 20),
        // Đĩa nhạc quay
        AnimatedBuilder(
          animation: _discAnimController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _discAnimController.value * 2 * math.pi,
              child: child,
            );
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceHigh,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: ClipOval(
              child: AppNetworkImage(url: short.thumbnailUrl),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
