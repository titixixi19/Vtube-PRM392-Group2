import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/channel_avatar.dart';

/// Tiêu đề phân nhóm thông báo ("Mới", "Trước đó").
class NotificationSectionHeader extends StatelessWidget {
  final String title;
  final int? badgeCount;
  final VoidCallback? onMarkAllRead;

  const NotificationSectionHeader({super.key, required this.title, this.badgeCount, this.onMarkAllRead});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: badgeCount != null ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          if (badgeCount != null && badgeCount! > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: Text(
                '$badgeCount',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
          const Spacer(),
          if (onMarkAllRead != null)
            TextButton(
              onPressed: onMarkAllRead,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Đánh dấu tất cả đã đọc', style: TextStyle(fontSize: 13, color: AppColors.link)),
            ),
        ],
      ),
    );
  }
}

/// Thẻ hiển thị một mục thông báo.
class NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onHide;
  final VoidCallback? onOpenChannel;

  const NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onHide,
    this.onOpenChannel,
  });

  Widget _buildTypeBadge() {
    IconData icon;
    Color bg;
    Color fg = Colors.white;

    switch (item.type) {
      case 'new_video':
        icon = Icons.smart_display;
        bg = AppColors.accent;
        break;
      case 'new_short':
        icon = Icons.slow_motion_video;
        bg = AppColors.accent;
        break;
      case 'live':
        icon = Icons.sensors;
        bg = AppColors.accent;
        break;
      case 'comment_reply':
        icon = Icons.reply;
        bg = AppColors.link;
        fg = AppColors.chipSelectedFg;
        break;
      case 'comment_heart':
        icon = Icons.favorite;
        bg = AppColors.accent;
        break;
      case 'new_subscriber':
        icon = Icons.person_add;
        bg = AppColors.blueDot;
        break;
      default:
        icon = Icons.notifications;
        bg = AppColors.surfaceHighest;
        break;
    }

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      child: Center(child: Icon(icon, size: 10, color: fg)),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Ẩn thông báo này'),
              onTap: () {
                Navigator.pop(ctx);
                onHide();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showThumbnail = item.videoThumbnailUrl != null || item.videoId != null;

    return Opacity(
      opacity: item.read ? 0.65 : 1.0,
      child: Material(
        color: item.read ? Colors.transparent : AppColors.surfaceContainer.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Chấm xanh chưa đọc
                SizedBox(
                  width: 12,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: !item.read
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.blueDot, shape: BoxShape.circle),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 4),

                // 2. Avatar + badge icon theo type
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ChannelAvatar(url: item.actor?.avatarUrl, size: 40, onTap: onOpenChannel),
                    Positioned(right: -2, bottom: -2, child: _buildTypeBadge()),
                  ],
                ),
                const SizedBox(width: 12),

                // 3. Message + relative time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: AppColors.textPrimary,
                          fontWeight: item.read ? FontWeight.w400 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Fmt.timeAgo(item.createdAt),
                        style: TextStyle(fontSize: 12, color: item.read ? AppColors.textSecondary : AppColors.link),
                      ),
                    ],
                  ),
                ),

                // 4. Thumbnail video bên phải (nếu có)
                if (showThumbnail) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 84,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AppNetworkImage(url: item.videoThumbnailUrl, width: 84, height: 48, fit: BoxFit.cover),
                        ),
                        if (item.videoDurationSeconds != null && item.videoDurationSeconds! > 0)
                          Container(
                            margin: const EdgeInsets.all(3),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              Fmt.duration(item.videoDurationSeconds!),
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // 5. Menu 3 chấm
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  onPressed: () => _showMenu(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
