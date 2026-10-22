import 'json_utils.dart';

/// Kênh rút gọn, đi kèm video / bình luận / thông báo.
class ChannelBrief {
  final int id;
  final String name;
  final String handle;
  final String? avatarUrl;
  final bool verified;
  final int subscriberCount;

  const ChannelBrief({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
    this.verified = false,
    this.subscriberCount = 0,
  });

  factory ChannelBrief.fromJson(Map<String, dynamic> j) => ChannelBrief(
        id: asInt(j['id']),
        name: asString(j['name']),
        handle: asString(j['handle']),
        avatarUrl: j['avatarUrl'] as String?,
        verified: asBool(j['verified']),
        subscriberCount: asInt(j['subscriberCount']),
      );
}
