import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/history_service.dart';
import '../../data/services/playlist_service.dart';
import '../../shared/widgets/app_network_image.dart';
import '../../shared/widgets/channel_avatar.dart';
import '../../shared/widgets/top_bar.dart';
import '../../shared/widgets/video_thumbnail.dart';
import 'widgets/playlist_form_dialog.dart';

/// MÀN 4 · TRANG "BẠN" · Người 1 (tab thứ 5 của bottom nav)
/// API:
///   - context.watch<AuthProvider>().user           (thông tin tài khoản, kênh)
///   - HistoryService.list(size: 10)                (hàng "Nhật ký xem")
///   - PlaylistService.mine() / create / update / delete   (hàng "Danh sách phát")
///   - AuthProvider.logout()                        (Đăng xuất)
/// Thiết kế: design/stitch/4._trang_b_n/ (bỏ banner "VTube Premium Creator", logo chỉ ghi "VTube" một lần).
/// Mỗi hàng tải và báo lỗi riêng (có "Thử lại"), không làm hỏng cả màn.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  /// Số video ở hàng "Nhật ký xem".
  static const historySize = 10;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int? _userId; // user đang hiển thị dữ liệu; đổi tài khoản / đăng xuất thì tải lại hoặc xóa

  List<HistoryItem>? _history;
  String? _historyError;
  List<Playlist>? _playlists;
  String? _playlistsError;

  // Tăng mỗi lần đổi user: kết quả tải về muộn của user cũ bị bỏ qua.
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = Provider.of<AuthProvider>(context).user?.id;
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    _history = null;
    _historyError = null;
    _playlists = null;
    _playlistsError = null;
    if (userId != null) {
      _loadHistory();
      _loadPlaylists();
    }
  }

  static String _messageOf(Object e) => e is ApiException ? e.message : 'Không tải được dữ liệu, vui lòng thử lại';

  Future<void> _loadHistory() async {
    final gen = _generation;
    final service = context.read<HistoryService>();
    if (_historyError != null) setState(() => _historyError = null);
    try {
      final page = await service.list(size: AccountScreen.historySize);
      if (mounted && gen == _generation) setState(() => _history = page.items);
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _historyError = _messageOf(e));
    }
  }

  Future<void> _loadPlaylists() async {
    final gen = _generation;
    final service = context.read<PlaylistService>();
    if (_playlistsError != null) setState(() => _playlistsError = null);
    try {
      final list = await service.mine();
      if (mounted && gen == _generation) setState(() => _playlists = list);
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _playlistsError = _messageOf(e));
    }
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([
      _loadHistory(),
      _loadPlaylists(),
      // Cập nhật tên, avatar, số người đăng ký; lỗi thì giữ thông tin cũ.
      auth.refreshMe().catchError((_) {}),
    ]);
  }

  /// Mở màn khác; quay lại thì tải ngầm hàng [reload] (vd. số video trong playlist đã đổi).
  Future<void> _open(String location, {Future<void> Function()? reload}) async {
    await context.push(location);
    if (mounted && reload != null) await reload();
  }

  // ---------------------------------------------------------------- Playlist

  Future<void> _createPlaylist() async {
    final service = context.read<PlaylistService>();
    Playlist? created;
    await showDialog<bool>(
      context: context,
      builder: (_) => PlaylistFormDialog(
        onSubmit: (title, visibility) async => created = await service.create(title, visibility: visibility),
      ),
    );
    final playlist = created;
    if (playlist == null || !mounted) return;
    setState(() {
      // Chèn ngay sau các playlist hệ thống để thấy liền ở đầu hàng.
      final list = [...?_playlists];
      list.insert(list.where((p) => p.isSystem).length, playlist);
      _playlists = list;
    });
    showSnack(context, 'Đã tạo danh sách phát "${playlist.title}"');
  }

  Future<void> _showPlaylistMenu(Playlist playlist) async {
    // Playlist hệ thống (Video đã thích, Xem sau) không đổi tên / xóa được.
    if (playlist.isSystem) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(playlist.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            titleTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Đổi tên'),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Xóa'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') await _renamePlaylist(playlist);
    if (action == 'delete') await _deletePlaylist(playlist);
  }

  void _replacePlaylist(int id, Playlist? updated) {
    setState(() {
      _playlists = [
        for (final p in _playlists ?? <Playlist>[])
          if (p.id != id) p else if (updated != null) updated,
      ];
    });
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final service = context.read<PlaylistService>();
    Playlist? updated;
    await showDialog<bool>(
      context: context,
      builder: (_) => PlaylistFormDialog(
        initialTitle: playlist.title,
        onSubmit: (title, _) async => updated = await service.update(playlist.id, title: title),
      ),
    );
    final result = updated;
    if (result != null && mounted) _replacePlaylist(playlist.id, result);
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final service = context.read<PlaylistService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa danh sách phát?'),
        content: Text('"${playlist.title}" sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await service.delete(playlist.id);
      if (!mounted) return;
      _replacePlaylist(playlist.id, null);
      showSnack(context, 'Đã xóa "${playlist.title}"');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _openLiked() async {
    if (_playlists == null) await _loadPlaylists();
    if (!mounted) return;
    final liked = _playlists?.where((p) => p.kind == 'liked').firstOrNull;
    if (liked == null) {
      showSnack(context, _playlistsError ?? 'Không tìm thấy danh sách Video đã thích');
      return;
    }
    await _open(AppRoutes.playlist(liked.id), reload: _loadPlaylists);
  }

  // ---------------------------------------------------------------- Tài khoản

  Future<void> _switchAccount(Me user) async {
    final addAccount = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Tài khoản', style: TextStyle(fontWeight: FontWeight.w600))),
          ListTile(
            leading: ChannelAvatar(url: user.avatarUrl, size: 36),
            title: Text(user.displayName),
            subtitle: Text(user.email),
            trailing: const Icon(Icons.check, color: AppColors.link),
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text('Đăng nhập tài khoản khác'),
            onTap: () => Navigator.pop(ctx, true),
          ),
        ]),
      ),
    );
    if (addAccount != true || !mounted) return;
    // Chưa lưu nhiều tài khoản cùng lúc: đăng xuất tài khoản này rồi mở màn Đăng nhập.
    await context.read<AuthProvider>().logout();
    if (mounted) context.push(AppRoutes.login);
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để xem lịch sử và danh sách phát.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await auth.logout();
    if (!mounted) return;
    showSnack(context, 'Đã đăng xuất');
    context.go(AppRoutes.home);
  }

  // ---------------------------------------------------------------- Giao diện

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const VtubeLogo(), actions: topBarActions(context)),
      body: user == null ? _buildGuest() : _buildSignedIn(user),
    );
  }

  Widget _buildGuest() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 24, 16, 24), children: [
      const Icon(Icons.account_circle_outlined, size: 96, color: AppColors.textSecondary),
      const SizedBox(height: 16),
      const Text(
        'Tận hưởng các video yêu thích',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'Đăng nhập để xem video đã thích, lịch sử và hơn thế nữa',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      Center(
        child: FilledButton.icon(
          onPressed: () => context.push(AppRoutes.login),
          icon: const Icon(Icons.login),
          label: const Text('Đăng nhập'),
        ),
      ),
      const SizedBox(height: 32),
      _MenuCard(items: _commonMenu()),
    ]);
  }

  Widget _buildSignedIn(Me user) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _Header(
              user: user,
              onOpenChannel: () => _open(AppRoutes.channel(user.channel.id)),
              onSwitchAccount: () => _switchAccount(user),
              onGoogleAccount: () => showSnack(context, 'Quản lý Tài khoản Google (giả lập)'),
            ),
          ),
          _SectionTitle(
            title: 'Nhật ký xem',
            trailing: TextButton(
              onPressed: () => _open(AppRoutes.history, reload: _loadHistory),
              style: TextButton.styleFrom(foregroundColor: AppColors.link),
              child: const Text('Xem tất cả'),
            ),
          ),
          _buildHistoryRow(),
          _SectionTitle(
            title: 'Danh sách phát',
            trailing: IconButton(
              tooltip: 'Tạo danh sách phát',
              onPressed: _createPlaylist,
              icon: const Icon(Icons.add),
            ),
          ),
          _buildPlaylistRow(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MenuCard(items: [
              _MenuItem(
                icon: Icons.smart_display_outlined,
                title: 'Video của bạn',
                subtitle: 'Xem các video đã tải lên kênh của bạn',
                onTap: () => _open(AppRoutes.channel(user.channel.id)),
              ),
              _MenuItem(
                icon: Icons.download_outlined,
                title: 'Video đã tải xuống',
                subtitle: '0 video · Sẵn sàng xem offline',
                onTap: () => showSnack(context, 'Chưa có video tải xuống (giả lập)'),
              ),
              _MenuItem(
                icon: Icons.thumb_up_outlined,
                title: 'Video đã thích',
                subtitle: _likedSubtitle(),
                onTap: _openLiked,
              ),
              ..._commonMenu(),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MenuCard(items: [
              _MenuItem(icon: Icons.logout, title: 'Đăng xuất', danger: true, onTap: _logout),
            ]),
          ),
        ],
      ),
    );
  }

  String? _likedSubtitle() {
    final liked = _playlists?.where((p) => p.kind == 'liked').firstOrNull;
    return liked == null ? null : '${liked.videoCount} video bạn đã thích';
  }

  List<_MenuItem> _commonMenu() => [
        _MenuItem(
          icon: Icons.settings_outlined,
          title: 'Cài đặt',
          subtitle: 'Chất lượng video, thông báo và quyền riêng tư',
          onTap: () => showSnack(context, 'Cài đặt sẽ có ở bản sau'),
        ),
        _MenuItem(
          icon: Icons.help_outline,
          title: 'Trợ giúp & phản hồi',
          subtitle: 'Trung tâm trợ giúp, gửi ý kiến đóng góp',
          onTap: () => showSnack(context, 'Trợ giúp & phản hồi sẽ có ở bản sau'),
        ),
      ];

  Widget _buildHistoryRow() {
    final items = _history;
    if (_historyError != null) return _RowError(message: _historyError!, onRetry: _loadHistory);
    if (items == null) return const _RowLoading(key: ValueKey('history-loading'));
    if (items.isEmpty) return const _RowEmpty(message: 'Video bạn xem sẽ hiện ở đây');
    return _HorizontalRow(children: [
      for (final item in items)
        _HistoryCard(item: item, onTap: () => _open(AppRoutes.video(item.video.id), reload: _loadHistory)),
    ]);
  }

  Widget _buildPlaylistRow() {
    final items = _playlists;
    if (_playlistsError != null) return _RowError(message: _playlistsError!, onRetry: _loadPlaylists);
    if (items == null) return const _RowLoading(key: ValueKey('playlists-loading'));
    if (items.isEmpty) return const _RowEmpty(message: 'Bấm + để tạo danh sách phát đầu tiên');
    return _HorizontalRow(children: [
      for (final p in items)
        _PlaylistCard(
          playlist: p,
          onTap: () => _open(AppRoutes.playlist(p.id), reload: _loadPlaylists),
          onLongPress: () => _showPlaylistMenu(p),
        ),
    ]);
  }
}

/// Avatar lớn, tên, "@handle · Xem kênh >", số người đăng ký, 2 chip tài khoản.
class _Header extends StatelessWidget {
  final Me user;
  final VoidCallback onOpenChannel;
  final VoidCallback onSwitchAccount;
  final VoidCallback onGoogleAccount;

  const _Header({
    required this.user,
    required this.onOpenChannel,
    required this.onSwitchAccount,
    required this.onGoogleAccount,
  });

  @override
  Widget build(BuildContext context) {
    final channel = user.channel;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ChannelAvatar(url: user.avatarUrl ?? channel.avatarUrl, size: 80),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                user.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: onOpenChannel,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Flexible(
                      child: Text(
                        '@${channel.handle} · Xem kênh',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(999)),
                child: Text(Fmt.subscribers(channel.subscriberCount), style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _AccountChip(icon: Icons.switch_account_outlined, label: 'Chuyển đổi tài khoản', onTap: onSwitchAccount),
            const SizedBox(width: 8),
            _AccountChip(icon: Icons.account_circle_outlined, label: 'Tài khoản Google', onTap: onGoogleAccount),
          ]),
        ),
      ]),
    );
  }
}

class _AccountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AccountChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.surfaceHigh,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionTitle({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        trailing,
      ]),
    );
  }
}

/// Hàng cuộn ngang. Chiều cao theo nội dung (không cố định) nên chữ to vẫn không bị tràn.
class _HorizontalRow extends StatelessWidget {
  final List<Widget> children;

  const _HorizontalRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          children[i],
        ],
      ]),
    );
  }
}

class _RowLoading extends StatelessWidget {
  const _RowLoading({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
          ),
        ),
      );
}

class _RowEmpty extends StatelessWidget {
  final String message;

  const _RowEmpty({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
}

/// Lỗi của riêng một hàng + nút "Thử lại"; các phần khác của màn vẫn dùng được.
class _RowError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RowError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.error_outline, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: AppColors.link),
          child: const Text('Thử lại'),
        ),
      ]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  static const width = 160.0;

  final HistoryItem item;
  final VoidCallback onTap;

  const _HistoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final video = item.video;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          VideoThumbnail(video: video, progress: item.progress, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 6),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(
            video.channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ]),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  static const width = 160.0;

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PlaylistCard({required this.playlist, required this.onTap, required this.onLongPress});

  IconData get _icon => switch (playlist.kind) {
        'liked' => Icons.thumb_up_outlined,
        'watch_later' => Icons.schedule,
        _ => Icons.playlist_play,
      };

  @override
  Widget build(BuildContext context) {
    final visibility = playlistVisibilityLabels[playlist.visibility] ?? playlist.visibility;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(fit: StackFit.expand, children: [
                AppNetworkImage(url: playlist.thumbnailUrl),
                // Nửa phải tối: icon loại playlist + số video (như thiết kế).
                Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.42,
                    heightFactor: 1,
                    child: ColoredBox(
                      color: const Color(0xB3000000),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_icon, size: 20, color: Colors.white),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.videoCount}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            '${playlist.videoCount} video · $visibility',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ]),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.title, this.subtitle, this.danger = false, required this.onTap});
}

/// Khối danh sách mục bo góc như thiết kế: icon trong ô vuông, tên, dòng phụ, mũi tên.
class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final item in items)
          ListTile(
            onTap: item.onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, size: 22, color: item.danger ? AppColors.accent : AppColors.textPrimary),
            ),
            title: Text(
              item.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: item.danger ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
            subtitle: item.subtitle == null
                ? null
                : Text(item.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: item.danger ? null : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ),
      ]),
    );
  }
}
