import 'channel_brief.dart';
import 'json_utils.dart';

/// Trang kênh (GET /api/channels/{id}).
class Channel {
  final int id;
  final int userId;
  final String name;
  final String handle;
  final String? description;
  final String? avatarUrl;
  final String? bannerUrl;
  final bool verified;
  final int subscriberCount;
  final int videoCount;
  final int totalViews;
  final String createdAt;
  final bool subscribed;
  final String? notifyMode;
  final bool mine;

  const Channel({
    required this.id,
    required this.userId,
    required this.name,
    required this.handle,
    this.description,
    this.avatarUrl,
    this.bannerUrl,
    this.verified = false,
    this.subscriberCount = 0,
    this.videoCount = 0,
    this.totalViews = 0,
    required this.createdAt,
    this.subscribed = false,
    this.notifyMode,
    this.mine = false,
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: asInt(j['id']),
        userId: asInt(j['userId']),
        name: asString(j['name']),
        handle: asString(j['handle']),
        description: j['description'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        bannerUrl: j['bannerUrl'] as String?,
        verified: asBool(j['verified']),
        subscriberCount: asInt(j['subscriberCount']),
        videoCount: asInt(j['videoCount']),
        totalViews: asInt(j['totalViews']),
        createdAt: asString(j['createdAt']),
        subscribed: asBool(j['subscribed']),
        notifyMode: j['notifyMode'] as String?,
        mine: asBool(j['mine']),
      );

  ChannelBrief toBrief() => ChannelBrief(
      id: id, name: name, handle: handle, avatarUrl: avatarUrl, verified: verified, subscriberCount: subscriberCount);
}

/// Kết quả đăng ký / hủy đăng ký kênh.
class SubscriptionResult {
  final bool subscribed;
  final String? notifyMode;
  final int subscriberCount;

  const SubscriptionResult(this.subscribed, this.notifyMode, this.subscriberCount);

  factory SubscriptionResult.fromJson(Map<String, dynamic> j) =>
      SubscriptionResult(asBool(j['subscribed']), j['notifyMode'] as String?, asInt(j['subscriberCount']));
}

/// Một kênh trong danh sách đã đăng ký (màn 12).
class SubscribedChannel {
  final ChannelBrief channel;
  final String notifyMode;
  final bool hasNew;
  final String? lastUploadAt;

  const SubscribedChannel({required this.channel, required this.notifyMode, this.hasNew = false, this.lastUploadAt});

  factory SubscribedChannel.fromJson(Map<String, dynamic> j) => SubscribedChannel(
        channel: ChannelBrief.fromJson(j['channel'] as Map<String, dynamic>),
        notifyMode: asString(j['notifyMode'], 'personalized'),
        hasNew: asBool(j['hasNew']),
        lastUploadAt: j['lastUploadAt'] as String?,
      );
}
