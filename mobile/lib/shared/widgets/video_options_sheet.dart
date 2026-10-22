import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/playlist_service.dart';
import '../../data/services/video_service.dart';
import 'save_to_playlist_sheet.dart';

/// Sheet nút 3 chấm của mọi video. [onHidden] được gọi khi chọn "Không quan tâm"
/// để màn hình xóa video khỏi danh sách.
Future<void> showVideoOptionsSheet(BuildContext context, Video video, {VoidCallback? onHidden}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.watch_later_outlined),
          title: const Text('Lưu vào danh sách Xem sau'),
          onTap: () async {
            Navigator.pop(ctx);
            if (!await requireLogin(context)) return;
            if (!context.mounted) return;
            try {
              await context.read<PlaylistService>().addWatchLater(video.id);
              if (context.mounted) showSnack(context, 'Đã lưu vào Xem sau');
            } on ApiException catch (e) {
              if (context.mounted) showSnack(context, e.message);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.playlist_add),
          title: const Text('Lưu vào danh sách phát'),
          onTap: () async {
            Navigator.pop(ctx);
            if (!await requireLogin(context)) return;
            if (context.mounted) showSaveToPlaylistSheet(context, video.id);
          },
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Chia sẻ'),
          onTap: () {
            Navigator.pop(ctx);
            Share.share('${video.title}\nhttps://vtube.vn/watch?v=${video.id}');
          },
        ),
        ListTile(
          leading: const Icon(Icons.block),
          title: const Text('Không quan tâm'),
          onTap: () async {
            Navigator.pop(ctx);
            if (!await requireLogin(context)) return;
            if (!context.mounted) return;
            try {
              await context.read<VideoService>().notInterested(video.id);
              onHidden?.call();
              if (context.mounted) showSnack(context, 'Video đã bị ẩn khỏi nguồn cấp dữ liệu');
            } on ApiException catch (e) {
              if (context.mounted) showSnack(context, e.message);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Báo cáo'),
          onTap: () {
            Navigator.pop(ctx);
            showSnack(context, 'Cảm ơn bạn đã báo cáo');
          },
        ),
      ]),
    ),
  );
}
