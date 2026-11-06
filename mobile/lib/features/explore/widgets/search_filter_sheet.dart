import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/models.dart';

/// Bottom sheet bộ lọc tìm kiếm nâng cao (Màn 10).
Future<void> showSearchFilterSheet(
  BuildContext context, {
  required SearchFilters currentFilters,
  required ValueChanged<SearchFilters> onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SearchFilterSheetContent(
      initialFilters: currentFilters,
      onApply: onApply,
    ),
  );
}

class _SearchFilterSheetContent extends StatefulWidget {
  final SearchFilters initialFilters;
  final ValueChanged<SearchFilters> onApply;

  const _SearchFilterSheetContent({
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<_SearchFilterSheetContent> createState() => _SearchFilterSheetContentState();
}

class _SearchFilterSheetContentState extends State<_SearchFilterSheetContent> {
  late String _type;
  String? _uploadDate;
  String? _duration;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _type = widget.initialFilters.type;
    _uploadDate = widget.initialFilters.uploadDate;
    _duration = widget.initialFilters.duration;
    _sort = widget.initialFilters.sort;
  }

  void _reset() {
    setState(() {
      _type = 'all';
      _uploadDate = null;
      _duration = null;
      _sort = 'relevance';
    });
  }

  void _apply() {
    final updated = SearchFilters(
      type: _type,
      uploadDate: _uploadDate,
      duration: _duration,
      sort: _sort,
    );
    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề & nút đóng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bộ lọc tìm kiếm',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppColors.divider, height: 16),

            // 1. Ngày tải lên
            _buildSectionTitle('Ngày tải lên'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Mọi lúc', _uploadDate == null, () => setState(() => _uploadDate = null)),
                _buildChoiceChip('Hôm nay', _uploadDate == 'today', () => setState(() => _uploadDate = 'today')),
                _buildChoiceChip('Tuần này', _uploadDate == 'week', () => setState(() => _uploadDate = 'week')),
                _buildChoiceChip('Tháng này', _uploadDate == 'month', () => setState(() => _uploadDate = 'month')),
                _buildChoiceChip('Năm nay', _uploadDate == 'year', () => setState(() => _uploadDate = 'year')),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Loại nội dung
            _buildSectionTitle('Loại nội dung'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Tất cả', _type == 'all', () => setState(() => _type = 'all')),
                _buildChoiceChip('Video', _type == 'video', () => setState(() => _type = 'video')),
                _buildChoiceChip('Kênh', _type == 'channel', () => setState(() => _type = 'channel')),
                _buildChoiceChip('Danh sách phát', _type == 'playlist', () => setState(() => _type = 'playlist')),
              ],
            ),
            const SizedBox(height: 14),

            // 3. Thời lượng
            _buildSectionTitle('Thời lượng'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Mọi thời lượng', _duration == null, () => setState(() => _duration = null)),
                _buildChoiceChip('Dưới 4 phút', _duration == 'short', () => setState(() => _duration = 'short')),
                _buildChoiceChip('4–20 phút', _duration == 'medium', () => setState(() => _duration = 'medium')),
                _buildChoiceChip('Trên 20 phút', _duration == 'long', () => setState(() => _duration = 'long')),
              ],
            ),
            const SizedBox(height: 14),

            // 4. Sắp xếp theo
            _buildSectionTitle('Sắp xếp theo'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Mức độ liên quan', _sort == 'relevance', () => setState(() => _sort = 'relevance')),
                _buildChoiceChip('Ngày tải lên', _sort == 'date', () => setState(() => _sort = 'date')),
                _buildChoiceChip('Lượt xem', _sort == 'views', () => setState(() => _sort = 'views')),
                _buildChoiceChip('Xếp hạng', _sort == 'rating', () => setState(() => _sort = 'rating')),
              ],
            ),
            const SizedBox(height: 20),

            // Hàng nút Đặt lại và Áp dụng
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('filter_reset_button'),
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Đặt lại'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('filter_apply_button'),
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.chipSelectedFg : AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      selectedColor: AppColors.chipSelectedBg,
      backgroundColor: AppColors.surfaceHigh,
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
  }
}
