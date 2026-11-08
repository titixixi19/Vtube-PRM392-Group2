import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/video_service.dart';
import '../../shared/widgets/shorts_shelf.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/top_bar.dart';
import '../../shared/widgets/video_card_large.dart';
import '../../shared/widgets/video_options_sheet.dart';
import 'widgets/home_category_bar.dart';

/// MÀN 5 · TRANG CHỦ · Người 2 (tab 1)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  List<CategoryChipItem> _categories = const [
    CategoryChipItem(label: 'Tất cả', slug: null),
  ];
  int _selectedCategoryIndex = 0;
  int _reqId = 0;

  final _videos = <Video>[];
  final _shorts = <Video>[];
  final _hiddenVideoIds = <int>{};

  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _errorMore;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _refresh();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Còn cách đáy ~500px thì tải trang tiếp
    if (_scrollController.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final apiCategories = await context.read<VideoService>().categories();
      if (!mounted) return;

      final items = <CategoryChipItem>[
        const CategoryChipItem(label: 'Tất cả', slug: null),
        ...apiCategories.map((c) => CategoryChipItem(label: c.name, slug: c.slug)),
        const CategoryChipItem(label: 'Trực tiếp', slug: 'live'),
        const CategoryChipItem(label: 'Mới tải lên', slug: 'recent'),
      ];

      setState(() => _categories = items);
    } catch (_) {
      // Giữ danh mục cơ bản nếu backend chưa trả về
    }
  }

  String? get _currentCategorySlug => _categories.isEmpty ? null : _categories[_selectedCategoryIndex].slug;

  Future<void> _refresh() async {
    final curReq = ++_reqId;

    setState(() {
      _videos.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _errorMore = null;
      _loading = true;
      _loadingMore = false;
    });

    final videoService = context.read<VideoService>();

    // Tải song song Shorts và Feed; Shorts lỗi tách riêng không làm hỏng cả Trang chủ
    try {
      final feedFuture = videoService.feed(category: _currentCategorySlug, page: 0);
      final shortsFuture = videoService.shorts(size: 10).catchError((_) => const PageResult<Video>(
            items: [],
            page: 0,
            size: 10,
            hasMore: false,
          ));

      final feedRes = await feedFuture;
      final shortsRes = await shortsFuture;

      if (!mounted || curReq != _reqId) return;

      setState(() {
        _videos.addAll(feedRes.items);
        _shorts
          ..clear()
          ..addAll(shortsRes.items);
        _hasMore = feedRes.hasMore;
        _page = 1;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || curReq != _reqId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || curReq != _reqId) return;
      setState(() {
        _error = 'Không thể kết nối đến máy chủ';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final curReq = _reqId;

    setState(() {
      _loadingMore = true;
      _errorMore = null;
    });

    try {
      final feedRes = await context.read<VideoService>().feed(
            category: _currentCategorySlug,
            page: _page,
          );

      if (!mounted || curReq != _reqId) return;

      setState(() {
        _videos.addAll(feedRes.items);
        _hasMore = feedRes.hasMore;
        _page++;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || curReq != _reqId) return;
      setState(() {
        _errorMore = e.message;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || curReq != _reqId) return;
      setState(() {
        _errorMore = 'Lỗi tải thêm';
        _loadingMore = false;
      });
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onCategorySelected(int index) {
    if (_selectedCategoryIndex == index && !_loading) return;
    setState(() => _selectedCategoryIndex = index);
    _scrollToTop();
    _refresh();
  }

  void _onHideVideo(int videoId) {
    if (!mounted) return;
    setState(() => _hiddenVideoIds.add(videoId));
  }

  Widget _buildBody() {
    if (_loading && _videos.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: LoadingView(),
      );
    }

    if (_error != null && _videos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(message: _error!, onRetry: _refresh),
      );
    }

    final visibleVideos = _videos.where((v) => !_hiddenVideoIds.contains(v.id)).toList();

    if (visibleVideos.isEmpty && !_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyView(
          icon: Icons.video_library_outlined,
          title: 'Chưa có video nào trong mục này',
        ),
      );
    }

    final bool showShorts = _shorts.isNotEmpty && visibleVideos.length >= 3;
    final int contentCount = visibleVideos.length + (showShorts ? 1 : 0);
    final int totalCount = contentCount + (_hasMore ? 1 : 0);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Vị trí footer phân trang
          if (index == contentCount) {
            if (_errorMore != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: LoadingView(),
            );
          }

          // Chèn kệ Shorts sau video thứ 3 (index = 3)
          if (showShorts && index == 3) {
            return ShortsShelf(
              shorts: _shorts,
              onTap: (short) => context.go(AppRoutes.shortsAt(short.id)),
            );
          }

          final videoIndex = (showShorts && index > 3) ? index - 1 : index;
          final video = visibleVideos[videoIndex];

          return VideoCardLarge(
            video: video,
            onTap: () => context.push(AppRoutes.video(video.id)),
            onChannelTap: () => context.push(AppRoutes.channel(video.channel.id)),
            onMore: () => showVideoOptionsSheet(context, video, onHidden: () => _onHideVideo(video.id)),
          );
        },
        childCount: totalCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              title: GestureDetector(
                onTap: _scrollToTop,
                child: const VtubeLogo(),
              ),
              actions: topBarActions(context),
              bottom: HomeCategoryBar(
                categories: _categories,
                selectedIndex: _selectedCategoryIndex,
                onSelected: _onCategorySelected,
              ),
            ),
            _buildBody(),
          ],
        ),
      ),
    );
  }
}
