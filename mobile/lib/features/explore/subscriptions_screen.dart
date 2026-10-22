import 'package:flutter/material.dart';

import '../../shared/widgets/screen_placeholder.dart';
import '../../shared/widgets/top_bar.dart';

/// MÀN 12 · KÊNH ĐĂNG KÝ · Người 3 (tab 4)
/// API: ChannelService.mySubscriptions(sort:)               (hàng avatar, trang "Tất cả")
///      ChannelService.subscriptionFeed(channelId:, type:, page:)
/// Khách: EmptyView "Đừng bỏ lỡ video mới" + nút Đăng nhập
/// Chi tiết: docs/tasks/NGUOI-3.md
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const VtubeLogo(), actions: topBarActions(context)),
      body: const ScreenPlaceholder(number: '12', title: 'Kênh đăng ký', owner: 'Người 3'),
    );
  }
}
