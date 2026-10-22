import 'channel_brief.dart';
import 'json_utils.dart';

/// type: new_video | new_short | live | comment_reply | comment_heart | new_subscriber
class NotificationItem {
  final int id;
  final String type;
  final String message;
  final bool read;
  final String createdAt;
  final ChannelBrief? actor;
  final int? videoId;
  final String? videoThumbnailUrl;
  final int? videoDurationSeconds;
  final bool? videoShort;
  final int? commentId;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.message,
    this.read = false,
    required this.createdAt,
    this.actor,
    this.videoId,
    this.videoThumbnailUrl,
    this.videoDurationSeconds,
    this.videoShort,
    this.commentId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: asInt(j['id']),
        type: asString(j['type']),
        message: asString(j['message']),
        read: asBool(j['read']),
        createdAt: asString(j['createdAt']),
        actor: j['actor'] == null ? null : ChannelBrief.fromJson(j['actor'] as Map<String, dynamic>),
        videoId: asIntOrNull(j['videoId']),
        videoThumbnailUrl: j['videoThumbnailUrl'] as String?,
        videoDurationSeconds: asIntOrNull(j['videoDurationSeconds']),
        videoShort: j['videoShort'] as bool?,
        commentId: asIntOrNull(j['commentId']),
      );
}
