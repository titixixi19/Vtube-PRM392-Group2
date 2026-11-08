import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/video_service.dart';
import '../../../shared/widgets/chip_bar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/video_card_large.dart';
import '../../../shared/widgets/video_options_sheet.dart';

/// Danh sách video gợi ý liên quan với thanh chip lọc.
class RelatedVideosSection extends StatefulWidget {
  final int videoId;

  const RelatedVideosSection({super.key, required this.videoId});

  @override
  State<RelatedVideosSection> createState() => _RelatedVideosSectionState();
}

class _RelatedVideosSectionState extends State<RelatedVideosSection> {
  static const _filters = [
    ('Tất cả', 'all'),
    ('Từ kênh này', 'channel'),
    ('Có liên quan', 'related'),
    ('Mới tải lên', 'recent'),
  ];

  int _selectedFilterIndex = 0;
  final _videos = <Video>[];
  final _hiddenVideoIds = <int>{};
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos(initial: true);
  }

  @override
  void didUpdateWidget(covariant RelatedVideosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _selectedFilterIndex = 0;
      _loadVideos(initial: true);
    }
  }

  Future<void> _loadVideos({bool initial = false}) async {
    if (!initial && _loading) return;
    final curReq = ++_reqId;

    if (initial) {
      setState(() {
        _videos.clear();
        _page = 0;
        _hasMore = true;
        _error = null;
        _loading = true;
      });
    } else {
      if (!_hasMore) return;
      setState(() => _loading = true);
    }

    try {
      final filter = _filters[_selectedFilterIndex].$2;
      final res = await context.read<VideoService>().related(
            widget.videoId,
            filter: filter,
            page: _page,
          );

      if (!mounted || curReq != _reqId) return;

      setState(() {
        _videos.addAll(res.items);
        _hasMore = res.hasMore;
        _page++;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || curReq != _reqId) return;
      setState(() {
        _error = 'Không thể tải video gợi ý';
        _loading = false;
      });
    }
  }

  void _onFilterChanged(int index) {
    if (_selectedFilterIndex == index) return;
    setState(() => _selectedFilterIndex = index);
    _loadVideos(initial: true);
  }

  @override
  Widget build(BuildContext context) {
    final visibleVideos = _videos.where((v) => !_hiddenVideoIds.contains(v.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChipBar(
          labels: _filters.map((f) => f.$1).toList(),
          selectedIndex: _selectedFilterIndex,
          onSelected: _onFilterChanged,
        ),
        const SizedBox(height: 8),
        if (_loading && visibleVideos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: LoadingView(),
          )
        else if (_error != null && visibleVideos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: TextButton.icon(
                onPressed: () => _loadVideos(initial: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại video gợi ý'),
              ),
            ),
          )
        else if (visibleVideos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Không có video gợi ý',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleVideos.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == visibleVideos.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _loading
                        ? const LoadingView()
                        : TextButton(
                            onPressed: () => _loadVideos(initial: false),
                            child: const Text('Tải thêm'),
                          ),
                  ),
                );
              }

              final video = visibleVideos[i];
              return VideoCardLarge(
                video: video,
                onTap: () => context.pushReplacement(AppRoutes.video(video.id)),
                onChannelTap: () => context.push(AppRoutes.channel(video.channel.id)),
                onMore: () => showVideoOptionsSheet(
                  context,
                  video,
                  onHidden: () {
                    if (mounted) {
                      setState(() => _hiddenVideoIds.add(video.id));
                    }
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
