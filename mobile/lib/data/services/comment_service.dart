import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Màn 7.
class CommentService {
  final ApiClient _api;
  CommentService(this._api);

  /// sort: top | new
  Future<PageResult<Comment>> list(int videoId, {String sort = 'top', int page = 0, int size = 20}) async =>
      PageResult.fromJson(
          await _api.get('/api/videos/$videoId/comments', query: {'sort': sort, 'page': page, 'size': size}),
          Comment.fromJson);

  Future<PageResult<Comment>> replies(int commentId, {int page = 0, int size = 20}) async => PageResult.fromJson(
      await _api.get('/api/comments/$commentId/replies', query: {'page': page, 'size': size}), Comment.fromJson);

  Future<Comment> create(int videoId, String content, {int? parentId}) async => Comment.fromJson(
      await _api.post('/api/videos/$videoId/comments', body: {'content': content, 'parentId': parentId}));

  Future<Comment> update(int id, String content) async =>
      Comment.fromJson(await _api.put('/api/comments/$id', body: {'content': content}));

  Future<void> delete(int id) async => _api.delete('/api/comments/$id');

  Future<Comment> react(int id, int value) async =>
      Comment.fromJson(await _api.put('/api/comments/$id/reaction', body: {'value': value}));

  Future<Comment> togglePin(int id) async => Comment.fromJson(await _api.put('/api/comments/$id/pin'));

  Future<Comment> toggleHeart(int id) async => Comment.fromJson(await _api.put('/api/comments/$id/heart'));
}
