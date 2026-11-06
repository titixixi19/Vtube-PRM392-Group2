import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/services/channel_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/chip_bar.dart';
import '../../../shared/widgets/shorts_shelf.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/video_card_compact.dart';
import '../../../shared/widgets/video_card_large.dart';
import '../../../shared/widgets/video_options_sheet.dart';

// ==========================================
// 1. TAB TRANG CHỦ
// ==========================================
class ChannelHomeTab extends StatefulWidget {
  final Channel channel;

  const ChannelHomeTab({super.key, required this.channel});

  @override
  State<ChannelHomeTab> createState() => _ChannelHomeTabState();
}

class _ChannelHomeTabState extends State<ChannelHomeTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _error;
  List<Video> _videos = [];
  List<Video> _shorts = [];
  List<Playlist> _playlists = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = context.read<ChannelService>();
      final results = await Future.wait([
        service.videos(widget.channel.id, sort: 'newest', page: 0, size: 10),
        service.shorts(widget.channel.id, page: 0, size: 10),
        service.playlists(widget.channel.id),
      ]);

      if (!mounted) return;
      setState(() {
        _videos = (results[0] as PageResult<Video>).items;
        _shorts = (results[1] as PageResult<Video>).items;
        _playlists = results[2] as List<Playlist>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải nội dung trang chủ';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _loadData);

    final isEmpty = _videos.isEmpty && _shorts.isEmpty && _playlists.isEmpty;
    if (isEmpty) {
      return EmptyView(
        icon: Icons.video_library_outlined,
        title: 'Kênh này không có nội dung nào',
        message: widget.channel.mine ? 'Bắt đầu tạo và chia sẻ video đầu tiên của bạn' : null,
        actionLabel: widget.channel.mine ? 'Tải video lên' : null,
        onAction: widget.channel.mine ? () => context.push(AppRoutes.upload) : null,
      );
    }

    final featuredVideo = _videos.isNotEmpty ? _videos.first : null;
    final otherVideos = _videos.length > 1 ? _videos.sublist(1) : <Video>[];

    return ListView(
      key: const PageStorageKey('channel_home_tab_list'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Video nổi bật
        if (featuredVideo != null) ...[
          VideoCardLarge(
            video: featuredVideo,
            onTap: () => context.push(AppRoutes.video(featuredVideo.id)),
            onMore: () => showVideoOptionsSheet(context, featuredVideo),
          ),
          const SizedBox(height: 8),
        ],

        // Kệ Shorts nếu có
        if (_shorts.isNotEmpty) ...[
          ShortsShelf(
            shorts: _shorts,
            onTap: (s) => context.push(AppRoutes.shortsAt(s.id)),
          ),
          const SizedBox(height: 8),
        ],

        // Các video khác
        if (otherVideos.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Video tải lên gần đây',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          for (final v in otherVideos)
            VideoCardCompact(
              video: v,
              onTap: () => context.push(AppRoutes.video(v.id)),
              onMore: () => showVideoOptionsSheet(context, v),
            ),
          const SizedBox(height: 12),
        ],

        // Danh sách phát
        if (_playlists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Danh sách phát',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          for (final p in _playlists) _PlaylistTile(playlist: p),
        ],
      ],
    );
  }
}

// ==========================================
// 2. TAB VIDEO
// ==========================================
class ChannelVideosTab extends StatefulWidget {
  final Channel channel;

  const ChannelVideosTab({super.key, required this.channel});

  @override
  State<ChannelVideosTab> createState() => _ChannelVideosTabState();
}

class _ChannelVideosTabState extends State<ChannelVideosTab> with AutomaticKeepAliveClientMixin {
  static const _sortOptions = ['newest', 'popular', 'oldest'];
  static const _sortLabels = ['Mới nhất', 'Phổ biến', 'Cũ nhất'];

  int _selectedSortIndex = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<Video> _videos = [];
  int _page = 0;
  bool _hasMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVideos(reset: true);
  }

  Future<void> _loadVideos({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 0;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final pageToLoad = reset ? 0 : _page + 1;
      final res = await context.read<ChannelService>().videos(
            widget.channel.id,
            sort: _sortOptions[_selectedSortIndex],
            page: pageToLoad,
            size: 20,
          );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _videos = res.items;
        } else {
          _videos.addAll(res.items);
        }
        _page = pageToLoad;
        _hasMore = res.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (reset) _error = 'Không thể tải danh sách video';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSortChanged(int index) {
    if (_selectedSortIndex == index) return;
    setState(() => _selectedSortIndex = index);
    _loadVideos(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // ChipBar đổi sắp xếp: Mới nhất / Phổ biến / Cũ nhất
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ChipBar(
            labels: _sortLabels,
            selectedIndex: _selectedSortIndex,
            onSelected: _onSortChanged,
          ),
        ),

        // Nội dung danh sách video
        Expanded(
          child: Builder(
            builder: (context) {
              if (_isLoading) return const LoadingView();
              if (_error != null) return ErrorView(message: _error!, onRetry: () => _loadVideos(reset: true));

              if (_videos.isEmpty) {
                return EmptyView(
                  icon: Icons.play_circle_outline,
                  title: 'Kênh này chưa có video nào',
                  message: widget.channel.mine ? 'Tải video lên để chia sẻ với người xem' : null,
                  actionLabel: widget.channel.mine ? 'Tải video lên' : null,
                  onAction: widget.channel.mine ? () => context.push(AppRoutes.upload) : null,
                );
              }

              return NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                    _loadVideos(reset: false);
                  }
                  return false;
                },
                child: ListView.builder(
                  key: const PageStorageKey('channel_videos_tab_list'),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _videos.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _videos.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        ),
                      );
                    }
                    final video = _videos[index];
                    return VideoCardCompact(
                      video: video,
                      onTap: () => context.push(AppRoutes.video(video.id)),
                      onMore: () => showVideoOptionsSheet(context, video),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. TAB SHORTS
// ==========================================
class ChannelShortsTab extends StatefulWidget {
  final Channel channel;

  const ChannelShortsTab({super.key, required this.channel});

  @override
  State<ChannelShortsTab> createState() => _ChannelShortsTabState();
}

class _ChannelShortsTabState extends State<ChannelShortsTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<Video> _shorts = [];
  int _page = 0;
  bool _hasMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadShorts(reset: true);
  }

  Future<void> _loadShorts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 0;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final pageToLoad = reset ? 0 : _page + 1;
      final res = await context.read<ChannelService>().shorts(
            widget.channel.id,
            page: pageToLoad,
            size: 30,
          );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _shorts = res.items;
        } else {
          _shorts.addAll(res.items);
        }
        _page = pageToLoad;
        _hasMore = res.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (reset) _error = 'Không thể tải danh sách Shorts';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: () => _loadShorts(reset: true));

    if (_shorts.isEmpty) {
      return EmptyView(
        icon: Icons.slow_motion_video,
        title: 'Kênh này chưa có video Shorts nào',
        actionLabel: widget.channel.mine ? 'Tạo video ngắn' : null,
        onAction: widget.channel.mine ? () => context.push(AppRoutes.uploadShort()) : null,
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          _loadShorts(reset: false);
        }
        return false;
      },
      child: GridView.builder(
        key: const PageStorageKey('channel_shorts_tab_grid'),
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: _shorts.length + (_isLoadingMore ? 3 : 0),
        itemBuilder: (context, index) {
          if (index >= _shorts.length) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ),
            );
          }

          final s = _shorts[index];
          return GestureDetector(
            onTap: () => context.push(AppRoutes.shortsAt(s.id)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
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
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Fmt.views(s.viewCount),
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 4. TAB DANH SÁCH PHÁT
// ==========================================
class ChannelPlaylistsTab extends StatefulWidget {
  final Channel channel;

  const ChannelPlaylistsTab({super.key, required this.channel});

  @override
  State<ChannelPlaylistsTab> createState() => _ChannelPlaylistsTabState();
}

class _ChannelPlaylistsTabState extends State<ChannelPlaylistsTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _error;
  List<Playlist> _playlists = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await context.read<ChannelService>().playlists(widget.channel.id);
      if (!mounted) return;
      setState(() {
        _playlists = res;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách phát';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _loadPlaylists);

    if (_playlists.isEmpty) {
      return const EmptyView(
        icon: Icons.playlist_play,
        title: 'Kênh này chưa có danh sách phát nào',
      );
    }

    return ListView.builder(
      key: const PageStorageKey('channel_playlists_tab_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        return _PlaylistTile(playlist: _playlists[index]);
      },
    );
  }
}

// ==========================================
// 5. TAB GIỚI THIỆU
// ==========================================
class ChannelAboutTab extends StatelessWidget {
  final Channel channel;

  const ChannelAboutTab({super.key, required this.channel});

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day} thg ${dt.month}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final link = 'https://vtube.vn/@${channel.handle}';

    return ListView(
      key: const PageStorageKey('channel_about_tab_list'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Mô tả
        const Text(
          'Mô tả',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          (channel.description != null && channel.description!.trim().isNotEmpty)
              ? channel.description!
              : 'Kênh này chưa có nội dung giới thiệu.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        const Divider(height: 32, color: AppColors.divider),

        // Chi tiết
        const Text(
          'Thông tin chi tiết',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.link, color: AppColors.link),
          title: Text(link, style: const TextStyle(fontSize: 14, color: AppColors.link)),
          subtitle: const Text('Đường liên kết kênh'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.people_outline, color: AppColors.textSecondary),
          title: Text(Fmt.subscribers(channel.subscriberCount), style: const TextStyle(fontSize: 14)),
          subtitle: const Text('Người đăng ký'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.video_library_outlined, color: AppColors.textSecondary),
          title: Text('${channel.videoCount} video', style: const TextStyle(fontSize: 14)),
          subtitle: const Text('Số lượng video đã đăng'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.visibility_outlined, color: AppColors.textSecondary),
          title: Text(Fmt.views(channel.totalViews), style: const TextStyle(fontSize: 14)),
          subtitle: const Text('Tổng lượt xem kênh'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
          title: Text('Đã tham gia ${_formatDate(channel.createdAt)}', style: const TextStyle(fontSize: 14)),
          subtitle: const Text('Ngày thành lập'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.public, color: AppColors.textSecondary),
          title: Text('Việt Nam', style: TextStyle(fontSize: 14)),
          subtitle: Text('Quốc gia'),
        ),
        const SizedBox(height: 20),

        FilledButton.icon(
          key: const Key('channel_share_button_tab'),
          onPressed: () => Share.share('Kênh ${channel.name}: $link'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surfaceHighest,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(0, 44),
          ),
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Chia sẻ kênh'),
        ),
      ],
    );
  }
}

// Widget tile hiển thị 1 Playlist
class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;

  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.playlist(playlist.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail tỉ lệ 16:9 kèm overlay số video
            SizedBox(
              width: 130,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(url: playlist.thumbnailUrl),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 48,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.65),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.playlist_play, color: Colors.white, size: 20),
                              const SizedBox(height: 2),
                              Text(
                                '${playlist.videoCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Tên và cập nhật
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.videoCount} video · ${Fmt.timeAgo(playlist.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
