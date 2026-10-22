import 'channel.dart';
import 'json_utils.dart';
import 'playlist.dart';
import 'video.dart';

class SearchResult {
  final List<Channel> channels;
  final List<Video> videos;
  final List<Video> shorts;
  final List<Playlist> playlists;
  final int page;
  final bool hasMore;

  const SearchResult({
    this.channels = const [],
    this.videos = const [],
    this.shorts = const [],
    this.playlists = const [],
    this.page = 0,
    this.hasMore = false,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        channels: asList(j['channels'], Channel.fromJson),
        videos: asList(j['videos'], Video.fromJson),
        shorts: asList(j['shorts'], Video.fromJson),
        playlists: asList(j['playlists'], Playlist.fromJson),
        page: asInt(j['page']),
        hasMore: asBool(j['hasMore']),
      );
}

/// GET /api/search/suggestions: history (icon đồng hồ) + suggestions (icon kính lúp)
class SearchSuggestions {
  final List<String> history;
  final List<String> suggestions;

  const SearchSuggestions({this.history = const [], this.suggestions = const []});

  factory SearchSuggestions.fromJson(Map<String, dynamic> j) => SearchSuggestions(
        history: (j['history'] as List? ?? []).cast<String>(),
        suggestions: (j['suggestions'] as List? ?? []).cast<String>(),
      );
}

/// Bộ lọc tìm kiếm (màn 10).
class SearchFilters {
  final String type; // all | video | short | channel | playlist | unwatched
  final String? uploadDate; // today | week | month | year
  final String? duration; // short | medium | long
  final String sort; // relevance | date | views | rating

  const SearchFilters({this.type = 'all', this.uploadDate, this.duration, this.sort = 'relevance'});

  bool get isDefault => uploadDate == null && duration == null && sort == 'relevance';

  SearchFilters copyWith({String? type, String? uploadDate, String? duration, String? sort}) => SearchFilters(
        type: type ?? this.type,
        uploadDate: uploadDate ?? this.uploadDate,
        duration: duration ?? this.duration,
        sort: sort ?? this.sort,
      );
}
