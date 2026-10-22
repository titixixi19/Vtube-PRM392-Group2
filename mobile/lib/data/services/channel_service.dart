import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Màn 11, 12 (và nút Đăng ký ở màn 6, 8, 10).
class ChannelService {
  final ApiClient _api;
  ChannelService(this._api);

  Future<Channel> get(int id) async => Channel.fromJson(await _api.get('/api/channels/$id'));

  Future<Channel> byHandle(String handle) async => Channel.fromJson(await _api.get('/api/channels/handle/$handle'));

  /// sort: newest | popular | oldest
  Future<PageResult<Video>> videos(int id, {String sort = 'newest', int page = 0, int size = 20}) async =>
      PageResult.fromJson(
          await _api.get('/api/channels/$id/videos', query: {'sort': sort, 'page': page, 'size': size}),
          Video.fromJson);

  Future<PageResult<Video>> shorts(int id, {String sort = 'newest', int page = 0, int size = 30}) async =>
      PageResult.fromJson(
          await _api.get('/api/channels/$id/shorts', query: {'sort': sort, 'page': page, 'size': size}),
          Video.fromJson);

  Future<List<Playlist>> playlists(int id) async =>
      (await _api.get('/api/channels/$id/playlists') as List).map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();

  Future<Channel> updateMine({String? name, String? description, String? avatarUrl, String? bannerUrl}) async =>
      Channel.fromJson(await _api.put('/api/channels/me', body: {
        'name': name,
        'description': description,
        'avatarUrl': avatarUrl,
        'bannerUrl': bannerUrl,
      }));

  /// Đăng ký hoặc đổi chế độ chuông. notifyMode: all | personalized | none
  Future<SubscriptionResult> subscribe(int id, {String? notifyMode}) async => SubscriptionResult.fromJson(
      await _api.put('/api/channels/$id/subscription', body: {'notifyMode': notifyMode}));

  Future<SubscriptionResult> unsubscribe(int id) async =>
      SubscriptionResult.fromJson(await _api.delete('/api/channels/$id/subscription'));

  /// sort: recent | az | relevance
  Future<List<SubscribedChannel>> mySubscriptions({String sort = 'recent'}) async =>
      (await _api.get('/api/me/subscriptions', query: {'sort': sort}) as List)
          .map((e) => SubscribedChannel.fromJson(e as Map<String, dynamic>))
          .toList();

  /// type: all | today | video | short | live | continue | unwatched
  Future<PageResult<Video>> subscriptionFeed({int? channelId, String type = 'all', int page = 0, int size = 20}) async =>
      PageResult.fromJson(
          await _api.get('/api/me/subscriptions/feed',
              query: {'channelId': channelId, 'type': type, 'page': page, 'size': size}),
          Video.fromJson);
}
