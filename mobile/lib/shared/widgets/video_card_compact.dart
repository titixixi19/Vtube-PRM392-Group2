import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'video_thumbnail.dart';

/// Card video nằm ngang: thumbnail bên trái ~40% (Kết quả tìm kiếm, Lịch sử, Playlist, Trang kênh).
class VideoCardCompact extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final double? progress;

  /// Widget đặt trước thumbnail (vd. số thứ tự trong playlist).
  final Widget? leading;

  /// Widget thay cho nút 3 chấm (vd. tay kéo thả).
  final Widget? trailing;

  const VideoCardCompact({super.key, required this.video, this.onTap, this.onMore, this.progress, this.leading, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (leading != null) leading!,
          SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.4,
            child: VideoThumbnail(video: video, progress: progress, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3)),
              const SizedBox(height: 4),
              Text(video.channel.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('${Fmt.views(video.viewCount)} · ${Fmt.timeAgo(video.publishedAt)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          trailing ?? IconButton(icon: const Icon(Icons.more_vert, size: 20), onPressed: onMore),
        ]),
      ),
    );
  }
}
