import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/network/api_exception.dart';
import '../../data/services/search_service.dart';

/// MÀN 9 · TÌM KIẾM · Người 3 (Hiếu)
///
/// Các tính năng:
/// - AppBar với ô tìm kiếm bo tròn, tự focus, nút X xóa nội dung, nút Micro.
/// - Ô trống: lấy lịch sử tìm kiếm từ server (icon đồng hồ).
/// - Đang gõ: debounce 300 ms, gọi API gợi ý, RichText in đậm phần gợi ý thêm.
/// - Chống race condition với `_lastQuery`.
/// - Nút ↖ điền từ khóa vào ô mà chưa tìm.
/// - Nhấn giữ mục lịch sử: Dialog xác nhận xóa và gọi API `deleteHistory`.
/// - Enter hoặc bấm gợi ý: điều hướng tới `AppRoutes.searchResults(q)`.
class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  Timer? _debounceTimer;
  String _lastQuery = '';
  List<String> _history = [];
  List<String> _suggestions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery ?? '';
    _controller = TextEditingController(text: initial);
    _focusNode = FocusNode();

    if (initial.isNotEmpty) {
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: initial.length));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSuggestions(initial);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {}); // Cập nhật nút xóa X
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      _loadSuggestions('');
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadSuggestions(query);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    _lastQuery = query;
    setState(() => _loading = true);

    try {
      final service = context.read<SearchService>();
      final res = await service.suggestions(query);
      if (!mounted) return;
      if (_lastQuery != query) return;

      setState(() {
        _history = List<String>.from(res.history);
        _suggestions = List<String>.from(res.suggestions);
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      if (_lastQuery != query) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      if (_lastQuery != query) return;
      setState(() => _loading = false);
    }
  }

  void _submitSearch(String rawQuery) {
    final q = rawQuery.trim();
    if (q.isEmpty) return;
    context.push(AppRoutes.searchResults(q));
  }

  void _fillQuery(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    _focusNode.requestFocus();
    _onQueryChanged(text);
  }

  Future<void> _confirmDeleteHistory(String keyword) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa khỏi nhật ký tìm kiếm?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Từ khóa "$keyword" sẽ bị xóa khỏi nhật ký tìm kiếm của bạn.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteHistoryItem(keyword);
    }
  }

  Future<void> _deleteHistoryItem(String keyword) async {
    final prevHistory = List<String>.from(_history);
    setState(() {
      _history = List<String>.from(_history)..remove(keyword);
    });

    try {
      await context.read<SearchService>().deleteHistory(keyword: keyword);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _history = prevHistory);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _history = prevHistory);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa mục lịch sử. Vui lòng thử lại.')),
      );
    }
  }

  void _onVoiceSearchPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng tìm kiếm bằng giọng nói đang được phát triển.')),
    );
  }

  Widget _buildHighlightedText(String text, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final matchIndex = lowerText.indexOf(query);
    if (matchIndex == -1) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final before = text.substring(0, matchIndex);
    final match = text.substring(matchIndex, matchIndex + query.length);
    final after = text.substring(matchIndex + query.length);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        children: [
          if (before.isNotEmpty)
            TextSpan(
              text: before,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          TextSpan(
            text: match,
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
          if (after.isNotEmpty)
            TextSpan(
              text: after,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _controller.text;
    final isQueryEmpty = currentText.trim().isEmpty;

    // Lọc trùng: nếu từ khóa gợi ý đã có trong lịch sử thì không hiện lặp
    final filteredSuggestions = _suggestions.where((s) => !_history.contains(s)).toList();
    final hasNoItems = _history.isEmpty && filteredSuggestions.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            key: const Key('search_text_field'),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            onSubmitted: _submitSearch,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tìm kiếm trên VTube',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: currentText.isNotEmpty
                  ? IconButton(
                      key: const Key('search_clear_button'),
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      tooltip: 'Xóa',
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              key: const Key('search_mic_button'),
              icon: const Icon(Icons.mic, size: 22, color: AppColors.textPrimary),
              tooltip: 'Tìm kiếm bằng giọng nói',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceHigh,
                shape: const CircleBorder(),
                minimumSize: const Size(40, 40),
              ),
              onPressed: _onVoiceSearchPressed,
            ),
          ),
        ],
      ),
      body: _loading && _history.isEmpty && filteredSuggestions.isEmpty
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            )
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // 1. Danh sách lịch sử
                for (final item in _history)
                  ListTile(
                    key: Key('history_$item'),
                    leading: const Icon(Icons.history, color: AppColors.textSecondary, size: 20),
                    title: _buildHighlightedText(item, currentText),
                    trailing: IconButton(
                      icon: const Icon(Icons.north_west, color: AppColors.textSecondary, size: 18),
                      tooltip: 'Điền từ khóa',
                      onPressed: () => _fillQuery(item),
                    ),
                    onTap: () => _submitSearch(item),
                    onLongPress: () => _confirmDeleteHistory(item),
                  ),

                // 2. Danh sách gợi ý
                for (final item in filteredSuggestions)
                  ListTile(
                    key: Key('suggestion_$item'),
                    leading: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                    title: _buildHighlightedText(item, currentText),
                    trailing: IconButton(
                      icon: const Icon(Icons.north_west, color: AppColors.textSecondary, size: 18),
                      tooltip: 'Điền từ khóa',
                      onPressed: () => _fillQuery(item),
                    ),
                    onTap: () => _submitSearch(item),
                  ),

                // 3. Nếu đang gõ mà không có kết quả gợi ý nào khớp: hiện 1 dòng "Tìm <query>"
                if (!isQueryEmpty && hasNoItems && !_loading)
                  ListTile(
                    key: const Key('search_fallback_tile'),
                    leading: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                    title: Text(
                      'Tìm "$currentText"',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _submitSearch(currentText),
                  ),
              ],
            ),
    );
  }
}
