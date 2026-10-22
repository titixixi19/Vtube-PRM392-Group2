import 'json_utils.dart';
import 'video.dart';

class HistoryItem {
  final String watchedAt;
  final int progressSeconds;
  final Video video;

  const HistoryItem({required this.watchedAt, required this.progressSeconds, required this.video});

  /// Tỉ lệ đã xem (0..1) để vẽ thanh đỏ dưới thumbnail.
  double get progress => video.durationSeconds == 0 ? 0 : (progressSeconds / video.durationSeconds).clamp(0, 1).toDouble();

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        watchedAt: asString(j['watchedAt']),
        progressSeconds: asInt(j['progressSeconds']),
        video: Video.fromJson(j['video'] as Map<String, dynamic>),
      );
}
