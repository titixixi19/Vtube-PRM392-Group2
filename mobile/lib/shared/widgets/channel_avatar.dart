import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'app_network_image.dart';

/// Avatar tròn. [hasNewDot] = chấm xanh "có video mới" (màn 12).
class ChannelAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final bool hasNewDot;
  final VoidCallback? onTap;

  const ChannelAvatar({super.key, required this.url, this.size = 36, this.hasNewDot = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget avatar = ClipOval(
      child: url == null
          ? Container(
              width: size,
              height: size,
              color: AppColors.surfaceHighest,
              child: Icon(Icons.person, size: size * 0.6, color: AppColors.textSecondary),
            )
          : AppNetworkImage(url: url, width: size, height: size),
    );
    if (hasNewDot) {
      avatar = Stack(clipBehavior: Clip.none, children: [
        avatar,
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: const BoxDecoration(color: AppColors.blueDot, shape: BoxShape.circle),
          ),
        ),
      ]);
    }
    return onTap == null ? avatar : GestureDetector(onTap: onTap, child: avatar);
  }
}
