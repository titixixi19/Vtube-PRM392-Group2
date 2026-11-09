import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/require_login.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/playlist_service.dart';
import '../../shared/widgets/save_to_playlist_sheet.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/video_card_compact.dart';
import 'widgets/playlist_edit_dialog.dart';
import 'widgets/playlist_header.dart';

/// MÀN 14 · CHI TIẾT PLAYLIST · Người 4
/// API: PlaylistService.detail(id, sort:), update, delete, removeVideo, reorder
/// Kéo thả: ReorderableListView (chỉ khi detail.mine và sort = manual)
/// Phát tất cả: context.push(AppRoutes.video(items.first.video.id))
class PlaylistScreen extends StatefulWidget {
  final int playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  PlaylistDetail? _detail;
  List<PlaylistItem> _items = [];
  String _sort = 'manual';
  bool _loading = true;
  String? _error;
  bool _isForbidden = false;
  int _requestId = 0;
  ScaffoldMessengerState? _scaffoldMessenger;
  final _pendingRemoves = <int, Future<void> Function({bool rollback})>{};

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    for (final action in _pendingRemoves.values) {
      action(rollback: false);
    }
    _pendingRemoves.clear();
    _scaffoldMessenger?.hideCurrentSnackBar();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final reqId = ++_requestId;
    if (_pendingRemoves.isNotEmpty) {
      final pendingActions = _pendingRemoves.values.toList();
      _pendingRemoves.clear();
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      await Future.wait(pendingActions.map((action) => action(rollback: false)));
      if (!mounted || reqId != _requestId) return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _isForbidden = false;
    });

    try {
      final res = await context.read<PlaylistService>().detail(widget.playlistId, sort: _sort);
      if (!mounted || reqId != _requestId) return;
      setState(() {
        _detail = res;
        _items = List.of(res.items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || reqId != _requestId) return;
      if (e is ApiException && (e.statusCode == 403 || e.isUnauthorized)) {
        setState(() {
          _isForbidden = true;
          _loading = false;
        });
      } else {
        setState(() {
          _error = e is ApiException ? e.message : 'Không thể tải playlist. Vui lòng thử lại sau.';
          _loading = false;
        });
      }
    }
  }

  void _onSortChanged(String newSort) {
    if (_sort == newSort) return;
    setState(() => _sort = newSort);
    _loadDetail();
  }

  void _playAll() {
    if (_items.isEmpty) return;
    context.push(AppRoutes.video(_items.first.video.id));
  }

  void _shuffle() {
    if (_items.isEmpty) return;
    final random = Random().nextInt(_items.length);
    context.push(AppRoutes.video(_items[random].video.id));
  }

  Future<void> _editPlaylist() async {
    if (_detail == null) return;
    final updated = await PlaylistEditDialog.show(context, _detail!.playlist);
    if (updated != null && mounted) {
      setState(() {
        _detail = PlaylistDetail(
          playlist: updated,
          mine: _detail!.mine,
          totalViews: _detail!.totalViews,
          items: _detail!.items,
        );
      });
      showSnack(context, 'Đã cập nhật danh sách phát');
    }
  }

  Future<void> _confirmDeletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa danh sách phát?'),
        content: Text('Bạn có chắc chắn muốn xóa danh sách phát "${_detail?.playlist.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (_pendingRemoves.isNotEmpty) {
      _pendingRemoves.clear();
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    }

    try {
      await context.read<PlaylistService>().delete(widget.playlistId);
      if (!mounted) return;
      showSnack(context, 'Đã xóa danh sách phát');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e is ApiException ? e.message : 'Không thể xóa danh sách phát');
    }
  }

  Future<void> _removeItem(int index) async {
    final removed = _items[index];
    setState(() => _items.removeAt(index));

    final playlistService = context.read<PlaylistService>();
    final messenger = ScaffoldMessenger.of(context);
    bool undone = false;

    Future<void> performRemove({bool rollback = true}) async {
      try {
        await playlistService.removeVideo(widget.playlistId, removed.video.id);
      } catch (e) {
        if (mounted && rollback) {
          setState(() {
            final safeIndex = index.clamp(0, _items.length);
            _items.insert(safeIndex, removed);
          });
          showSnack(context, e is ApiException ? e.message : 'Không thể xóa khỏi danh sách phát');
        }
      }
    }

    _pendingRemoves[removed.video.id] = performRemove;

    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: const Text('Đã xóa khỏi danh sách phát'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          textColor: AppColors.link,
          onPressed: () {
            undone = true;
            _pendingRemoves.remove(removed.video.id);
            if (!mounted) return;
            setState(() {
              final safeIndex = index.clamp(0, _items.length);
              _items.insert(safeIndex, removed);
            });
          },
        ),
      ),
    );

    controller.closed.then((reason) async {
      if (undone || reason == SnackBarClosedReason.action) {
        _pendingRemoves.remove(removed.video.id);
        return;
      }
      final action = _pendingRemoves.remove(removed.video.id);
      if (action != null) {
        await action(rollback: true);
      }
    });
  }

  Future<void> _flushPendingRemoves() async {
    if (_pendingRemoves.isNotEmpty) {
      final pendingActions = _pendingRemoves.values.toList();
      _pendingRemoves.clear();
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      await Future.wait(pendingActions.map((action) => action(rollback: false)));
    }
  }

  Future<void> _moveItemTo(int fromIndex, int toIndex) async {
    setState(() {
      final item = _items.removeAt(fromIndex);
      _items.insert(toIndex, item);
    });

    try {
      await _flushPendingRemoves();
      if (!mounted) return;
      await context.read<PlaylistService>().reorder(
            widget.playlistId,
            _items.map((e) => e.video.id).toList(),
          );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Không thể cập nhật thứ tự video');
      _loadDetail();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });

    try {
      await _flushPendingRemoves();
      if (!mounted) return;
      await context.read<PlaylistService>().reorder(
            widget.playlistId,
            _items.map((e) => e.video.id).toList(),
          );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Không thể cập nhật thứ tự');
      _loadDetail();
    }
  }

  void _showItemOptions(int index) {
    final item = _items[index];
    final isMine = _detail?.mine == true;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Xóa khỏi danh sách phát'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeItem(index);
                },
              ),
              if (index > 0)
                ListTile(
                  leading: const Icon(Icons.vertical_align_top),
                  title: const Text('Chuyển lên đầu'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveItemTo(index, 0);
                  },
                ),
              if (index < _items.length - 1)
                ListTile(
                  leading: const Icon(Icons.vertical_align_bottom),
                  title: const Text('Chuyển xuống cuối'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveItemTo(index, _items.length - 1);
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Lưu vào danh sách phát khác'),
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
    if (_isForbidden) {
      return Scaffold(
        appBar: AppBar(title: const Text('Danh sách phát')),
        body: const EmptyView(
          icon: Icons.lock_outline,
          title: 'Danh sách phát này là riêng tư',
          message: 'Bạn không có quyền truy cập danh sách phát này.',
        ),
      );
    }

    final isMine = _detail?.mine == true;
    final isCustom = _detail?.playlist.isSystem == false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.playlist.title ?? 'Chi tiết playlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Tìm kiếm',
            onPressed: () => context.push(AppRoutes.search),
          ),
          IconButton(
            icon: const Icon(Icons.cast),
            tooltip: 'Truyền màn hình',
            onPressed: () => showSnack(context, 'Đang tìm thiết bị trên cùng mạng Wi-Fi'),
          ),
          if (isMine && isCustom)
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn playlist',
              onSelected: (val) {
                if (val == 'edit') {
                  _editPlaylist();
                } else if (val == 'delete') {
                  _confirmDeletePlaylist();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Chỉnh sửa danh sách phát'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa danh sách phát', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _detail == null) {
      return const LoadingView();
    }
    if (_error != null && _detail == null) {
      return ErrorView(message: _error!, onRetry: _loadDetail);
    }
    if (_detail == null) {
      return const SizedBox.shrink();
    }

    final header = PlaylistHeader(
      detail: _detail!,
      videoCount: _items.length,
      coverUrl: _items.isEmpty ? '' : (_items.first.video.thumbnailUrl ?? _detail!.playlist.thumbnailUrl ?? ''),
      currentSort: _sort,
      onSortChanged: _onSortChanged,
      onPlayAll: _playAll,
      onShuffle: _shuffle,
      onEdit: _editPlaylist,
      onOpenChannel: () => context.push(AppRoutes.channel(_detail!.playlist.ownerChannelId)),
    );

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header,
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyView(
                icon: Icons.playlist_play,
                title: 'Chưa có video nào trong danh sách phát này',
              ),
            ),
          ],
        ),
      );
    }

    final canReorder = _detail!.mine && _sort == 'manual';

    if (canReorder) {
      return RefreshIndicator(
        onRefresh: _loadDetail,
        child: ReorderableListView.builder(
          header: header,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _items.length,
          // ignore: deprecated_member_use
          onReorder: _onReorder,
          itemBuilder: (context, index) {
            final item = _items[index];
            return Material(
              key: ValueKey('playlist_item_${item.video.id}_${item.position}'),
              color: Colors.transparent,
              child: VideoCardCompact(
                video: item.video,
                onTap: () => context.push(AppRoutes.video(item.video.id)),
                leading: SizedBox(
                  width: 24,
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle, color: AppColors.textSecondary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: () => _showItemOptions(index),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return header;
          final itemIndex = index - 1;
          final item = _items[itemIndex];
          return VideoCardCompact(
            key: ValueKey('playlist_item_${item.video.id}'),
            video: item.video,
            onTap: () => context.push(AppRoutes.video(item.video.id)),
            leading: SizedBox(
              width: 24,
              child: Center(
                child: Text(
                  '${itemIndex + 1}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            onMore: () => _showItemOptions(itemIndex),
          );
        },
      ),
    );
  }
}
