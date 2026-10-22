import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Màn 5, 6, 8, 15.
class VideoService {
  final ApiClient _api;
  VideoService(this._api);

  Future<List<Category>> categories() async =>
      (await _api.get('/api/categories') as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();

  /// category: all | live | recent | music | gaming | news | education | food | travel | tech | entertainment | sports
  Future<PageResult<Video>> feed({String? category, int page = 0, int size = 20}) async => PageResult.fromJson(
      await _api.get('/api/videos/feed', query: {'category': category, 'page': page, 'size': size}), Video.fromJson);

  Future<PageResult<Video>> shorts({int page = 0, int size = 10}) async =>
      PageResult.fromJson(await _api.get('/api/shorts', query: {'page': page, 'size': size}), Video.fromJson);

  /// Có thêm video.viewer khi đã đăng nhập.
  Future<Video> detail(int id) async => Video.fromJson(await _api.get('/api/videos/$id'));

  /// filter: all | channel | related | recent
  Future<PageResult<Video>> related(int id, {String filter = 'all', int page = 0, int size = 20}) async =>
      PageResult.fromJson(
          await _api.get('/api/videos/$id/related', query: {'filter': filter, 'page': page, 'size': size}),
          Video.fromJson);

  Future<void> addView(int id) async => _api.post('/api/videos/$id/view');

  /// value: 1 like, -1 dislike, 0 bỏ.
  Future<ReactionResult> react(int id, int value) async =>
      ReactionResult.fromJson(await _api.put('/api/videos/$id/reaction', body: {'value': value}));

  Future<void> notInterested(int id) async => _api.post('/api/videos/$id/not-interested');

  /// Tạo video sau khi đã upload file bằng UploadService.
  Future<Video> create({
    required String title,
    required String videoUrl,
    String? description,
    String? thumbnailUrl,
    int? durationSeconds,
    int? categoryId,
    bool isShort = false,
    String visibility = 'public',
    bool commentsEnabled = true,
    bool madeForKids = false,
    String? tags,
  }) async =>
      Video.fromJson(await _api.post('/api/videos', body: {
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'videoUrl': videoUrl,
        'durationSeconds': durationSeconds,
        'categoryId': categoryId,
        'shortVideo': isShort,
        'visibility': visibility,
        'commentsEnabled': commentsEnabled,
        'madeForKids': madeForKids,
        'tags': tags,
      }));

  /// Trường nào null thì backend giữ nguyên.
  Future<Video> update(int id, {String? title, String? description, String? thumbnailUrl, String? visibility}) async =>
      Video.fromJson(await _api.put('/api/videos/$id', body: {
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'visibility': visibility,
      }));

  Future<void> delete(int id) async => _api.delete('/api/videos/$id');
}
