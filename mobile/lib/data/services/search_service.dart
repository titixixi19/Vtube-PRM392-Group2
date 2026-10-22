import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Màn 9, 10.
class SearchService {
  final ApiClient _api;
  SearchService(this._api);

  Future<SearchResult> search(String q, {SearchFilters filters = const SearchFilters(), int page = 0, int size = 20}) async =>
      SearchResult.fromJson(await _api.get('/api/search', query: {
        'q': q,
        'type': filters.type,
        'uploadDate': filters.uploadDate,
        'duration': filters.duration,
        'sort': filters.sort,
        'page': page,
        'size': size,
      }));

  Future<SearchSuggestions> suggestions(String q) async =>
      SearchSuggestions.fromJson(await _api.get('/api/search/suggestions', query: {'q': q}));

  /// keyword = null -> xóa toàn bộ lịch sử tìm kiếm.
  Future<void> deleteHistory({String? keyword}) async =>
      _api.delete('/api/me/search-history', query: {'keyword': keyword});
}
