import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/channel_service.dart';
import '../../shared/widgets/chip_bar.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/top_bar.dart';
import '../../shared/widgets/video_card_large.dart';
import '../../shared/widgets/video_options_sheet.dart';
import 'widgets/all_subscriptions_screen.dart';
import 'widgets/subscription_channel_bar.dart';

/// MÀN 12 · KÊNH ĐĂNG KÝ · Người 3 (Hiếu) (tab 4)
///
/// Các tính năng:
/// - Khách: EmptyView "Đừng bỏ lỡ video mới" + nút Đăng nhập. Theo dõi qua AuthProvider.
/// - Hàng avatar kênh cuộn ngang (SubscriptionChannelBar):
///   - Có chấm xanh hasNewDot khi có video mới.
///   - Bấm avatar: lọc feed theo kênh đó, avatar được viền nổi bật, hiện nút "Xem kênh" dẫn tới Màn 11.
///   - Bấm lại avatar: bỏ lọc.
///   - Nút "Tất cả" ở cuối hàng: mở AllSubscriptionsScreen để quản lý thông báo / hủy đăng ký.
/// - ChipBar loại nội dung: Tất cả, Hôm nay, Video, Shorts, Trực tiếp, Tiếp tục xem, Chưa xem.
/// - Feed video phân trang: VideoCardLarge, kéo làm mới, cuộn vô hạn.
/// - Thông báo hết video: "Bạn đã cập nhật hết video mới!".
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  static const _chipLabels = ['Tất cả', 'Hôm nay', 'Video', 'Shorts', 'Trực tiếp', 'Tiếp tục xem', 'Chưa xem'];
  static const _chipTypes = ['all', 'today', 'video', 'short', 'live', 'continue', 'unwatched'];

  final _scroll = ScrollController();

  final List<SubscribedChannel> _channels = [];
  int? _selectedChannelId;
  int _selectedChipIndex = 0;

  final List<Video> _videos = [];
  int _page = 0;
  bool _hasMore = true;

  bool _loadingChannels = true;
  bool _loadingFeed = true;
  bool _loadingMore = false;
  String? _channelsError;
  String? _feedError;
  int _feedReqId = 0;

  bool? _lastLoggedIn;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (_lastLoggedIn != isLoggedIn) {
      _lastLoggedIn = isLoggedIn;
      if (isLoggedIn) {
        _loadData();
      } else {
        _selectedChannelId = null;
        _selectedChipIndex = 0;
        _channels.clear();
        _videos.clear();
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
    if (_scroll.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadChannels(),
      _refreshFeed(),
    ]);
  }

  Future<void> _loadChannels() async {
    setState(() {
      _loadingChannels = true;
      _channelsError = null;
    });

    try {
      final res = await context.read<ChannelService>().mySubscriptions();
      if (!mounted) return;
      setState(() {
        _channels.clear();
        _channels.addAll(res);
        if (_selectedChannelId != null && !_channels.any((c) => c.channel.id == _selectedChannelId)) {
          _selectedChannelId = null;
        }
        _loadingChannels = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _channelsError = e.message;
        _loadingChannels = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _channelsError = 'Không thể tải danh sách kênh đăng ký.';
        _loadingChannels = false;
      });
    }
  }

  Future<void> _refreshFeed({bool silent = false}) async {
    final reqId = ++_feedReqId;
    if (!silent) {
      setState(() {
        _loadingFeed = true;
        _loadingMore = false;
        _feedError = null;
        _page = 0;
        _videos.clear();
        _hasMore = true;
      });
    } else {
      _loadingMore = false;
    }

    try {
      final res = await context.read<ChannelService>().subscriptionFeed(
            channelId: _selectedChannelId,
            type: _chipTypes[_selectedChipIndex],
            page: 0,
          );
      if (!mounted || reqId != _feedReqId) return;
      setState(() {
        if (silent) _videos.clear();
        _videos.addAll(res.items);
        _page = res.page;
        _hasMore = res.hasMore;
        _loadingFeed = false;
        _loadingMore = false;
        _feedError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || reqId != _feedReqId) return;
      setState(() {
        if (!silent) _feedError = e.message;
        _loadingFeed = false;
        _loadingMore = false;
      });
      if (silent) showSnack(context, e.message);
    } catch (_) {
      if (!mounted || reqId != _feedReqId) return;
      setState(() {
        if (!silent) _feedError = 'Không thể tải video từ các kênh đăng ký.';
        _loadingFeed = false;
        _loadingMore = false;
      });
      if (silent) showSnack(context, 'Không thể tải video từ các kênh đăng ký.');
    }
  }

  Future<void> _loadMore() async {
    if (_loadingFeed || _loadingMore || !_hasMore) return;
    final reqId = _feedReqId;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;
      final res = await context.read<ChannelService>().subscriptionFeed(
            channelId: _selectedChannelId,
            type: _chipTypes[_selectedChipIndex],
            page: nextPage,
          );
      if (!mounted || reqId != _feedReqId) return;
      setState(() {
        _videos.addAll(res.items);
        _page = res.page;
        _hasMore = res.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || reqId != _feedReqId) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
      showSnack(context, 'Không thể tải thêm video');
    }
  }

  void _onChannelSelected(int? channelId) {
    if (_selectedChannelId == channelId) return;
    setState(() => _selectedChannelId = channelId);
    _refreshFeed();
  }

  void _onChipSelected(int index) {
    if (_selectedChipIndex == index) return;
    setState(() => _selectedChipIndex = index);
    _refreshFeed();
  }

  Future<void> _openAllSubscriptions() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AllSubscriptionsScreen()),
    );
    if (changed == true && mounted) {
      await _loadChannels();
      if (mounted) await _refreshFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const VtubeLogo(),
        actions: topBarActions(context),
      ),
      body: !isLoggedIn ? _buildGuestView() : _buildContent(),
    );
  }

  Widget _buildGuestView() {
    return EmptyView(
      icon: Icons.subscriptions_outlined,
      title: 'Đừng bỏ lỡ video mới',
      message: 'Đăng nhập để xem cập nhật từ các kênh VTube bạn yêu thích',
      actionLabel: 'Đăng nhập',
      onAction: () => context.push(AppRoutes.login),
    );
  }

  Widget _buildContent() {
    if (_loadingChannels && _channels.isEmpty && _loadingFeed && _videos.isEmpty) {
      return const LoadingView();
    }

    if (_channelsError != null && _channels.isEmpty) {
      return ErrorView(message: _channelsError!, onRetry: _loadData);
    }

    if (!_loadingChannels && _channels.isEmpty) {
      return EmptyView(
        icon: Icons.subscriptions_outlined,
        title: 'Hãy đăng ký kênh để xem video mới nhất tại đây',
        actionLabel: 'Khám phá kênh',
        onAction: () => context.go(AppRoutes.home),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadChannels();
        await _refreshFeed(silent: true);
      },
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceContainer,
      child: ListView(
        key: const Key('subscriptions_feed_list_view'),
        controller: _scroll,
        children: [
          // 1. Hàng avatar kênh đăng ký
          SubscriptionChannelBar(
            channels: _channels,
            selectedChannelId: _selectedChannelId,
            onChannelSelected: _onChannelSelected,
            onAllPressed: _openAllSubscriptions,
            onViewChannelPressed:
                _selectedChannelId != null ? () => context.push(AppRoutes.channel(_selectedChannelId!)) : null,
          ),

          // 2. ChipBar chọn loại nội dung
          ChipBar(
            labels: _chipLabels,
            selectedIndex: _selectedChipIndex,
            onSelected: _onChipSelected,
          ),
          const SizedBox(height: 8),

          // 3. Feed video
          if (_loadingFeed && _videos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: LoadingView(),
            )
          else if (_feedError != null && _videos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: ErrorView(
                message: _feedError!,
                onRetry: _refreshFeed,
              ),
            )
          else if (_videos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: EmptyView(
                icon: Icons.video_library_outlined,
                title: 'Chưa có video nào',
                message: 'Các video mới sẽ xuất hiện ở đây',
              ),
            )
          else ...[
            for (final v in _videos)
              VideoCardLarge(
                key: Key('video_card_large_${v.id}'),
                video: v,
                onTap: () => v.isShort ? context.push(AppRoutes.shortsAt(v.id)) : context.push(AppRoutes.video(v.id)),
                onChannelTap: () => context.push(AppRoutes.channel(v.channel.id)),
                onMore: () => showVideoOptionsSheet(
                  context,
                  v,
                  onHidden: () => setState(() => _videos.remove(v)),
                ),
              ),

            // Đang tải thêm trang tiếp
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

            // Đã hết video
            if (!_hasMore && _videos.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Bạn đã cập nhật hết video mới!',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
