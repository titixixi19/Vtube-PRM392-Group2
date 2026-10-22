import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 11 · TRANG KÊNH · Người 3
/// API: ChannelService.get(id), videos(id, sort:), shorts(id), playlists(id),
///      subscribe / unsubscribe, updateMine (khi channel.mine = true)
/// Gợi ý: NestedScrollView + SliverAppBar + TabBar ghim (SliverPersistentHeader)
/// Chi tiết: docs/tasks/NGUOI-3.md
class ChannelScreen extends StatelessWidget {
  final int channelId;

  const ChannelScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenPlaceholder(number: '11', title: 'Trang kênh #$channelId', owner: 'Người 3'),
    );
  }
}
