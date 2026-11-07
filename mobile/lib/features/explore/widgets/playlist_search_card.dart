import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/app_network_image.dart';

/// Thẻ danh sách phát hiển thị trong kết quả tìm kiếm (Màn 10).
class PlaylistSearchCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;

  const PlaylistSearchCard({super.key, required this.playlist, this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbWidth = MediaQuery.sizeOf(context).width * 0.4;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail kèm lớp overlay số lượng video và icon playlist
            SizedBox(
              width: thumbWidth,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(url: playlist.thumbnailUrl),
                      // Lớp overlay màu tối bên phải
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: thumbWidth * 0.4,
                          color: Colors.black.withValues(alpha: 0.75),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.playlist_play, color: Colors.white, size: 22),
                              const SizedBox(height: 2),
                              Text(
                                '${playlist.videoCount} video',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Thông tin playlist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.ownerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Danh sách phát',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
