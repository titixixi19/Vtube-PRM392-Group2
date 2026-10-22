import 'json_utils.dart';

class CommentAuthor {
  final int userId;
  final int channelId;
  final String name;
  final String handle;
  final String? avatarUrl;

  const CommentAuthor({required this.userId, required this.channelId, required this.name, required this.handle, this.avatarUrl});

  factory CommentAuthor.fromJson(Map<String, dynamic> j) => CommentAuthor(
        userId: asInt(j['userId']),
        channelId: asInt(j['channelId']),
        name: asString(j['name']),
        handle: asString(j['handle']),
        avatarUrl: j['avatarUrl'] as String?,
      );
}

class Comment {
  final int id;
  final int videoId;
  final int? parentId;
  final String content;
  final int likeCount;
  final int replyCount;
  final bool pinned;
  final bool hearted;
  final String createdAt;
  final String? updatedAt;
  final CommentAuthor author;
  final bool byChannelOwner;
  final int myReaction;

  const Comment({
    required this.id,
    required this.videoId,
    this.parentId,
    required this.content,
    this.likeCount = 0,
    this.replyCount = 0,
    this.pinned = false,
    this.hearted = false,
    required this.createdAt,
    this.updatedAt,
    required this.author,
    this.byChannelOwner = false,
    this.myReaction = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: asInt(j['id']),
        videoId: asInt(j['videoId']),
        parentId: asIntOrNull(j['parentId']),
        content: asString(j['content']),
        likeCount: asInt(j['likeCount']),
        replyCount: asInt(j['replyCount']),
        pinned: asBool(j['pinned']),
        hearted: asBool(j['hearted']),
        createdAt: asString(j['createdAt']),
        updatedAt: j['updatedAt'] as String?,
        author: CommentAuthor.fromJson(j['author'] as Map<String, dynamic>),
        byChannelOwner: asBool(j['byChannelOwner']),
        myReaction: asInt(j['myReaction']),
      );
}
