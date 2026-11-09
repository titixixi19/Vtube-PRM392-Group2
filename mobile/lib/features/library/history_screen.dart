import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/history_service.dart';
import '../../shared/widgets/chip_bar.dart';
import '../../shared/widgets/save_to_playlist_sheet.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/video_card_compact.dart';
import 'widgets/history_group_section.dart';

/// MÀN 13 · LỊCH SỬ XEM · Người 4
/// API: HistoryService.list(type:, q:, page:), delete(videoId), clear()
///      AuthService.setHistoryPaused(true/false) rồi AuthProvider.refreshMe()
/// Nhóm theo ngày từ item.watchedAt (Hôm nay, Hôm qua, Tuần này, ...); thanh đỏ = item.progress
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  final _items = <HistoryItem>[];
  static const _types = ['all', 'video', 'short', 'music'];
  static const _chipLabels = ['Tất cả', 'Video', 'Shorts', 'Nhạc'];
  int _selectedType = 0;

  bool _searching = false;
  String _query = '';
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _requestId = 0;
  bool? _lastLoggedIn;
  ScaffoldMessengerState? _scaffoldMessenger;

  final _pendingDeletes = <int, Future<void> Function({bool rollback})>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (_lastLoggedIn != loggedIn) {
      _lastLoggedIn = loggedIn;
      if (loggedIn) {
        _refresh();
      } else {
        _items.clear();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    for (final action in _pendingDeletes.values) {
      action(rollback: false);
    }
    _pendingDeletes.clear();
    _scaffoldMessenger?.hideCurrentSnackBar();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 500 && !_loading && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _refresh({bool isFilterChange = false}) async {
    final reqId = ++_requestId;
    if (_pendingDeletes.isNotEmpty) {
      final pendingActions = _pendingDeletes.values.toList();
      _pendingDeletes.clear();
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      await Future.wait(pendingActions.map((action) => action(rollback: false)));
      if (!mounted || reqId != _requestId) return;
    }
    final prevItems = List<HistoryItem>.from(_items);
    final prevPage = _page;
    final prevHasMore = _hasMore;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<HistoryService>();
      final q = _query.trim().isEmpty ? null : _query.trim();
      final res = await service.list(
        type: _types[_selectedType],
        q: q,
        page: 0,
        size: 20,
      );
      if (!mounted || reqId != _requestId) return;
      setState(() {
        _items.clear();
        _items.addAll(res.items);
        _hasMore = res.hasMore;
        _page = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || reqId != _requestId) return;
      final msg = e is ApiException ? e.message : 'Không thể tải lịch sử xem. Vui lòng thử lại sau.';
      setState(() {
        _loading = false;
        _error = msg;
        if (isFilterChange) {
          _items.clear();
          _page = 0;
          _hasMore = false;
        } else {
          _items.clear();
          _items.addAll(prevItems);
          _page = prevPage;
          _hasMore = prevHasMore;
        }
      });
      if (!isFilterChange && prevItems.isNotEmpty) {
        showSnack(context, msg);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final reqId = _requestId;
    setState(() => _loading = true);

    try {
      final nextPage = _page + 1;
      final service = context.read<HistoryService>();
      final q = _query.trim().isEmpty ? null : _query.trim();
      final res = await service.list(
        type: _types[_selectedType],
        q: q,
        page: nextPage,
        size: 20,
      );
      if (!mounted || reqId != _requestId) return;
      setState(() {
        _items.addAll(res.items);
        _page = nextPage;
        _hasMore = res.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || reqId != _requestId) return;
      setState(() {
        _loading = false;
        _hasMore = false;
      });
      showSnack(context, e is ApiException ? e.message : 'Không thể tải thêm nhật ký xem');
    }
  }

  void _onTypeSelected(int index) {
    if (_selectedType == index) return;
    setState(() => _selectedType = index);
    _refresh(isFilterChange: true);
  }

  void _openSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
    _refresh(isFilterChange: true);
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = val);
      _refresh(isFilterChange: true);
    });
  }

  Future<void> _deleteHistoryItem(HistoryItem item) async {
    final index = _items.indexOf(item);
    if (index == -1) return;

    setState(() => _items.removeAt(index));

    final historyService = context.read<HistoryService>();
    final messenger = ScaffoldMessenger.of(context);
    bool undone = false;

    Future<void> performDelete({bool rollback = true}) async {
      try {
        await historyService.delete(item.video.id);
      } catch (e) {
        if (mounted && rollback) {
          setState(() {
            final safeIndex = index.clamp(0, _items.length);
            _items.insert(safeIndex, item);
          });
          showSnack(context, e is ApiException ? e.message : 'Không thể xóa video khỏi nhật ký xem');
        }
      }
    }

    _pendingDeletes[item.video.id] = performDelete;

    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: const Text('Đã xóa khỏi nhật ký xem'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          textColor: AppColors.link,
          onPressed: () {
            undone = true;
            _pendingDeletes.remove(item.video.id);
            if (!mounted) return;
            setState(() {
              final safeIndex = index.clamp(0, _items.length);
              _items.insert(safeIndex, item);
            });
          },
        ),
      ),
    );

    controller.closed.then((reason) async {
      if (undone || reason == SnackBarClosedReason.action) {
        _pendingDeletes.remove(item.video.id);
        return;
      }
      final action = _pendingDeletes.remove(item.video.id);
      if (action != null) {
        await action(rollback: true);
      }
    });
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ nhật ký xem?'),
        content: const Text('Nhật ký xem trên tất cả thiết bị của bạn sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa nhật ký xem'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (_pendingDeletes.isNotEmpty) {
      _pendingDeletes.clear();
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    }

    try {
      await context.read<HistoryService>().clear();
      if (!mounted) return;
      setState(() => _items.clear());
      showSnack(context, 'Đã xóa toàn bộ nhật ký xem');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e is ApiException ? e.message : 'Không thể xóa nhật ký xem');
    }
  }

  Future<void> _togglePauseHistory(bool pause) async {
    try {
      await context.read<AuthService>().setHistoryPaused(pause);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshMe();
      if (!mounted) return;
      showSnack(context, pause ? 'Đã tạm dừng nhật ký xem' : 'Đã bật lại nhật ký xem');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e is ApiException ? e.message : 'Không thể cập nhật cài đặt');
    }
  }

  void _openItem(HistoryItem item) {
    if (item.video.isShort) {
      context.go(AppRoutes.shortsAt(item.video.id));
    } else {
      context.push(AppRoutes.video(item.video.id));
    }
  }

  void _showHistoryItemSheet(HistoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Xóa khỏi nhật ký xem'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteHistoryItem(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Lưu vào danh sách phát'),
              onTap: () {
                Navigator.pop(ctx);
                showSaveToPlaylistSheet(context, item.video.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Chia sẻ'),
              onTap: () {
                Navigator.pop(ctx);
                final shareUrl = ApiConfig.resolveUrl('/watch?v=${item.video.id}');
                Share.share('${item.video.title} - $shareUrl');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPaused = auth.user?.historyPaused == true;

    return Scaffold(
      appBar: _searching ? _buildSearchAppBar() : _buildNormalAppBar(isPaused),
      body: !auth.isLoggedIn
          ? EmptyView(
              icon: Icons.history,
              title: 'Nhật ký xem của bạn sẽ xuất hiện tại đây',
              message: 'Đăng nhập để xem lại các video bạn đã xem.',
              actionLabel: 'Đăng nhập',
              onAction: () => context.push(AppRoutes.loginFromDialog),
            )
          : Column(
              children: [
                ChipBar(
                  labels: _chipLabels,
                  selectedIndex: _selectedType,
                  onSelected: _onTypeSelected,
                ),
                if (isPaused) HistoryPausedBanner(onResume: () => _togglePauseHistory(false)),
                Expanded(child: _buildBody()),
              ],
            ),
    );
  }

  AppBar _buildNormalAppBar(bool isPaused) {
    return AppBar(
      title: const Text('Nhật ký xem'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Tìm trong nhật ký',
          onPressed: _openSearch,
        ),
        IconButton(
          icon: const Icon(Icons.cast),
          tooltip: 'Truyền màn hình',
          onPressed: () => showSnack(context, 'Đang tìm thiết bị trên cùng mạng Wi-Fi'),
        ),
        PopupMenuButton<String>(
          tooltip: 'Tùy chọn khác',
          onSelected: (val) {
            if (val == 'toggle_pause') {
              _togglePauseHistory(!isPaused);
            } else if (val == 'clear_all') {
              _confirmClearAll();
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'toggle_pause',
              child: Text(isPaused ? 'Bật lại nhật ký xem' : 'Tạm dừng nhật ký xem'),
            ),
            const PopupMenuItem(
              value: 'clear_all',
              child: Text('Xóa toàn bộ nhật ký xem', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: true,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Tìm trong nhật ký xem...',
          border: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: _refresh);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            EmptyView(
              icon: Icons.history,
              title: _query.isNotEmpty ? 'Không tìm thấy kết quả phù hợp' : 'Chưa có video nào trong nhật ký xem',
              message: _query.isNotEmpty ? 'Hãy thử tìm kiếm với từ khóa khác' : 'Các video bạn xem sẽ hiển thị ở đây',
            ),
          ],
        ),
      );
    }

    final groups = groupHistoryItems(_items);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _calculateTotalRows(groups) + 1, // +1 cho nút xóa toàn bộ hoặc loading indicator
        itemBuilder: (context, index) {
          final totalContentRows = _calculateTotalRows(groups);
          if (index == totalContentRows) {
            return _buildFooter();
          }

          var cursor = 0;
          for (final g in groups) {
            if (index == cursor) {
              return HistoryGroupHeader(title: g.label, count: g.items.length);
            }
            cursor++;
            final itemIndex = index - cursor;
            if (itemIndex < g.items.length) {
              final item = g.items[itemIndex];
              return Dismissible(
                key: ValueKey('history_${item.video.id}_${item.watchedAt}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.accent,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                onDismissed: (_) => _deleteHistoryItem(item),
                child: VideoCardCompact(
                  video: item.video,
                  progress: item.progress,
                  onTap: () => _openItem(item),
                  onMore: () => _showHistoryItemSheet(item),
                ),
              );
            }
            cursor += g.items.length;
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  int _calculateTotalRows(List<HistoryDateGroup> groups) {
    var count = 0;
    for (final g in groups) {
      count += 1 + g.items.length; // 1 header + items
    }
    return count;
  }

  Widget _buildFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.delete_sweep, color: AppColors.error, size: 20),
          label: const Text(
            'Xóa toàn bộ nhật ký xem',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.divider),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: _confirmClearAll,
        ),
      ),
    );
  }
}
