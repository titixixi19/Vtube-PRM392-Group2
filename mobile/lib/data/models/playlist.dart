import 'json_utils.dart';
import 'video.dart';

class Playlist {
  final int id;
  final String title;
  final String? description;
  final String visibility; // public | unlisted | private
  final String kind; // liked | watch_later | custom
  final int videoCount;
  final String? thumbnailUrl;
  final String updatedAt;
  final int ownerUserId;
  final String ownerName;
  final int ownerChannelId;
  final bool? containsVideo;

  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.visibility = 'private',
    this.kind = 'custom',
    this.videoCount = 0,
    this.thumbnailUrl,
    required this.updatedAt,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerChannelId,
    this.containsVideo,
  });

  bool get isSystem => kind != 'custom';

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: asInt(j['id']),
        title: asString(j['title']),
        description: j['description'] as String?,
        visibility: asString(j['visibility'], 'private'),
        kind: asString(j['kind'], 'custom'),
        videoCount: asInt(j['videoCount']),
        thumbnailUrl: j['thumbnailUrl'] as String?,
        updatedAt: asString(j['updatedAt']),
        ownerUserId: asInt(j['ownerUserId']),
        ownerName: asString(j['ownerName']),
        ownerChannelId: asInt(j['ownerChannelId']),
        containsVideo: j['containsVideo'] as bool?,
      );
}

class PlaylistItem {
  final int position;
  final String addedAt;
  final Video video;

  const PlaylistItem({required this.position, required this.addedAt, required this.video});

  factory PlaylistItem.fromJson(Map<String, dynamic> j) => PlaylistItem(
        position: asInt(j['position']),
        addedAt: asString(j['addedAt']),
        video: Video.fromJson(j['video'] as Map<String, dynamic>),
      );
}

/// GET /api/playlists/{id}
class PlaylistDetail {
  final Playlist playlist;
  final bool mine;
  final int totalViews;
  final List<PlaylistItem> items;

  const PlaylistDetail({required this.playlist, required this.mine, required this.totalViews, required this.items});

  factory PlaylistDetail.fromJson(Map<String, dynamic> j) => PlaylistDetail(
        playlist: Playlist.fromJson(j['playlist'] as Map<String, dynamic>),
        mine: asBool(j['mine']),
        totalViews: asInt(j['totalViews']),
        items: asList(j['items'], PlaylistItem.fromJson),
      );
}
