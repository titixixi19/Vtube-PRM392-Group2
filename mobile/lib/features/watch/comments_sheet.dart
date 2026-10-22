import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';

/// MÀN 7 · BÌNH LUẬN (bottom sheet) · Người 2
/// API: CommentService.list / replies / create / update / delete / react / togglePin / toggleHeart
/// Mở từ màn 6 và màn 8: showCommentsSheet(context, videoId)
/// Gợi ý: DraggableScrollableSheet(initialChildSize: 0.75, maxChildSize: 1)
/// Chi tiết: docs/tasks/NGUOI-2.md
Future<void> showCommentsSheet(BuildContext context, int videoId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.75,
      child: ScreenPlaceholder(number: '7', title: 'Bình luận video #$videoId', owner: 'Người 2'),
    ),
  );
}
