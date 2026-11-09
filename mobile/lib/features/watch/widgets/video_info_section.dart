import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/auth/require_login.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/services/channel_service.dart';
import '../../../data/services/video_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/channel_avatar.dart';
import '../../../shared/widgets/save_to_playlist_sheet.dart';
import '../../../shared/widgets/subscribe_button.dart';
import 'video_description_sheet.dart';

/// Hàng thông tin chi tiết video, kênh, các nút tương tác và thẻ bình luận thu nhỏ.
class VideoInfoSection extends StatefulWidget {
  final Video video;
  final Comment? previewComment;
  final VoidCallback onOpenComments;

  const VideoInfoSection({
    super.key,
    required this.video,
    this.previewComment,
    required this.onOpenComments,
  });

  @override
  State<VideoInfoSection> createState() => _VideoInfoSectionState();
}

class _VideoInfoSectionState extends State<VideoInfoSection> {
  late int _myReaction;
  late int _likeCount;
  late bool _subscribed;
  bool _downloading = false;
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    _initStateFromVideo();
  }

  @override
  void didUpdateWidget(covariant VideoInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _initStateFromVideo();
    }
  }

  /// Người xem là chủ kênh của video (viewer.owner do backend trả khi đã đăng nhập).
  bool get _isOwnVideo => widget.video.viewer?.owner ?? false;

  void _initStateFromVideo() {
    _myReaction = widget.video.viewer?.myReaction ?? 0;
    _likeCount = widget.video.likeCount;
    _subscribed = widget.video.viewer?.subscribed ?? false;
  }

  Future<void> _handleReaction(int targetValue) async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;

    final prevReaction = _myReaction;
    final prevLikes = _likeCount;

    int nextReaction;
    int nextLikes = prevLikes;

    if (targetValue == 1) {
      // Bấm Like
      if (prevReaction == 1) {
        nextReaction = 0;
        nextLikes = prevLikes > 0 ? prevLikes - 1 : 0;
      } else {
        nextReaction = 1;
        nextLikes = prevLikes + 1;
      }
    } else {
      // Bấm Dislike
      if (prevReaction == -1) {
        nextReaction = 0;
      } else {
        nextReaction = -1;
        if (prevReaction == 1 && prevLikes > 0) {
          nextLikes = prevLikes - 1;
        }
      }
    }

    // Optimistic update
    setState(() {
      _myReaction = nextReaction;
      _likeCount = nextLikes;
    });

    try {
      final res = await context.read<VideoService>().react(widget.video.id, nextReaction);
      if (!mounted) return;
      setState(() {
        _myReaction = res.myReaction;
        _likeCount = res.likeCount;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Rollback
      setState(() {
        _myReaction = prevReaction;
        _likeCount = prevLikes;
      });
      showSnack(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myReaction = prevReaction;
        _likeCount = prevLikes;
      });
      showSnack(context, 'Không thể gửi tương tác');
    }
  }

  Future<void> _toggleSubscribe() async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;

    final before = _subscribed;

    if (before) {
      // Đã đăng ký mà bấm lại: hiện sheet tùy chọn
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: Text('Hủy đăng ký kênh ${widget.video.channel.name}?'),
                onTap: () => Navigator.pop(ctx, true),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Hủy bỏ'),
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    setState(() => _subscribed = !before);

    try {
      final channels = context.read<ChannelService>();
      if (before) {
        await channels.unsubscribe(widget.video.channel.id);
        if (mounted) showSnack(context, 'Đã hủy đăng ký kênh ${widget.video.channel.name}');
      } else {
        await channels.subscribe(widget.video.channel.id);
        if (mounted) showSnack(context, 'Đã đăng ký kênh ${widget.video.channel.name}');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _subscribed = before);
      showSnack(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _subscribed = before);
      showSnack(context, 'Thao tác không thành công');
    }
  }

  void _handleDownload() {
    if (_downloaded) {
      showSnack(context, 'Video đã được lưu ngoại tuyến');
      return;
    }

    setState(() => _downloading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloaded = true;
      });
      showSnack(context, 'Đã tải video xuống thành công (giả lập)');
    });
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final metaText = '${Fmt.views(video.viewCount)} · ${Fmt.timeAgo(video.publishedAt)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Tiêu đề video
          GestureDetector(
            onTap: () => showVideoDescriptionSheet(context, video),
            child: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
          const SizedBox(height: 6),
          // Metadata và nút ...thêm
          GestureDetector(
            onTap: () => showVideoDescriptionSheet(context, video),
            child: Row(
              children: [
                Text(
                  metaText,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 6),
                const Text(
                  '...thêm',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hàng Kênh
          Row(
            children: [
              ChannelAvatar(
                url: video.channel.avatarUrl,
                size: 38,
                onTap: () => context.push(AppRoutes.channel(video.channel.id)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.channel(video.channel.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Fmt.subscribers(video.channel.subscriberCount),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              // Video của chính mình thì không hiện nút Đăng ký (backend cũng chặn tự đăng ký kênh mình).
              if (!_isOwnVideo)
                SubscribeButton(
                  subscribed: _subscribed,
                  onPressed: _toggleSubscribe,
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Hàng nút hành động cuộn ngang
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Like / Dislike chung 1 pill
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _handleReaction(1),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                _myReaction == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
                                size: 18,
                                color: _myReaction == 1 ? AppColors.accent : AppColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                Fmt.count(_likeCount),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _myReaction == 1 ? AppColors.accent : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 18, color: Colors.white24),
                      InkWell(
                        onTap: () => _handleReaction(-1),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Icon(
                            _myReaction == -1 ? Icons.thumb_down : Icons.thumb_down_outlined,
                            size: 18,
                            color: _myReaction == -1 ? AppColors.accent : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Nút Chia sẻ
                _buildActionPill(
                  icon: Icons.share_outlined,
                  label: 'Chia sẻ',
                  onTap: () {
                    Share.share('${video.title}\nhttps://vtube.vn/watch?v=${video.id}');
                  },
                ),
                const SizedBox(width: 8),
                // Nút Tải xuống
                _buildActionPill(
                  icon: _downloaded
                      ? Icons.check_circle_outline
                      : (_downloading ? Icons.hourglass_top : Icons.download_outlined),
                  label: _downloaded
                      ? 'Đã tải xuống'
                      : (_downloading ? 'Đang tải...' : 'Tải xuống'),
                  onTap: _handleDownload,
                ),
                const SizedBox(width: 8),
                // Nút Lưu vào playlist
                _buildActionPill(
                  icon: Icons.playlist_add,
                  label: 'Lưu',
                  onTap: () async {
                    if (!await requireLogin(context)) return;
                    if (context.mounted) showSaveToPlaylistSheet(context, video.id);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Thẻ bình luận thu nhỏ
          _buildCommentCard(context),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentCard(BuildContext context) {
    final comment = widget.previewComment;
    final commentCount = widget.video.commentCount;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onOpenComments,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Bình luận',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Fmt.count(commentCount),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (comment != null)
                Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: AppNetworkImage(url: comment.author.avatarUrl),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        comment.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'Thêm bình luận...',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
