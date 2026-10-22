import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Màn 13 (và lưu tiến độ ở màn 6).
class HistoryService {
  final ApiClient _api;
  HistoryService(this._api);

  /// type: all | video | short | music
  Future<PageResult<HistoryItem>> list({String type = 'all', String? q, int page = 0, int size = 20}) async =>
      PageResult.fromJson(
          await _api.get('/api/me/history', query: {'type': type, 'q': q, 'page': page, 'size': size}),
          HistoryItem.fromJson);

  /// Trả false nếu user đang tạm dừng lịch sử.
  Future<bool> saveProgress(int videoId, int progressSeconds) async =>
      (await _api.put('/api/me/history/$videoId', body: {'progressSeconds': progressSeconds}))['saved'] == true;

  Future<void> delete(int videoId) async => _api.delete('/api/me/history/$videoId');

  Future<void> clear() async => _api.delete('/api/me/history');
}
