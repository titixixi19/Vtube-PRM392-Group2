import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class UploadResult {
  final String url;
  final String fileName;
  final int size;
  const UploadResult(this.url, this.fileName, this.size);
}

/// Màn 15 (video, thumbnail) và màn 3 / 11 (avatar, banner).
class UploadService {
  final ApiClient _api;
  UploadService(this._api);

  /// type: video | image. Trả url tương đối "/uploads/xxx.mp4" -> lưu nguyên vào video / avatar.
  Future<UploadResult> upload(
    String filePath, {
    String type = 'image',
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'type': type,
      'file': await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
    });
    final data = await _api.upload('/api/uploads', form, onProgress: onProgress, cancelToken: cancelToken);
    return UploadResult(data['url'] as String, data['fileName'] as String, (data['size'] as num).toInt());
  }
}
