import 'channel_brief.dart';
import 'json_utils.dart';

/// Tài khoản đang đăng nhập (GET /api/me).
class Me {
  final int id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool historyPaused;
  final String createdAt;
  final ChannelBrief channel;

  const Me({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.historyPaused = false,
    required this.createdAt,
    required this.channel,
  });

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: asInt(j['id']),
        email: asString(j['email']),
        displayName: asString(j['displayName']),
        avatarUrl: j['avatarUrl'] as String?,
        historyPaused: asBool(j['historyPaused']),
        createdAt: asString(j['createdAt']),
        channel: ChannelBrief.fromJson(j['channel'] as Map<String, dynamic>),
      );
}
