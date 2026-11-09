import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/notification_service.dart';
import '../../shared/widgets/chip_bar.dart';
import '../../shared/widgets/state_views.dart';
import 'widgets/notification_tile.dart';

/// MÀN 16 · THÔNG BÁO · Người 4
/// API: NotificationService.list(type: all | mention, page:), markRead(id), markAllRead(), delete(id)
/// Bấm thông báo -> điều hướng theo item.type (bảng trong docs/API.md mục Thông báo)
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  final _items = <NotificationItem>[];

  static const _types = ['all', 'mention'];
  static const _chipLabels = ['Tất cả', 'Lượt nhắc'];
  int _selectedChip = 0;

  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _requestId = 0;
  bool? _lastLoggedIn;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 500 && !_loading && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _refresh({bool isChipChange = false}) async {
    final reqId = ++_requestId;
    final prevItems = List<NotificationItem>.from(_items);
    final prevPage = _page;
    final prevHasMore = _hasMore;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<NotificationService>();
      final res = await service.list(type: _types[_selectedChip], page: 0, size: 20);
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
      final msg = e is ApiException ? e.message : 'Không thể tải thông báo. Vui lòng thử lại sau.';
      setState(() {
        _loading = false;
        _error = msg;
        if (isChipChange) {
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
      if (!isChipChange && prevItems.isNotEmpty) {
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
      final service = context.read<NotificationService>();
      final res = await service.list(type: _types[_selectedChip], page: nextPage, size: 20);
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
      showSnack(context, e is ApiException ? e.message : 'Không thể tải thêm thông báo');
    }
  }

  void _onChipSelected(int index) {
    if (_selectedChip == index) return;
    setState(() => _selectedChip = index);
    _refresh(isChipChange: true);
  }

  Future<void> _markAllRead() async {
    try {
      await context.read<NotificationService>().markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final item = _items[i];
          if (!item.read) {
            _items[i] = NotificationItem(
              id: item.id,
              type: item.type,
              message: item.message,
              read: true,
              createdAt: item.createdAt,
              actor: item.actor,
              videoId: item.videoId,
              videoThumbnailUrl: item.videoThumbnailUrl,
              videoDurationSeconds: item.videoDurationSeconds,
              videoShort: item.videoShort,
              commentId: item.commentId,
            );
          }
        }
      });
      showSnack(context, 'Đã đánh dấu tất cả là đã đọc');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e is ApiException ? e.message : 'Không thể cập nhật trạng thái');
    }
  }

  void _onTapNotification(NotificationItem item) {
    if (!item.read) {
      final index = _items.indexWhere((e) => e.id == item.id);
      if (index != -1) {
        setState(() {
          _items[index] = NotificationItem(
            id: item.id,
            type: item.type,
            message: item.message,
            read: true,
            createdAt: item.createdAt,
            actor: item.actor,
            videoId: item.videoId,
            videoThumbnailUrl: item.videoThumbnailUrl,
            videoDurationSeconds: item.videoDurationSeconds,
            videoShort: item.videoShort,
            commentId: item.commentId,
          );
        });
      }
      unawaited(_markReadWithRollback(item));
    }

    if (item.type == 'new_short' && item.videoId != null) {
      context.go(AppRoutes.shortsAt(item.videoId!));
    } else if (item.type == 'new_subscriber' && item.actor != null) {
      context.push(AppRoutes.channel(item.actor!.id));
    } else if (item.videoId != null) {
      context.push(AppRoutes.video(item.videoId!));
    }
  }

  Future<void> _markReadWithRollback(NotificationItem item) async {
    try {
      await context.read<NotificationService>().markRead(item.id);
    } catch (e) {
      if (!mounted) return;
      final index = _items.indexWhere((e) => e.id == item.id);
      if (index != -1) {
        setState(() {
          _items[index] = item;
        });
      }
      showSnack(context, e is ApiException ? e.message : 'Không thể cập nhật trạng thái thông báo');
    }
  }

  Future<void> _hideNotification(NotificationItem item) async {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index == -1) return;

    setState(() => _items.removeAt(index));

    try {
      await context.read<NotificationService>().delete(item.id);
      if (!mounted) return;
      showSnack(context, 'Đã ẩn thông báo');
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(index, item));
      showSnack(context, e is ApiException ? e.message : 'Không thể ẩn thông báo');
    }
  }

  void _showNotificationSettings() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cài đặt thông báo'),
        content: const Text(
          'Bạn đang nhận thông báo về video mới, bình luận, lượt thích và người đăng ký mới. Để quản lý chi tiết hoặc tắt rung/chuông, hãy kiểm tra phần cài đặt thông báo của hệ thống thiết bị.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast),
            tooltip: 'Truyền màn hình',
            onPressed: () => showSnack(context, 'Đang tìm thiết bị trên cùng mạng Wi-Fi'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Tìm kiếm',
            onPressed: () => context.push(AppRoutes.search),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn khác',
            onSelected: (val) {
              if (val == 'mark_all') {
                _markAllRead();
              } else if (val == 'settings') {
                _showNotificationSettings();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'mark_all', child: Text('Đánh dấu tất cả đã đọc')),
              const PopupMenuItem(value: 'settings', child: Text('Cài đặt thông báo')),
            ],
          ),
        ],
      ),
      body: !auth.isLoggedIn
          ? EmptyView(
              icon: Icons.notifications_none,
              title: 'Thông báo của bạn sẽ hiển thị ở đây',
              message: 'Đăng nhập để xem thông báo từ các kênh đã đăng ký và bình luận.',
              actionLabel: 'Đăng nhập',
              onAction: () => context.push(AppRoutes.loginFromDialog),
            )
          : Column(
              children: [
                ChipBar(labels: _chipLabels, selectedIndex: _selectedChip, onSelected: _onChipSelected),
                Expanded(child: _buildBody()),
              ],
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
          children: const [
            SizedBox(height: 80),
            EmptyView(
              icon: Icons.notifications_none,
              title: 'Thông báo của bạn sẽ hiển thị ở đây',
              message: 'Đăng ký kênh để nhận thông báo về video mới nhất',
            ),
          ],
        ),
      );
    }

    final unread = _items.where((e) => !e.read).toList();
    final read = _items.where((e) => e.read).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (unread.isNotEmpty) ...[
            NotificationSectionHeader(title: 'Mới', badgeCount: unread.length, onMarkAllRead: _markAllRead),
            for (final item in unread)
              NotificationTile(
                key: ValueKey('notif_${item.id}'),
                item: item,
                onTap: () => _onTapNotification(item),
                onHide: () => _hideNotification(item),
                onOpenChannel: item.actor != null ? () => context.push(AppRoutes.channel(item.actor!.id)) : null,
              ),
          ],
          if (read.isNotEmpty) ...[
            const NotificationSectionHeader(title: 'Trước đó'),
            for (final item in read)
              NotificationTile(
                key: ValueKey('notif_${item.id}'),
                item: item,
                onTap: () => _onTapNotification(item),
                onHide: () => _hideNotification(item),
                onOpenChannel: item.actor != null ? () => context.push(AppRoutes.channel(item.actor!.id)) : null,
              ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
