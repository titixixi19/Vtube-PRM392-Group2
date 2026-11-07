import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';

/// Hiển thị bottom sheet giới thiệu chi tiết về kênh.
Future<void> showChannelAboutSheet(BuildContext context, Channel channel) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => ChannelAboutSheet(channel: channel),
  );
}

class ChannelAboutSheet extends StatelessWidget {
  final Channel channel;

  const ChannelAboutSheet({super.key, required this.channel});

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day} thg ${dt.month}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final link = 'https://vtube.vn/@${channel.handle}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Giới thiệu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mô tả
              const Text(
                'Mô tả',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                (channel.description != null && channel.description!.trim().isNotEmpty)
                    ? channel.description!
                    : 'Kênh này chưa có nội dung giới thiệu.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const Divider(height: 28, color: AppColors.divider),
              // Thông tin chi tiết
              const Text(
                'Thông tin khác',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: AppColors.link),
                title: Text(link, style: const TextStyle(fontSize: 13, color: AppColors.link)),
                subtitle: const Text('Đường liên kết kênh', style: TextStyle(fontSize: 11)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline, color: AppColors.textSecondary),
                title: Text(Fmt.subscribers(channel.subscriberCount), style: const TextStyle(fontSize: 13)),
                subtitle: const Text('Người đăng ký', style: TextStyle(fontSize: 11)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.video_library_outlined, color: AppColors.textSecondary),
                title: Text('${channel.videoCount} video', style: const TextStyle(fontSize: 13)),
                subtitle: const Text('Số lượng video', style: TextStyle(fontSize: 11)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.visibility_outlined, color: AppColors.textSecondary),
                title: Text(Fmt.views(channel.totalViews), style: const TextStyle(fontSize: 13)),
                subtitle: const Text('Tổng số lượt xem', style: TextStyle(fontSize: 11)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                title: Text('Đã tham gia ${_formatDate(channel.createdAt)}', style: const TextStyle(fontSize: 13)),
                subtitle: const Text('Ngày lập kênh', style: TextStyle(fontSize: 11)),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.public, color: AppColors.textSecondary),
                title: Text('Việt Nam', style: TextStyle(fontSize: 13)),
                subtitle: Text('Quốc gia', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('channel_share_button_sheet'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Share.share('Kênh ${channel.name}: $link');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceHighest,
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Chia sẻ kênh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
