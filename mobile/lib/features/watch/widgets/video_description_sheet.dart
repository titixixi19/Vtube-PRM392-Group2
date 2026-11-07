import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';

/// Bottom sheet xem chi tiết mô tả video, hashtag và 3 cột thống kê.
Future<void> showVideoDescriptionSheet(BuildContext context, Video video) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Mô tả',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                video.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
              ),
              const SizedBox(height: 16),
              // 3 cột thông kê: Lượt thích - Lượt xem - Ngày đăng
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCol(Fmt.count(video.likeCount), 'Lượt thích'),
                    Container(width: 1, height: 28, color: Colors.white12),
                    _buildStatCol(Fmt.count(video.viewCount), 'Lượt xem'),
                    Container(width: 1, height: 28, color: Colors.white12),
                    _buildStatCol(Fmt.timeAgo(video.publishedAt), 'Ngày tải lên'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Nội dung mô tả chi tiết
              SelectableText(
                video.description?.trim().isNotEmpty == true
                    ? video.description!
                    : 'Không có mô tả nào cho video này.',
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
              ),
              if (video.tags != null && video.tags!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: video.tags!
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .map((tag) => Text(
                            tag.startsWith('#') ? tag : '#$tag',
                            style: const TextStyle(fontSize: 13, color: AppColors.link),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

Widget _buildStatCol(String value, String label) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
  );
}
