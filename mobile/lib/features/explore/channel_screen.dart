import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/channel_service.dart';
import '../../shared/widgets/state_views.dart';
import 'widgets/channel_about_sheet.dart';
import 'widgets/channel_edit_sheet.dart';
import 'widgets/channel_header.dart';
import 'widgets/channel_tabs.dart';

/// MÀN 11 · TRANG KÊNH · Người 3
/// API: ChannelService.get(id), videos(id, sort:), shorts(id), playlists(id),
///      subscribe / unsubscribe, updateMine (khi channel.mine = true)
/// Thiết kế: NestedScrollView + SliverAppBar + TabBar ghim (SliverPersistentHeader)
class ChannelScreen extends StatefulWidget {
  final int channelId;

  const ChannelScreen({super.key, required this.channelId});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Channel? _channel;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadChannel();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChannel({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final ch = await context.read<ChannelService>().get(widget.channelId);
      if (!mounted) return;
      setState(() {
        _channel = ch;
        _isLoading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Kênh này không có sẵn';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSubscribe() async {
    if (_channel == null) return;
    if (!await requireLogin(context)) return;
    if (!mounted) return;

    final service = context.read<ChannelService>();
    final isSub = _channel!.subscribed;

    try {
      if (isSub) {
        final res = await service.unsubscribe(_channel!.id);
        if (!mounted) return;
        setState(() {
          _channel = _channel!.copyWith(
            subscribed: false,
            subscriberCount: res.subscriberCount,
            notifyMode: res.notifyMode,
          );
        });
        showSnack(context, 'Đã hủy đăng ký kênh');
      } else {
        final res = await service.subscribe(_channel!.id);
        if (!mounted) return;
        setState(() {
          _channel = _channel!.copyWith(
            subscribed: true,
            subscriberCount: res.subscriberCount,
            notifyMode: res.notifyMode,
          );
        });
        showSnack(context, 'Đã đăng ký kênh');
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, 'Không thể thay đổi trạng thái đăng ký');
    }
  }

  void _onJoin() {
    if (_channel == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tham gia hội viên'),
        content: Text('Tính năng Hội viên cho kênh ${_channel!.name} đang được phát triển.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _onCustomizeChannel() async {
    if (_channel == null) return;
    final updated = await showChannelEditSheet(context, _channel!);
    if (updated != null && mounted) {
      setState(() => _channel = updated);
      showSnack(context, 'Đã cập nhật thông tin kênh');
    }
  }

  void _onManageVideos() {
    _tabController.animateTo(1);
    showSnack(context, 'Quản lý video trên kênh của bạn');
  }

  void _onShowAbout() {
    if (_channel == null) return;
    showChannelAboutSheet(context, _channel!);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    if (_error != null || _channel == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Trang kênh'),
        ),
        body: EmptyView(
          icon: Icons.error_outline,
          title: 'Kênh này không có sẵn',
          message: (_error != null && _error != 'Kênh này không có sẵn') ? _error : null,
          actionLabel: 'Quay lại',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final channel = _channel!;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App Bar cuộn: Tên kênh, Cast, Tìm kiếm, 3 chấm
            SliverAppBar(
              pinned: true,
              floating: false,
              title: Text(
                channel.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.cast),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.push(AppRoutes.search),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'share') {
                      Share.share('Kênh ${channel.name}: https://vtube.vn/@${channel.handle}');
                    } else if (value == 'report') {
                      showSnack(context, 'Cảm ơn bạn đã báo cáo kênh');
                    } else if (value == 'block') {
                      showSnack(context, 'Đã chặn người dùng');
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text('Chia sẻ')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text('Báo cáo')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block_outlined, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text('Chặn')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Header chứa banner, avatar, thông tin, các nút
            SliverToBoxAdapter(
              child: ChannelHeader(
                channel: channel,
                onToggleSubscribe: _toggleSubscribe,
                onJoin: _onJoin,
                onCustomizeChannel: _onCustomizeChannel,
                onManageVideos: _onManageVideos,
                onShowAbout: _onShowAbout,
              ),
            ),

            // TabBar ghim cố định khi cuộn
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 2,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                  tabs: const [
                    Tab(text: 'Trang chủ'),
                    Tab(text: 'Video'),
                    Tab(text: 'Shorts'),
                    Tab(text: 'Danh sách phát'),
                    Tab(text: 'Giới thiệu'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            ChannelHomeTab(channel: channel),
            ChannelVideosTab(channel: channel),
            ChannelShortsTab(channel: channel),
            ChannelPlaylistsTab(channel: channel),
            ChannelAboutTab(channel: channel),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

extension _ChannelCopyWith on Channel {
  Channel copyWith({
    int? id,
    int? userId,
    String? name,
    String? handle,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
    bool? verified,
    int? subscriberCount,
    int? videoCount,
    int? totalViews,
    String? createdAt,
    bool? subscribed,
    String? notifyMode,
    bool? mine,
  }) {
    return Channel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      verified: verified ?? this.verified,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      videoCount: videoCount ?? this.videoCount,
      totalViews: totalViews ?? this.totalViews,
      createdAt: createdAt ?? this.createdAt,
      subscribed: subscribed ?? this.subscribed,
      notifyMode: notifyMode ?? this.notifyMode,
      mine: mine ?? this.mine,
    );
  }
}
