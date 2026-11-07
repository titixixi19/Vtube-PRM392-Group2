import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/auth/require_login.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/models.dart';
import '../../../data/services/channel_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/channel_avatar.dart';
import '../../../shared/widgets/subscribe_button.dart';
import 'shorts_action_column.dart';

/// Hiển thị một trang Video Short đơn lẻ với player dọc, touch gestures và overlay thông tin.
class ShortsPageItem extends StatefulWidget {
  final Video short;
  final VideoPlayerController? controller;
  final bool isCurrent;
  final VoidCallback onOpenComments;

  const ShortsPageItem({
    super.key,
    required this.short,
    required this.controller,
    required this.isCurrent,
    required this.onOpenComments,
  });

  @override
  State<ShortsPageItem> createState() => _ShortsPageItemState();
}

class _ShortsPageItemState extends State<ShortsPageItem> with SingleTickerProviderStateMixin {
  final _actionKey = GlobalKey<ShortsActionColumnState>();
  late bool _subscribed;
  bool _showPauseIcon = false;
  bool _isPaused = false;

  // Animation tim bay khi chạm đúp
  Offset? _heartPosition;
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnim;
  late Animation<double> _heartOpacityAnim;

  @override
  void initState() {
    super.initState();
    _subscribed = widget.short.viewer?.subscribed ?? false;

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heartScaleAnim = Tween<double>(begin: 0.5, end: 1.4).animate(
      CurvedAnimation(parent: _heartAnimController, curve: Curves.easeOutBack),
    );

    _heartOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _heartAnimController, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    _heartAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _heartPosition = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShortsPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.short.id != widget.short.id) {
      _subscribed = widget.short.viewer?.subscribed ?? false;
    }
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _handleSingleTap() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
      setState(() {
        _isPaused = true;
        _showPauseIcon = true;
      });
    } else {
      controller.play();
      setState(() {
        _isPaused = false;
        _showPauseIcon = true;
      });
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showPauseIcon = false);
    });
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    setState(() {
      _heartPosition = details.localPosition;
    });
    _heartAnimController.forward(from: 0.0);
    _actionKey.currentState?.triggerLikeFromDoubleTap();
  }

  Future<void> _toggleSubscribe() async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;

    final before = _subscribed;
    setState(() => _subscribed = !before);

    try {
      final channels = context.read<ChannelService>();
      if (before) {
        await channels.unsubscribe(widget.short.channel.id);
        if (mounted) showSnack(context, 'Đã hủy đăng ký');
      } else {
        await channels.subscribe(widget.short.channel.id);
        if (mounted) showSnack(context, 'Đã đăng ký kênh');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _subscribed = before);
      showSnack(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _subscribed = before);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isInitialized = controller != null && controller.value.isInitialized;
    final short = widget.short;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video Player hoặc Thumbnail dự phòng
        GestureDetector(
          onTap: _handleSingleTap,
          onDoubleTapDown: _handleDoubleTapDown,
          onDoubleTap: () {}, // Giữ gesture detector nhận double tap
          child: Container(
            color: Colors.black,
            child: isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(url: short.thumbnailUrl),
                      const Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    ],
                  ),
          ),
        ),

        // Lớp gradient mờ ở đáy để dễ đọc chữ
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 240,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(200),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 2. Icon Play/Pause lớn giữa màn hình khi chạm 1 lần
        if (_showPauseIcon)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPaused ? Icons.pause : Icons.play_arrow,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),

        // 3. Tim bay khi chạm đúp
        if (_heartPosition != null)
          Positioned(
            left: _heartPosition!.dx - 40,
            top: _heartPosition!.dy - 40,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _heartAnimController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heartOpacityAnim.value,
                    child: Transform.scale(
                      scale: _heartScaleAnim.value,
                      child: const Icon(Icons.favorite, size: 80, color: Colors.red),
                    ),
                  );
                },
              ),
            ),
          ),

        // 4. Cột tác vụ bên phải
        Positioned(
          right: 12,
          bottom: 24,
          child: ShortsActionColumn(
            key: _actionKey,
            short: short,
            onOpenComments: widget.onOpenComments,
          ),
        ),

        // 5. Thông tin kênh và tiêu đề ở góc dưới trái
        Positioned(
          left: 12,
          right: 80,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hàng Kênh: Avatar + @handle + SubscribeButton
              Row(
                children: [
                  ChannelAvatar(
                    url: short.channel.avatarUrl,
                    size: 36,
                    onTap: () => context.push(AppRoutes.channel(short.channel.id)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.channel(short.channel.id)),
                      child: Text(
                        '@${short.channel.handle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SubscribeButton(
                    subscribed: _subscribed,
                    red: true,
                    onPressed: _toggleSubscribe,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Tiêu đề video Short
              Text(
                short.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.3, color: Colors.white),
              ),
              const SizedBox(height: 6),
              // Dòng nhạc chạy chữ
              Row(
                children: [
                  const Icon(Icons.music_note, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Âm thanh gốc - ${short.channel.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 6. Thanh tiến độ mảnh ở đáy video
        if (isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: AppColors.accent,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
    );
  }
}
