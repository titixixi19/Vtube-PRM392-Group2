import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Màn 16 (và badge chuông trên app bar).
class NotificationService {
  final ApiClient _api;
  NotificationService(this._api);

  /// type: all | mention
  Future<PageResult<NotificationItem>> list({String type = 'all', int page = 0, int size = 20}) async =>
      PageResult.fromJson(
          await _api.get('/api/me/notifications', query: {'type': type, 'page': page, 'size': size}),
          NotificationItem.fromJson);

  Future<int> unreadCount() async => ((await _api.get('/api/me/notifications/unread-count'))['count'] as num).toInt();

  Future<void> markRead(int id) async => _api.put('/api/notifications/$id/read');

  Future<void> markAllRead() async => _api.put('/api/me/notifications/read-all');

  Future<void> delete(int id) async => _api.delete('/api/notifications/$id');
}
