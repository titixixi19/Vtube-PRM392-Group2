import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 8 · SHORTS · Người 2 (tab 2)
/// API: VideoService.shorts(page:), react, addView; ChannelService.subscribe; showCommentsSheet
/// [startVideoId]: mở đúng short đã bấm từ kệ Shorts (route /shorts?start=<id>).
///   Nếu short đó chưa có trong trang đầu, gọi VideoService.detail(startVideoId) và đặt nó lên đầu danh sách.
/// Gợi ý: PageView(scrollDirection: Axis.vertical) + VideoPlayerController, preload 1-2 video kế tiếp,
///   dispose controller khi đã cách xa để không tràn bộ nhớ, dừng video khi đổi tab.
/// Chi tiết: docs/tasks/NGUOI-2.md
class ShortsScreen extends StatelessWidget {
  final int? startVideoId;

  const ShortsScreen({super.key, this.startVideoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ScreenPlaceholder(number: '8', title: 'Shorts${startVideoId == null ? '' : ' (bắt đầu #$startVideoId)'}', owner: 'Người 2'),
    );
  }
}
