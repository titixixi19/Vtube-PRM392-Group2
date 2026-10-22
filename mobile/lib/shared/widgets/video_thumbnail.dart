import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'app_network_image.dart';

/// Thumbnail 16:9 + badge thời lượng (hoặc "TRỰC TIẾP") + thanh tiến độ đỏ (progress 0..1).
class VideoThumbnail extends StatelessWidget {
  final Video video;
  final double? progress;
  final BorderRadius borderRadius;

  const VideoThumbnail({super.key, required this.video, this.progress, this.borderRadius = const BorderRadius.all(Radius.circular(12))});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(fit: StackFit.expand, children: [
          AppNetworkImage(url: video.thumbnailUrl),
          Positioned(
            right: 6,
            bottom: 6 + (progress != null ? 3 : 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: video.isLive ? AppColors.accent : const Color(0xCC000000),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                video.isLive ? 'TRỰC TIẾP' : Fmt.duration(video.durationSeconds),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          if (progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                color: AppColors.accent,
                backgroundColor: Colors.white24,
              ),
            ),
        ]),
      ),
    );
  }
}
