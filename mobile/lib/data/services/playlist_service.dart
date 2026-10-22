import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Màn 4, 14 (và sheet "Lưu vào danh sách phát").
class PlaylistService {
  final ApiClient _api;
  PlaylistService(this._api);

  /// videoId: để biết video đã có trong playlist nào (containsVideo).
  Future<List<Playlist>> mine({int? videoId}) async =>
      (await _api.get('/api/me/playlists', query: {'videoId': videoId}) as List)
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<Playlist> create(String title, {String? description, String visibility = 'private'}) async =>
      Playlist.fromJson(
          await _api.post('/api/playlists', body: {'title': title, 'description': description, 'visibility': visibility}));

  /// sort: manual | added_new | added_old | popular | published
  Future<PlaylistDetail> detail(int id, {String sort = 'manual'}) async =>
      PlaylistDetail.fromJson(await _api.get('/api/playlists/$id', query: {'sort': sort}));

  Future<Playlist> update(int id, {String? title, String? description, String? visibility}) async =>
      Playlist.fromJson(await _api.put('/api/playlists/$id',
          body: {'title': title, 'description': description, 'visibility': visibility}));

  Future<void> delete(int id) async => _api.delete('/api/playlists/$id');

  Future<Playlist> addVideo(int id, int videoId) async =>
      Playlist.fromJson(await _api.post('/api/playlists/$id/videos', body: {'videoId': videoId}));

  Future<Playlist> removeVideo(int id, int videoId) async =>
      Playlist.fromJson(await _api.delete('/api/playlists/$id/videos/$videoId'));

  Future<Playlist> reorder(int id, List<int> videoIds) async =>
      Playlist.fromJson(await _api.put('/api/playlists/$id/order', body: {'videoIds': videoIds}));

  Future<Playlist> addWatchLater(int videoId) async => Playlist.fromJson(await _api.put('/api/me/watch-later/$videoId'));

  Future<Playlist> removeWatchLater(int videoId) async =>
      Playlist.fromJson(await _api.delete('/api/me/watch-later/$videoId'));
}
