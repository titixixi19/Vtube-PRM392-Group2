import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/auth/require_login.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/services/channel_service.dart';
import '../../../shared/widgets/channel_avatar.dart';
import '../../../shared/widgets/chip_bar.dart';
import '../../../shared/widgets/state_views.dart';

/// Màn hình "Tất cả kênh đăng ký" mở từ Màn 12.
class AllSubscriptionsScreen extends StatefulWidget {
  const AllSubscriptionsScreen({super.key});

  @override
  State<AllSubscriptionsScreen> createState() => _AllSubscriptionsScreenState();
}

class _AllSubscriptionsScreenState extends State<AllSubscriptionsScreen> {
  static const _sortLabels = ['Liên quan nhất', 'Hoạt động mới', 'A-Z'];
  static const _sortKeys = ['relevance', 'recent', 'az'];

  int _selectedSortIndex = 1; // Mặc định Hoạt động mới (recent)
  final List<SubscribedChannel> _channels = [];
  bool _loading = true;
  String? _error;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await context.read<ChannelService>().mySubscriptions(
            sort: _sortKeys[_selectedSortIndex],
          );
      if (!mounted) return;
      setState(() {
        _channels.clear();
        _channels.addAll(res);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách kênh đăng ký.';
        _loading = false;
      });
    }
  }

  void _onSortChanged(int index) {
    if (_selectedSortIndex == index) return;
    setState(() => _selectedSortIndex = index);
    _loadChannels();
  }

  Future<void> _changeNotificationMode(SubscribedChannel item) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Tùy chọn thông báo cho ${item.channel.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            const Divider(color: AppColors.divider),
            ListTile(
              leading: const Icon(Icons.notifications_active, color: AppColors.accent),
              title: const Text('Tất cả'),
              subtitle: const Text('Nhận tất cả thông báo video và phát trực tiếp'),
              trailing: item.notifyMode == 'all' ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () => Navigator.pop(ctx, 'all'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications, color: AppColors.textPrimary),
              title: const Text('Cá nhân hóa'),
              subtitle: const Text('Nhận thông báo được đề xuất cho bạn'),
              trailing: item.notifyMode == 'personalized' ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () => Navigator.pop(ctx, 'personalized'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined, color: AppColors.textSecondary),
              title: const Text('Không có'),
              subtitle: const Text('Tắt thông báo từ kênh này'),
              trailing: item.notifyMode == 'none' ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
          ],
        ),
      ),
    );

    if (mode == null || mode == item.notifyMode || !mounted) return;

    final beforeMode = item.notifyMode;
    final index = _channels.indexOf(item);
    if (index != -1) {
      setState(() {
        _channels[index] = SubscribedChannel(
          channel: item.channel,
          notifyMode: mode,
          hasNew: item.hasNew,
          lastUploadAt: item.lastUploadAt,
        );
      });
    }

    try {
      await context.read<ChannelService>().subscribe(item.channel.id, notifyMode: mode);
      _hasChanged = true;
    } on ApiException catch (e) {
      if (!mounted) return;
      if (index != -1) {
        setState(() {
          _channels[index] = SubscribedChannel(
            channel: item.channel,
            notifyMode: beforeMode,
            hasNew: item.hasNew,
            lastUploadAt: item.lastUploadAt,
          );
        });
      }
      showSnack(context, e.message);
    }
  }

  Future<void> _confirmUnsubscribe(SubscribedChannel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Hủy đăng ký?'),
        content: Text('Hủy đăng ký kênh ${item.channel.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            key: const Key('confirm_unsubscribe_button'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đăng ký'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final index = _channels.indexOf(item);
    if (index != -1) {
      setState(() => _channels.removeAt(index));
    }

    try {
      await context.read<ChannelService>().unsubscribe(item.channel.id);
      _hasChanged = true;
      if (mounted) showSnack(context, 'Đã hủy đăng ký kênh ${item.channel.name}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (index != -1) {
        setState(() => _channels.insert(index, item));
      }
      showSnack(context, e.message);
    }
  }

  IconData _bellIcon(String mode) {
    switch (mode) {
      case 'all':
        return Icons.notifications_active;
      case 'none':
        return Icons.notifications_off_outlined;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanged);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasChanged),
          ),
          title: const Text('Kênh đăng ký'),
        ),
        body: Column(
          children: [
            ChipBar(
              labels: _sortLabels,
              selectedIndex: _selectedSortIndex,
              onSelected: _onSortChanged,
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _channels.isEmpty) {
      return const LoadingView();
    }

    if (_error != null && _channels.isEmpty) {
      return ErrorView(message: _error!, onRetry: _loadChannels);
    }

    if (_channels.isEmpty) {
      return const EmptyView(
        icon: Icons.subscriptions_outlined,
        title: 'Bạn chưa đăng ký kênh nào',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChannels,
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceContainer,
      child: ListView.separated(
        key: const Key('all_subscriptions_list'),
        itemCount: _channels.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1),
        itemBuilder: (context, i) {
          final item = _channels[i];
          final ch = item.channel;

          return ListTile(
            key: Key('all_sub_channel_${ch.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ChannelAvatar(url: ch.avatarUrl, size: 44),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
                if (ch.verified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle, size: 14, color: AppColors.link),
                ],
              ],
            ),
            subtitle: Text(
              '@${ch.handle} · ${Fmt.subscribers(ch.subscriberCount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('bell_button_${ch.id}'),
                  icon: Icon(_bellIcon(item.notifyMode), size: 22, color: AppColors.textPrimary),
                  tooltip: 'Tùy chọn chuông',
                  onPressed: () => _changeNotificationMode(item),
                ),
                PopupMenuButton<String>(
                  key: Key('channel_more_${ch.id}'),
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  color: AppColors.surfaceContainer,
                  onSelected: (val) {
                    if (val == 'unsubscribe') _confirmUnsubscribe(item);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'unsubscribe',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove_outlined, size: 20, color: AppColors.accent),
                          SizedBox(width: 10),
                          Text('Hủy đăng ký', style: TextStyle(color: AppColors.accent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => context.push(AppRoutes.channel(ch.id)),
          );
        },
      ),
    );
  }
}
