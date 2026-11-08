import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../app/main_shell.dart';
import '../../app/theme.dart';
import '../../core/config/api_config.dart';
import '../../data/models/models.dart';
import '../../data/services/video_service.dart';
import '../../shared/widgets/state_views.dart';
import 'comments_sheet.dart';
import 'widgets/shorts_page_item.dart';

/// MÀN 8 · SHORTS · Người 2 (tab 2)
class ShortsScreen extends StatefulWidget {
  final int? startVideoId;
  final bool isActive;

  const ShortsScreen({
    super.key,
    this.startVideoId,
    this.isActive = true,
  });

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final _shorts = <Video>[];
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _visitedIndices = {};
  final Set<int> _initializingIndices = {};

  final Map<int, int> _reactions = {};
  final Map<int, int> _likeCounts = {};
  final Map<int, bool> _subscribedChannels = {};

  int _currentPage = 0;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  bool _effectiveActive = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _loadInitialShorts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncActiveState();
  }

  @override
  void didUpdateWidget(covariant ShortsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncActiveState();
    }
  }

  void _syncActiveState() {
    final tabActive = ShortsTabScope.of(context);
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final active = widget.isActive && tabActive && routeCurrent;

    if (_effectiveActive != active) {
      _effectiveActive = active;
      if (active) {
        _playCurrent();
      } else {
        _pauseAll();
      }
    }
  }

  void _playCurrent() {
    final cur = _controllers[_currentPage];
    if (cur != null && cur.value.isInitialized) {
      cur.play();
    }
  }

  void _pauseAll() {
    for (final c in _controllers.values) {
      c.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      if (_effectiveActive) {
        _playCurrent();
      }
    }
  }

  void _disposeAllControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  Future<void> _loadInitialShorts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final videoService = context.read<VideoService>();
      final res = await videoService.shorts(page: 0, size: 10);

      if (!mounted) return;

      final items = List<Video>.from(res.items);

      // Nếu mở từ kệ Shorts bằng startVideoId
      int initialIndex = 0;
      if (widget.startVideoId != null) {
        final existingIdx = items.indexWhere((s) => s.id == widget.startVideoId);
        if (existingIdx != -1) {
          initialIndex = existingIdx;
        } else {
          try {
            final startVideo = await videoService.detail(widget.startVideoId!);
            items.insert(0, startVideo);
            initialIndex = 0;
          } catch (_) {
            // Không tìm thấy video chi tiết thì vẫn phát danh sách mặc định
          }
        }
      }

      setState(() {
        _shorts.addAll(items);
        _hasMore = res.hasMore;
        _page = 1;
        _currentPage = initialIndex;
        _loading = false;
      });

      _pageController.dispose();
      _pageController = PageController(initialPage: initialIndex);

      // Khởi tạo controller cho video hiện tại và preload video kế tiếp
      _initAndPlayController(initialIndex);
      if (initialIndex + 1 < _shorts.length) {
        _initController(initialIndex + 1);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải Shorts. Vui lòng thử lại';
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreShorts() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;

    try {
      final res = await context.read<VideoService>().shorts(page: _page, size: 10);
      if (!mounted) return;

      setState(() {
        _shorts.addAll(res.items);
        _hasMore = res.hasMore;
        _page++;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _initController(int index) async {
    if (index < 0 || index >= _shorts.length) return;
    if (_controllers.containsKey(index)) return;
    if (_initializingIndices.contains(index)) return;

    _initializingIndices.add(index);
    final short = _shorts[index];
    final resolvedUrl = ApiConfig.resolveUrl(short.videoUrl);
    if (resolvedUrl == null) {
      _initializingIndices.remove(index);
      if (index == _currentPage && mounted) {
        _skipToNextShort(index);
      }
      return;
    }

    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
      await controller.initialize();
      await controller.setLooping(true);

      _initializingIndices.remove(index);

      if (!mounted) {
        controller.dispose();
        return;
      }

      // Hủy ngay nếu người dùng đã lướt đi xa quá 1 trang
      if ((index - _currentPage).abs() > 1) {
        controller.dispose();
        return;
      }

      _controllers[index]?.dispose();
      setState(() {
        _controllers[index] = controller!;
      });
    } catch (_) {
      _initializingIndices.remove(index);
      controller?.dispose();
      if (index == _currentPage && mounted) {
        _skipToNextShort(index);
      }
    }
  }

  void _skipToNextShort(int failedIndex) {
    if (!mounted || failedIndex != _currentPage) return;
    if (failedIndex + 1 < _shorts.length && _pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _initAndPlayController(int index) async {
    if (!_controllers.containsKey(index)) {
      await _initController(index);
    }

    if (!mounted) return;
    // Bắt buộc kiểm tra index vẫn là trang hiện tại để chống phát đè âm thanh
    if (index != _currentPage) return;

    final controller = _controllers[index];
    if (controller != null && controller.value.isInitialized) {
      if (_effectiveActive) {
        controller.play();
      }

      // Tăng view đúng 1 lần khi bắt đầu xem
      if (_visitedIndices.add(index)) {
        try {
          context.read<VideoService>().addView(_shorts[index].id);
        } catch (_) {}
      }
    }
  }

  void _onPageChanged(int index) {
    // 1. Tạm dừng video cũ
    _controllers[_currentPage]?.pause();

    _currentPage = index;

    // 2. Phát video mới
    _initAndPlayController(index);

    // 3. Preload video kế tiếp
    if (index + 1 < _shorts.length) {
      _initController(index + 1);
    }

    // 4. Giải phóng controller cách xa quá 1 trang (đảm bảo chống tràn RAM)
    final keysToRemove = <int>[];
    for (final pageIdx in _controllers.keys) {
      if ((pageIdx - index).abs() > 1) {
        keysToRemove.add(pageIdx);
      }
    }

    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }

    // 5. Tải thêm khi còn 3 video chưa xem
    if (index >= _shorts.length - 3) {
      _loadMoreShorts();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _shorts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_error != null && _shorts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: ErrorView(
          message: _error!,
          onRetry: _loadInitialShorts,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final short = _shorts[index];
          final controller = _controllers[index];
          final myReaction = _reactions[short.id] ?? short.viewer?.myReaction ?? 0;
          final likeCount = _likeCounts[short.id] ?? short.likeCount;
          final isSubscribed = _subscribedChannels[short.channel.id] ?? short.viewer?.subscribed ?? false;

          return ShortsPageItem(
            key: ValueKey('short-${short.id}'),
            short: short,
            controller: controller,
            isCurrent: index == _currentPage,
            initialReaction: myReaction,
            initialLikeCount: likeCount,
            initialSubscribed: isSubscribed,
            onReactionChanged: (reaction, likes) {
              _reactions[short.id] = reaction;
              _likeCounts[short.id] = likes;
            },
            onSubscribedChanged: (subscribed) {
              _subscribedChannels[short.channel.id] = subscribed;
            },
            onOpenComments: () => showCommentsSheet(
              context,
              short.id,
              channelId: short.channel.id,
              commentsEnabled: short.commentsEnabled,
              totalCommentCount: short.commentCount,
            ),
          );
        },
      ),
    );
  }
}
