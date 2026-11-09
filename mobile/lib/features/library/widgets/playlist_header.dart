import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/auth/require_login.dart';
import '../../../core/config/api_config.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/chip_bar.dart';

/// Header của Màn 14: Chi tiết Playlist, bao gồm ảnh nền mờ, cover thumbnail lớn,
/// thông tin playlist, nút tải xuống/chia sẻ/chỉnh sửa, cụm nút Phát tất cả / Trộn bài
/// và thanh chip sắp xếp.
class PlaylistHeader extends StatelessWidget {
  final PlaylistDetail detail;
  final int? videoCount;
  final String? coverUrl;
  final String currentSort;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final VoidCallback? onEdit;
  final VoidCallback? onOpenChannel;

  const PlaylistHeader({
    super.key,
    required this.detail,
    this.videoCount,
    this.coverUrl,
    required this.currentSort,
    required this.onSortChanged,
    required this.onPlayAll,
    required this.onShuffle,
    this.onEdit,
    this.onOpenChannel,
  });

  static const sortModes = ['manual', 'added_new', 'added_old', 'popular', 'published'];
  static const sortLabels = ['Thủ công', 'Mới thêm', 'Cũ nhất', 'Phổ biến', 'Ngày đăng'];

  String get _coverUrl {
    if (coverUrl != null) {
      return coverUrl!;
    }
    if (detail.playlist.thumbnailUrl != null && detail.playlist.thumbnailUrl!.isNotEmpty) {
      return detail.playlist.thumbnailUrl!;
    }
    if (detail.items.isNotEmpty) {
      return detail.items.first.video.thumbnailUrl ?? '';
    }
    return '';
  }

  Widget _buildVisibilityPill() {
    IconData icon;
    String label;
    switch (detail.playlist.visibility) {
      case 'public':
        icon = Icons.public;
        label = 'Công khai';
        break;
      case 'unlisted':
        icon = Icons.link;
        label = 'Không công khai';
        break;
      case 'private':
      default:
        icon = Icons.lock_outline;
        label = 'Riêng tư';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = _coverUrl;
    final selectedSortIndex = sortModes.indexOf(currentSort).clamp(0, sortModes.length - 1);

    final totalVideos = videoCount ?? detail.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Khối Header có nền mờ từ thumbnail đầu tiên
        Stack(
          children: [
            // Lớp ảnh làm mờ và gradient tối
            if (cover.isNotEmpty)
              Positioned.fill(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: AppNetworkImage(
                      url: cover,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0.6),
                      AppColors.background.withValues(alpha: 0.88),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),

            // Nội dung thông tin phía trên
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cover thumbnail 16:9
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AppNetworkImage(
                                url: cover,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.playlist_play, size: 14, color: AppColors.textPrimary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$totalVideos VIDEO',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tiêu đề Playlist
                  Text(
                    detail.playlist.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  if (detail.playlist.description != null && detail.playlist.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail.playlist.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Thông tin chủ sở hữu & lượt xem & quyền riêng tư
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      InkWell(
                        onTap: onOpenChannel,
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          detail.playlist.ownerName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.link),
                        ),
                      ),
                      const Text('·', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        '${videoCount ?? detail.playlist.videoCount} video',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const Text('·', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        Fmt.views(detail.totalViews),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      _buildVisibilityPill(),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Hàng nút thao tác: Tải xuống, Chia sẻ, Sửa
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.arrow_downward, size: 20),
                        tooltip: 'Tải xuống',
                        onPressed: totalVideos > 0
                            ? () {
                                showSnack(context, 'Đang tải xuống 1/$totalVideos video');
                              }
                            : null,
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        tooltip: 'Chia sẻ',
                        onPressed: () {
                          final url = ApiConfig.resolveUrl('/playlist?list=${detail.playlist.id}');
                          Share.share('${detail.playlist.title} - $url');
                        },
                      ),
                      if (detail.mine && !detail.playlist.isSystem && onEdit != null) ...[
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Chỉnh sửa playlist',
                          onPressed: onEdit,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cụm CTA chính: Phát tất cả + Trộn bài
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: totalVideos > 0 ? onPlayAll : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Phát tất cả'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.chipSelectedBg,
                            foregroundColor: AppColors.chipSelectedFg,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: totalVideos > 0 ? onShuffle : null,
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Trộn bài'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surfaceHigh,
                            foregroundColor: AppColors.textPrimary,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // 2. Chip sắp xếp
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: ChipBar(
            labels: sortLabels,
            selectedIndex: selectedSortIndex,
            onSelected: (index) => onSortChanged(sortModes[index]),
          ),
        ),
      ],
    );
  }
}
