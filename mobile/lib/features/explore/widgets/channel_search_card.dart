import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/auth/require_login.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/services/channel_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/subscribe_button.dart';

/// Thẻ kênh nổi bật trên đầu kết quả tìm kiếm (Màn 10).
class ChannelSearchCard extends StatefulWidget {
  final Channel channel;
  final VoidCallback? onTap;

  const ChannelSearchCard({super.key, required this.channel, this.onTap});

  @override
  State<ChannelSearchCard> createState() => _ChannelSearchCardState();
}

class _ChannelSearchCardState extends State<ChannelSearchCard> {
  late bool _subscribed;
  late int _subscriberCount;

  @override
  void initState() {
    super.initState();
    _subscribed = widget.channel.subscribed;
    _subscriberCount = widget.channel.subscriberCount;
  }

  @override
  void didUpdateWidget(ChannelSearchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id ||
        oldWidget.channel.subscribed != widget.channel.subscribed ||
        oldWidget.channel.subscriberCount != widget.channel.subscriberCount) {
      _subscribed = widget.channel.subscribed;
      _subscriberCount = widget.channel.subscriberCount;
    }
  }

  Future<void> _toggleSubscribe() async {
    final service = context.read<ChannelService>();
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    final before = _subscribed;
    final beforeCount = _subscriberCount;

    setState(() {
      _subscribed = !before;
      _subscriberCount += before ? -1 : 1;
    });

    try {
      if (before) {
        await service.unsubscribe(widget.channel.id);
      } else {
        await service.subscribe(widget.channel.id);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _subscribed = before;
        _subscriberCount = beforeCount;
      });
      showSnack(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscribed = before;
        _subscriberCount = beforeCount;
      });
      showSnack(context, 'Không thể cập nhật đăng ký kênh.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Avatar kênh lớn
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: AppNetworkImage(url: ch.avatarUrl),
              ),
            ),
            const SizedBox(width: 14),
            // Thông tin kênh
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (ch.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle, size: 14, color: AppColors.link),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${ch.handle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.subscribers(_subscriberCount)} · ${ch.videoCount} video',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SubscribeButton(
                    key: const Key('channel_card_subscribe_button'),
                    subscribed: _subscribed,
                    onPressed: _toggleSubscribe,
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
