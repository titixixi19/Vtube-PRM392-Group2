import 'package:flutter/material.dart';

/// Sheet "Lưu vào danh sách phát": danh sách playlist có checkbox + "Danh sách phát mới".
///
/// TODO(Người 4): làm sheet này (màn 14 - phần mở rộng của Playlist).
///   - Gọi PlaylistService.mine(videoId: videoId) để biết containsVideo của từng playlist
///   - Tick -> addVideo, bỏ tick -> removeVideo
///   - "Danh sách phát mới" -> dialog nhập tên + chế độ hiển thị -> create rồi addVideo
/// Được dùng ở: menu 3 chấm (mọi video) và nút "Lưu" ở màn 6.
Future<void> showSaveToPlaylistSheet(BuildContext context, int videoId) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Lưu vào danh sách phát - Người 4 đang làm'),
      ),
    ),
  );
}
