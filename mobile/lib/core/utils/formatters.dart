/// Định dạng hiển thị dùng chung (xem mục "Quy ước hiển thị" trong tài liệu đặc tả).
class Fmt {
  Fmt._();

  /// 999 -> "999", 1200 -> "1,2 N", 1500000 -> "1,5 Tr", 2000000000 -> "2 T"
  static String count(num n) {
    if (n < 1000) return n.toInt().toString();
    if (n < 1000000) return '${_short(n / 1000)} N';
    if (n < 1000000000) return '${_short(n / 1000000)} Tr';
    return '${_short(n / 1000000000)} T';
  }

  static String _short(double v) {
    // 1 chữ số thập phân khi < 10, bỏ ",0"
    final s = v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s.replaceAll('.', ',');
  }

  static String views(num n) => '${count(n)} lượt xem';

  static String subscribers(num n) => '${count(n)} người đăng ký';

  /// 65 -> "1:05", 3750 -> "1:02:30"
  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  /// "2026-10-22T04:30:00Z" -> "3 ngày trước"
  static String timeAgo(String? iso) {
    if (iso == null) return '';
    final time = DateTime.tryParse(iso);
    if (time == null) return '';
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} tuần trước';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} tháng trước';
    return '${diff.inDays ~/ 365} năm trước';
  }

  /// Dòng meta dưới tiêu đề video: "Tên kênh · 1,2 Tr lượt xem · 3 ngày trước"
  static String videoMeta(String channelName, num views, String? publishedAt) =>
      '$channelName · ${Fmt.views(views)} · ${timeAgo(publishedAt)}';
}
