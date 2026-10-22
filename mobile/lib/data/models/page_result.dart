import 'json_utils.dart';

/// { items, page, size, hasMore } — tải trang tiếp khi hasMore = true.
class PageResult<T> {
  final List<T> items;
  final int page;
  final int size;
  final bool hasMore;

  const PageResult({required this.items, required this.page, required this.size, required this.hasMore});

  factory PageResult.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) fromJson) => PageResult(
        items: asList(j['items'], fromJson),
        page: asInt(j['page']),
        size: asInt(j['size'], 20),
        hasMore: asBool(j['hasMore']),
      );
}
