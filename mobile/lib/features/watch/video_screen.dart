import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';
import 'comments_sheet.dart';

/// MÀN 6 · XEM VIDEO · Người 2
/// API:
///   - VideoService.detail(videoId)               (có video.viewer khi đã đăng nhập)
///   - VideoService.related(videoId, filter:)     (video gợi ý)
///   - VideoService.addView(videoId)              (khi bắt đầu phát)
///   - VideoService.react(videoId, 1 | -1 | 0)
///   - ChannelService.subscribe / unsubscribe
///   - HistoryService.saveProgress(videoId, giây) (mỗi 10 giây + khi rời màn, chỉ khi đã đăng nhập)
///   - PlaylistService.addWatchLater / showSaveToPlaylistSheet (nút Lưu)
/// Trình phát: video_player + chewie (đã có trong pubspec). URL: ApiConfig.resolveUrl(video.videoUrl)
/// Bình luận: showCommentsSheet(context, videoId)  (màn 7)
/// Chi tiết: docs/tasks/NGUOI-2.md
class VideoScreen extends StatelessWidget {
  final int videoId;

  const VideoScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenPlaceholder(
        number: '6',
        title: 'Xem video #$videoId',
        owner: 'Người 2',
        actions: [
          TextButton(onPressed: () => showCommentsSheet(context, videoId), child: const Text('Mở bình luận (màn 7)')),
        ],
      ),
    );
  }
}
