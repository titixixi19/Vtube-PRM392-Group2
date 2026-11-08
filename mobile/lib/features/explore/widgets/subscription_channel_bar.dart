import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/channel_avatar.dart';

/// Hàng avatar kênh đã đăng ký cuộn ngang trên Màn 12.
class SubscriptionChannelBar extends StatelessWidget {
  final List<SubscribedChannel> channels;
  final int? selectedChannelId;
  final ValueChanged<int?> onChannelSelected;
  final VoidCallback onAllPressed;
  final VoidCallback? onViewChannelPressed;

  const SubscriptionChannelBar({
    super.key,
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelSelected,
    required this.onAllPressed,
    this.onViewChannelPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();

    final selectedChannel =
        selectedChannelId != null ? channels.where((c) => c.channel.id == selectedChannelId).firstOrNull : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 104,
          child: ListView.separated(
            key: const Key('subscription_channels_list'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: channels.length + 1, // +1 cho nút "Tất cả"
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              if (i == channels.length) {
                // Nút "Tất cả" ở cuối hàng
                return Center(
                  child: InkWell(
                    key: const Key('all_subscriptions_button'),
                    onTap: onAllPressed,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                      child: const Text(
                        'Tất cả',
                        style: TextStyle(
                          color: AppColors.link,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final item = channels[i];
              final ch = item.channel;
              final isSelected = ch.id == selectedChannelId;

              return SizedBox(
                width: 68,
                child: GestureDetector(
                  key: Key('channel_avatar_item_${ch.id}'),
                  onTap: () {
                    // Bấm vào kênh đang chọn thì bỏ chọn (null), nếu chưa chọn thì chọn kênh đó
                    onChannelSelected(isSelected ? null : ch.id);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.accent : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ChannelAvatar(
                          url: ch.avatarUrl,
                          size: 52,
                          hasNewDot: item.hasNew && !isSelected,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ch.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Khi đang lọc theo 1 kênh cụ thể: hiện thanh phụ có nút "Xem kênh"
        if (selectedChannel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.surfaceContainer,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Đang xem video từ ${selectedChannel.channel.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                TextButton(
                  key: const Key('view_channel_button'),
                  onPressed: onViewChannelPressed,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    foregroundColor: AppColors.link,
                  ),
                  child: const Text('Xem kênh', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
