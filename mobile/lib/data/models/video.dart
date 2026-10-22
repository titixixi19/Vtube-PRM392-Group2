import 'channel_brief.dart';
import 'json_utils.dart';

/// Trạng thái của người đang xem (chỉ có ở GET /api/videos/{id} khi đã đăng nhập).
class ViewerState {
  final int myReaction; // 1 like, -1 dislike, 0 chưa
  final bool subscribed;
  final String? notifyMode; // all | personalized | none
  final int progressSeconds;
  final bool inWatchLater;
  final bool owner;

  const ViewerState({
    this.myReaction = 0,
    this.subscribed = false,
    this.notifyMode,
    this.progressSeconds = 0,
    this.inWatchLater = false,
    this.owner = false,
  });

  factory ViewerState.fromJson(Map<String, dynamic> j) => ViewerState(
        myReaction: asInt(j['myReaction']),
        subscribed: asBool(j['subscribed']),
        notifyMode: j['notifyMode'] as String?,
        progressSeconds: asInt(j['progressSeconds']),
        inWatchLater: asBool(j['inWatchLater']),
        owner: asBool(j['owner']),
      );

  ViewerState copyWith({int? myReaction, bool? subscribed, String? notifyMode, bool? inWatchLater}) => ViewerState(
        myReaction: myReaction ?? this.myReaction,
        subscribed: subscribed ?? this.subscribed,
        notifyMode: notifyMode ?? this.notifyMode,
        progressSeconds: progressSeconds,
        inWatchLater: inWatchLater ?? this.inWatchLater,
        owner: owner,
      );
}

class Video {
  final int id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String videoUrl;
  final int durationSeconds;
  final int viewCount;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final int? categoryId;
  final bool isShort;
  final bool isLive;
  final String visibility; // public | unlisted | private
  final bool commentsEnabled;
  final String? tags;
  final String publishedAt;
  final ChannelBrief channel;
  final ViewerState? viewer;

  const Video({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.videoUrl,
    this.durationSeconds = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.commentCount = 0,
    this.categoryId,
    this.isShort = false,
    this.isLive = false,
    this.visibility = 'public',
    this.commentsEnabled = true,
    this.tags,
    required this.publishedAt,
    required this.channel,
    this.viewer,
  });

  factory Video.fromJson(Map<String, dynamic> j) => Video(
        id: asInt(j['id']),
        title: asString(j['title']),
        description: j['description'] as String?,
        thumbnailUrl: j['thumbnailUrl'] as String?,
        videoUrl: asString(j['videoUrl']),
        durationSeconds: asInt(j['durationSeconds']),
        viewCount: asInt(j['viewCount']),
        likeCount: asInt(j['likeCount']),
        dislikeCount: asInt(j['dislikeCount']),
        commentCount: asInt(j['commentCount']),
        categoryId: asIntOrNull(j['categoryId']),
        isShort: asBool(j['shortVideo']),
        isLive: asBool(j['live']),
        visibility: asString(j['visibility'], 'public'),
        commentsEnabled: j['commentsEnabled'] != false,
        tags: j['tags'] as String?,
        publishedAt: asString(j['publishedAt']),
        channel: ChannelBrief.fromJson(j['channel'] as Map<String, dynamic>),
        viewer: j['viewer'] == null ? null : ViewerState.fromJson(j['viewer'] as Map<String, dynamic>),
      );

  Video copyWith({int? likeCount, int? dislikeCount, int? commentCount, int? viewCount, ViewerState? viewer}) => Video(
        id: id,
        title: title,
        description: description,
        thumbnailUrl: thumbnailUrl,
        videoUrl: videoUrl,
        durationSeconds: durationSeconds,
        viewCount: viewCount ?? this.viewCount,
        likeCount: likeCount ?? this.likeCount,
        dislikeCount: dislikeCount ?? this.dislikeCount,
        commentCount: commentCount ?? this.commentCount,
        categoryId: categoryId,
        isShort: isShort,
        isLive: isLive,
        visibility: visibility,
        commentsEnabled: commentsEnabled,
        tags: tags,
        publishedAt: publishedAt,
        channel: channel,
        viewer: viewer ?? this.viewer,
      );
}

class Category {
  final int id;
  final String name;
  final String slug;

  const Category({required this.id, required this.name, required this.slug});

  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: asInt(j['id']), name: asString(j['name']), slug: asString(j['slug']));
}

/// Kết quả PUT /api/videos/{id}/reaction
class ReactionResult {
  final int likeCount;
  final int dislikeCount;
  final int myReaction;

  const ReactionResult(this.likeCount, this.dislikeCount, this.myReaction);

  factory ReactionResult.fromJson(Map<String, dynamic> j) =>
      ReactionResult(asInt(j['likeCount']), asInt(j['dislikeCount']), asInt(j['myReaction']));
}
