import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/search_service.dart';
import '../../shared/widgets/app_network_image.dart';
import '../../shared/widgets/chip_bar.dart';
import '../../shared/widgets/shorts_shelf.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/video_card_compact.dart';
import '../../shared/widgets/video_options_sheet.dart';
import 'widgets/channel_search_card.dart';
import 'widgets/playlist_search_card.dart';
import 'widgets/search_filter_sheet.dart';

/// MÀN 10 · KẾT QUẢ TÌM KIẾM · Người 3 (Hiếu)
///
/// Các tính năng:
/// - AppBar: ô hiển thị query (bấm quay lại Màn 9 sửa từ khóa), nút micro, nút bộ lọc (chấm đỏ khi khác mặc định).
/// - ChipBar loại nội dung: Tất cả, Video, Shorts, Kênh, Danh sách phát, Chưa xem.
/// - Kết quả đa dạng: Thẻ kênh nổi bật ở đầu, VideoCardCompact, kệ ShortsShelf chèn sau ~4 video, thẻ Playlist.
/// - Bottom sheet bộ lọc 4 nhóm: Ngày tải lên, Loại, Thời lượng, Sắp xếp theo, nút Đặt lại và Áp dụng.
/// - Đầy đủ 3 trạng thái: Đang tải, Trống (gợi ý bỏ bộ lọc), Lỗi (có nút Thử lại).
/// - Cuộn vô hạn theo `hasMore` và kéo xuống để làm mới.
class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  static const _chipLabels = ['Tất cả', 'Video', 'Shorts', 'Kênh', 'Danh sách phát', 'Chưa xem'];
  static const _chipTypes = ['all', 'video', 'short', 'channel', 'playlist', 'unwatched'];

  final _scroll = ScrollController();

  SearchFilters _filters = const SearchFilters();
  int _selectedChipIndex = 0;

  final List<Channel> _channels = [];
  final List<Video> _videos = [];
  final List<Video> _shorts = [];
  final List<Playlist> _playlists = [];

  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void didUpdateWidget(SearchResultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    final reqId = ++_reqId;
    if (!silent) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _page = 0;
        _channels.clear();
        _videos.clear();
        _shorts.clear();
        _playlists.clear();
      });
    } else {
      _loadingMore = false;
    }

    try {
      final res = await context.read<SearchService>().search(
            widget.query,
            filters: _filters,
            page: 0,
          );
      if (!mounted || reqId != _reqId) return;
      setState(() {
        if (silent) {
          _channels.clear();
          _videos.clear();
          _shorts.clear();
          _playlists.clear();
        }
        _channels.addAll(res.channels);
        _videos.addAll(res.videos);
        _shorts.addAll(res.shorts);
        _playlists.addAll(res.playlists);
        _page = res.page;
        _hasMore = res.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || reqId != _reqId) return;
      setState(() {
        if (!silent) _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
      if (silent) showSnack(context, e.message);
    } catch (_) {
      if (!mounted || reqId != _reqId) return;
      setState(() {
        if (!silent) _error = 'Không thể tải kết quả tìm kiếm. Vui lòng thử lại.';
        _loading = false;
        _loadingMore = false;
      });
      if (silent) showSnack(context, 'Không thể tải kết quả tìm kiếm. Vui lòng thử lại.');
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final reqId = _reqId;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;
      final res = await context.read<SearchService>().search(
            widget.query,
            filters: _filters,
            page: nextPage,
          );
      if (!mounted || reqId != _reqId) return;
      setState(() {
        if (_filters.type == 'channel') {
          _channels.addAll(res.channels);
        } else if (_filters.type == 'playlist') {
          _playlists.addAll(res.playlists);
        } else if (_filters.type == 'short') {
          _shorts.addAll(res.shorts);
        } else {
          _videos.addAll(res.videos);
        }
        _page = res.page;
        _hasMore = res.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || reqId != _reqId) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
      showSnack(context, 'Không thể tải thêm kết quả tìm kiếm');
    }
  }

  void _onChipSelected(int index) {
    if (_selectedChipIndex == index) return;
    final newType = _chipTypes[index];
    setState(() {
      _selectedChipIndex = index;
      _filters = _filters.copyWith(type: newType);
    });
    _refresh();
  }

  void _onApplyFilters(SearchFilters newFilters) {
    setState(() {
      _filters = newFilters;
      final typeIndex = _chipTypes.indexOf(newFilters.type);
      _selectedChipIndex = typeIndex != -1 ? typeIndex : 0;
    });
    _refresh();
  }

  void _resetFilters() {
    setState(() {
      _filters = const SearchFilters();
      _selectedChipIndex = 0;
    });
    _refresh();
  }

  bool get _isResultsEmpty => _channels.isEmpty && _videos.isEmpty && _shorts.isEmpty && _playlists.isEmpty;

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = !_filters.isDefault;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: InkWell(
          key: const Key('search_bar_query_tap'),
          onTap: () {
            context.pushReplacement('/search?q=${Uri.encodeQueryComponent(widget.query)}');
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 40,
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('search_results_mic_button'),
            icon: const Icon(Icons.mic, size: 22, color: AppColors.textPrimary),
            tooltip: 'Tìm kiếm bằng giọng nói',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng tìm kiếm bằng giọng nói đang được phát triển.')),
              );
            },
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                key: const Key('search_filter_button'),
                icon: const Icon(Icons.tune, size: 22, color: AppColors.textPrimary),
                tooltip: 'Bộ lọc',
                onPressed: () {
                  showSearchFilterSheet(
                    context,
                    currentFilters: _filters,
                    onApply: _onApplyFilters,
                  );
                },
              ),
              if (hasActiveFilter)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    key: const Key('filter_active_dot'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Thanh chọn loại nội dung ChipBar
          ChipBar(
            labels: _chipLabels,
            selectedIndex: _selectedChipIndex,
            onSelected: _onChipSelected,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _isResultsEmpty) {
      return const LoadingView();
    }

    if (_error != null && _isResultsEmpty) {
      return ErrorView(message: _error!, onRetry: _refresh);
    }

    if (_isResultsEmpty) {
      return EmptyView(
        icon: Icons.search_off,
        title: 'Không tìm thấy kết quả nào cho "${widget.query}"',
        message: 'Hãy thử từ khóa khác hoặc bỏ bộ lọc',
        actionLabel: !_filters.isDefault ? 'Xóa bộ lọc' : null,
        onAction: !_filters.isDefault ? _resetFilters : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(silent: true),
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceContainer,
      child: ListView(
        key: const Key('search_results_list_view'),
        controller: _scroll,
        children: [
          // 1. Nếu xem "Tất cả": Kênh trên cùng -> Video xen kẽ Shorts -> Playlist
          if (_filters.type == 'all') ...[
            for (final ch in _channels)
              ChannelSearchCard(
                key: Key('channel_card_${ch.id}'),
                channel: ch,
                onTap: () => context.push(AppRoutes.channel(ch.id)),
              ),
            ..._buildAllTypeVideosAndShorts(),
            for (final p in _playlists)
              PlaylistSearchCard(
                key: Key('playlist_card_${p.id}'),
                playlist: p,
                onTap: () => context.push(AppRoutes.playlist(p.id)),
              ),
          ]

          // 2. Nếu xem riêng "Kênh"
          else if (_filters.type == 'channel') ...[
            for (final ch in _channels)
              ChannelSearchCard(
                key: Key('channel_card_${ch.id}'),
                channel: ch,
                onTap: () => context.push(AppRoutes.channel(ch.id)),
              ),
          ]

          // 3. Nếu xem riêng "Shorts"
          else if (_filters.type == 'short') ...[
            _buildShortsGrid(),
          ]

          // 4. Nếu xem riêng "Danh sách phát"
          else if (_filters.type == 'playlist') ...[
            for (final p in _playlists)
              PlaylistSearchCard(
                key: Key('playlist_card_${p.id}'),
                playlist: p,
                onTap: () => context.push(AppRoutes.playlist(p.id)),
              ),
          ]

          // 5. Nếu xem "Video" hoặc "Chưa xem"
          else ...[
            for (final v in _videos)
              VideoCardCompact(
                key: Key('video_card_${v.id}'),
                video: v,
                onTap: () => context.push(AppRoutes.video(v.id)),
                onMore: () => showVideoOptionsSheet(
                  context,
                  v,
                  onHidden: () => setState(() => _videos.remove(v)),
                ),
              ),
          ],

          // Vòng quay tải thêm trang tiếp
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Khi type == 'all': Chèn ShortsShelf sau khoảng 4 video đầu tiên
  List<Widget> _buildAllTypeVideosAndShorts() {
    final items = <Widget>[];
    const shortsInsertIndex = 4;
    var shortsInserted = false;

    for (var i = 0; i < _videos.length; i++) {
      if (i == shortsInsertIndex && _shorts.isNotEmpty) {
        items.add(ShortsShelf(
          key: const Key('search_shorts_shelf'),
          shorts: _shorts,
          onTap: (s) => context.push(AppRoutes.shortsAt(s.id)),
        ));
        shortsInserted = true;
      }

      final v = _videos[i];
      items.add(VideoCardCompact(
        key: Key('video_card_${v.id}'),
        video: v,
        onTap: () => context.push(AppRoutes.video(v.id)),
        onMore: () => showVideoOptionsSheet(
          context,
          v,
          onHidden: () => setState(() => _videos.remove(v)),
        ),
      ));
    }

    if (!shortsInserted && _shorts.isNotEmpty) {
      items.add(ShortsShelf(
        key: const Key('search_shorts_shelf'),
        shorts: _shorts,
        onTap: (s) => context.push(AppRoutes.shortsAt(s.id)),
      ));
    }

    return items;
  }

  /// Lưới Shorts khi lọc tab Shorts riêng
  Widget _buildShortsGrid() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _shorts.length,
        itemBuilder: (context, i) {
          final s = _shorts[i];
          return GestureDetector(
            key: Key('short_grid_item_${s.id}'),
            onTap: () => context.push(AppRoutes.shortsAt(s.id)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Fmt.views(s.viewCount),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
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
