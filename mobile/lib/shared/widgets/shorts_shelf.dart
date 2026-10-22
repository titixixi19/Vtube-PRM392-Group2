import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'app_network_image.dart';

/// Kệ Shorts nằm ngang (thumbnail 9:16). Dùng ở Trang chủ, Kết quả tìm kiếm, Kênh đăng ký.
class ShortsShelf extends StatelessWidget {
  final List<Video> shorts;
  final void Function(Video short) onTap;
  final String title;

  const ShortsShelf({super.key, required this.shorts, required this.onTap, this.title = 'Shorts'});

  @override
  Widget build(BuildContext context) {
    if (shorts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(children: [
            const Icon(Icons.slow_motion_video, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
        ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: shorts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = shorts[i];
              return GestureDetector(
                onTap: () => onTap(s),
                child: SizedBox(
                  width: 158,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [
                      AppNetworkImage(url: s.thumbnailUrl),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(Fmt.views(s.viewCount), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
