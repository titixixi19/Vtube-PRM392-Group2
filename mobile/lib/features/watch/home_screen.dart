import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../shared/widgets/screen_placeholder.dart';
import '../../shared/widgets/top_bar.dart';

/// MÀN 5 · TRANG CHỦ · Người 2 (tab 1)
/// API:
///   - VideoService.categories()                              (chip danh mục)
///   - VideoService.feed(category: slug, page: n)             (feed cuộn vô hạn)
///   - VideoService.shorts(size: 10)                          (kệ Shorts sau video thứ 3)
/// Widget có sẵn: VtubeLogo, topBarActions, ChipBar, VideoCardLarge, ShortsShelf, showVideoOptionsSheet
/// Chi tiết: docs/tasks/NGUOI-2.md
///
/// Các nút bên dưới chỉ để cả nhóm mở thử màn của mình khi Trang chủ chưa xong. Xóa khi làm.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const VtubeLogo(), actions: topBarActions(context)),
      body: SingleChildScrollView(
        child: ScreenPlaceholder(
          number: '5',
          title: 'Trang chủ',
          owner: 'Người 2',
          actions: [
            const Text('Mở nhanh để thử:'),
            TextButton(onPressed: () => context.push(AppRoutes.video(1)), child: const Text('Màn 6 · Xem video #1')),
            TextButton(onPressed: () => context.go(AppRoutes.shortsAt(27)), child: const Text('Màn 8 · Shorts bắt đầu từ #27')),
            TextButton(onPressed: () => context.push(AppRoutes.search), child: const Text('Màn 9 · Tìm kiếm')),
            TextButton(onPressed: () => context.push(AppRoutes.searchResults('flutter')), child: const Text('Màn 10 · Kết quả "flutter"')),
            TextButton(onPressed: () => context.push(AppRoutes.channel(2)), child: const Text('Màn 11 · Kênh VTech Studio')),
            TextButton(onPressed: () => context.push(AppRoutes.history), child: const Text('Màn 13 · Lịch sử')),
            TextButton(onPressed: () => context.push(AppRoutes.playlist(100)), child: const Text('Màn 14 · Playlist "Học Flutter"')),
            TextButton(onPressed: () => context.push(AppRoutes.upload), child: const Text('Màn 15 · Tải video lên')),
            TextButton(onPressed: () => context.push(AppRoutes.notifications), child: const Text('Màn 16 · Thông báo')),
          ],
        ),
      ),
    );
  }
}
