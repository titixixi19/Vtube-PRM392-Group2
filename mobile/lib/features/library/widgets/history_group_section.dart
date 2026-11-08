import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/models.dart';

/// Nhóm lịch sử xem theo nhãn ngày.
class HistoryDateGroup {
  final String label;
  final List<HistoryItem> items;

  HistoryDateGroup({required this.label, required this.items});
}

/// Chuyển đổi chuỗi ISO thời điểm xem thành nhãn tiếng Việt thân thiện:
/// "Hôm nay", "Hôm qua", "Tuần này", "Tháng này", hoặc "dd thg mm, yyyy".
String formatHistoryDateLabel(String watchedAtIso, {DateTime? now}) {
  final date = DateTime.tryParse(watchedAtIso)?.toLocal();
  if (date == null) return 'Trước đó';

  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final itemDate = DateTime(date.year, date.month, date.day);

  final diffDays = today.difference(itemDate).inDays;

  if (diffDays == 0) return 'Hôm nay';
  if (diffDays == 1) return 'Hôm qua';
  if (diffDays > 1 && diffDays < 7) return 'Tuần này';
  if (date.year == today.year && date.month == today.month) return 'Tháng này';
  return '${date.day} thg ${date.month}, ${date.year}';
}

/// Gom các HistoryItem liên tiếp cùng nhóm ngày thành các `HistoryDateGroup`.
List<HistoryDateGroup> groupHistoryItems(List<HistoryItem> items, {DateTime? now}) {
  final groups = <HistoryDateGroup>[];
  for (final item in items) {
    final label = formatHistoryDateLabel(item.watchedAt, now: now);
    if (groups.isEmpty || groups.last.label != label) {
      groups.add(HistoryDateGroup(label: label, items: [item]));
    } else {
      groups.last.items.add(item);
    }
  }
  return groups;
}

/// Banner màu hổ phách cảnh báo khi nhật ký xem đang bị tạm dừng.
class HistoryPausedBanner extends StatelessWidget {
  final VoidCallback onResume;

  const HistoryPausedBanner({super.key, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline, color: AppColors.warning, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Nhật ký xem đang bị tạm dừng',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onResume,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Bật lại', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Tiêu đề mỗi nhóm ngày: tên nhóm bên trái và số lượng video bên phải.
class HistoryGroupHeader extends StatelessWidget {
  final String title;
  final int count;

  const HistoryGroupHeader({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          Text(
            '$count video',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
