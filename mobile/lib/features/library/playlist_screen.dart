import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 14 · CHI TIẾT PLAYLIST · Người 4
/// API: PlaylistService.detail(id, sort:), update, delete, removeVideo, reorder
/// Kéo thả: ReorderableListView (chỉ khi detail.mine và sort = manual)
/// Phát tất cả: context.push(AppRoutes.video(items.first.video.id))
/// Chi tiết: docs/tasks/NGUOI-4.md (kèm sheet "Lưu vào danh sách phát" trong shared/widgets/save_to_playlist_sheet.dart)
class PlaylistScreen extends StatelessWidget {
  final int playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenPlaceholder(number: '14', title: 'Playlist #$playlistId', owner: 'Người 4'),
    );
  }
}
