import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'channel_avatar.dart';
import 'video_thumbnail.dart';

/// Card video lớn (Trang chủ, Kênh đăng ký, video gợi ý ở màn 6).
class VideoCardLarge extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;
  final VoidCallback? onChannelTap;
  final VoidCallback? onMore;
  final double? progress;

  const VideoCardLarge({super.key, required this.video, this.onTap, this.onChannelTap, this.onMore, this.progress});

  @override
  Widget build(BuildContext context) {
    final meta = video.isLive
        ? '${video.channel.name} · ${Fmt.count(video.viewCount)} người đang xem'
        : Fmt.videoMeta(video.channel.name, video.viewCount, video.publishedAt);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          VideoThumbnail(video: video, progress: progress, borderRadius: BorderRadius.zero),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 0, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ChannelAvatar(url: video.channel.avatarUrl, size: 36, onTap: onChannelTap),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.more_vert, size: 20), onPressed: onMore),
            ]),
          ),
        ]),
      ),
    );
  }
}
