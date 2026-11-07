import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/channel_avatar.dart';
import '../../../shared/widgets/subscribe_button.dart';

/// Header của Trang kênh (Màn 11): Banner, Avatar, Tên kênh, Thông số, Nút thao tác.
class ChannelHeader extends StatelessWidget {
  final Channel channel;
  final VoidCallback onToggleSubscribe;
  final VoidCallback onJoin;
  final VoidCallback onCustomizeChannel;
  final VoidCallback onManageVideos;
  final VoidCallback onShowAbout;

  const ChannelHeader({
    super.key,
    required this.channel,
    required this.onToggleSubscribe,
    required this.onJoin,
    required this.onCustomizeChannel,
    required this.onManageVideos,
    required this.onShowAbout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Channel Banner (tỉ lệ ~16:5 hoặc 3:1)
        AspectRatio(
          aspectRatio: 16 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (channel.bannerUrl != null && channel.bannerUrl!.isNotEmpty)
                AppNetworkImage(url: channel.bannerUrl, fit: BoxFit.cover)
              else
                Container(
                  color: AppColors.surfaceHigh,
                  child: const Center(
                    child: Icon(Icons.panorama_outlined, size: 40, color: AppColors.textSecondary),
                  ),
                ),
              // Gradient mờ dần ở đáy banner
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.surface.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Avatar & Thông tin kênh
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar tròn lớn (68dp)
                  ChannelAvatar(url: channel.avatarUrl, size: 68),
                  const SizedBox(width: 14),
                  // Tên, tích xanh, handle & thông số
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                channel.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (channel.verified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle, size: 18, color: AppColors.link),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${channel.handle} · ${Fmt.subscribers(channel.subscriberCount)} · ${channel.videoCount} video',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 3. Mô tả ngắn + nút "...thêm"
              if (channel.description != null && channel.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onShowAbout,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: channel.description!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                        ),
                        const TextSpan(
                          text: ' ...thêm',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // 4. Các nút thao tác theo quyền sở hữu kênh
              const SizedBox(height: 14),
              if (!channel.mine)
                Row(
                  children: [
                    Expanded(
                      child: SubscribeButton(
                        subscribed: channel.subscribed,
                        onPressed: onToggleSubscribe,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('channel_join_button'),
                        onPressed: onJoin,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceHighest,
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        icon: const Icon(Icons.loyalty_outlined, size: 18, color: AppColors.link),
                        label: const Text('Tham gia'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('channel_customize_button'),
                        onPressed: onCustomizeChannel,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceHighest,
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Tùy chỉnh kênh'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('channel_manage_videos_button'),
                        onPressed: onManageVideos,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceHighest,
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        icon: const Icon(Icons.video_library_outlined, size: 18),
                        label: const Text('Quản lý video'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
