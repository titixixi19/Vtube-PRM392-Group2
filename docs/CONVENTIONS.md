# Quy ước code

Mục tiêu: 4 người code mà nhìn như 1 người viết.

## 1. Trước khi commit

```bash
cd mobile
dart format -l 120 lib
flutter analyze        # phải "No issues found!" (cảnh báo info thì sửa nếu dễ)
```

## 2. Đặt tên

| Thứ | Quy tắc | Ví dụ |
| --- | --- | --- |
| File | `snake_case.dart` | `video_screen.dart`, `like_button.dart` |
| Class, Widget | `PascalCase` | `VideoScreen`, `LikeButton` |
| Biến, hàm | `camelCase` | `isLoading`, `loadMore()` |
| Biến / widget riêng trong file | thêm `_` ở đầu | `_items`, `_CommentTile` |
| Màn hình | hậu tố `Screen` | `HistoryScreen` |
| Bottom sheet | hàm `showXxxSheet(context, ...)` | `showCommentsSheet` |

Chữ hiển thị viết **tiếng Việt có dấu**, giống thiết kế. Chú thích code viết tiếng Việt hay tiếng Anh đều được, nhưng mỗi file thống nhất một kiểu.

## 3. Cấu trúc trong thư mục của mỗi người

```
features/watch/
├── home_screen.dart          # 1 màn = 1 file chính (tên file đã có sẵn, KHÔNG đổi)
├── video_screen.dart
├── comments_sheet.dart
├── shorts_screen.dart
└── widgets/                  # widget chỉ dùng trong luồng của mình
    ├── video_player_view.dart
    └── action_pill_row.dart
```

File màn hình dài quá ~300 dòng thì tách widget con ra `widgets/`.

## 4. Luật bắt buộc

| Đừng | Hãy |
| --- | --- |
| `Color(0xFF...)`, `Colors.red` trong màn hình | `AppColors.accent`, `AppColors.textSecondary` |
| `context.push('/video/$id')` | `context.push(AppRoutes.video(id))` |
| `Dio().get(...)`, `http.get(...)` | `context.read<VideoService>().feed(...)` |
| `Image.network(url)` | `AppNetworkImage(url: url)` (có cache, tự ghép URL tương đối) |
| Tự viết "1,2 Tr lượt xem", "3 ngày trước" | `Fmt.views(n)`, `Fmt.timeAgo(iso)`, `Fmt.duration(s)` |
| `print(...)` | `debugPrint(...)`, và xóa trước khi PR |
| Tự viết card video | `VideoCardLarge`, `VideoCardCompact`, `ShortsShelf` |
| Tự kiểm tra đăng nhập rồi push màn login | `if (!await requireLogin(context)) return;` |
| Dùng `context` sau `await` mà không kiểm tra | `if (!mounted) return;` (trong State) hoặc `if (!context.mounted) return;` |
| Quên `dispose()` controller | Mọi `TextEditingController`, `ScrollController`, `VideoPlayerController`, `Timer` đều phải dispose |

## 5. Gọi API và xử lý lỗi

Mọi service ném ra `ApiException`, trong đó `e.message` là tiếng Việt và hiện thẳng lên được.

```dart
try {
  final res = await context.read<VideoService>().react(video.id, 1);
  setState(() => _video = _video.copyWith(likeCount: res.likeCount));
} on ApiException catch (e) {
  if (mounted) showSnack(context, e.message);
}
```

**Optimistic update** cho Like, Đăng ký, Lưu: đổi giao diện trước, gọi API sau, lỗi thì trả lại như cũ.

```dart
Future<void> _toggleSubscribe() async {
  if (!await requireLogin(context)) return;
  final before = _subscribed;
  setState(() => _subscribed = !before);
  try {
    final channels = context.read<ChannelService>();
    before ? await channels.unsubscribe(_channel.id) : await channels.subscribe(_channel.id);
  } on ApiException catch (e) {
    if (!mounted) return;
    setState(() => _subscribed = before);
    showSnack(context, e.message);
  }
}
```

## 6. Mẫu màn danh sách có phân trang

Dùng cho Trang chủ, Kết quả tìm kiếm, Lịch sử, Thông báo, tab Video của kênh... Copy rồi đổi kiểu dữ liệu và hàm gọi API.

```dart
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scroll = ScrollController();
  final _items = <HistoryItem>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Còn cách đáy ~3 item thì tải trang tiếp
      if (_scroll.position.extentAfter < 500) _loadMore();
    });
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final res = await context.read<HistoryService>().list(page: _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _hasMore = res.hasMore;
        _page++;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_items.isEmpty && _loading) {
      body = const LoadingView();
    } else if (_items.isEmpty && _error != null) {
      body = ErrorView(message: _error!, onRetry: _refresh);
    } else if (_items.isEmpty) {
      body = const EmptyView(icon: Icons.history, title: 'Nhật ký xem của bạn sẽ xuất hiện tại đây');
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scroll,
          itemCount: _items.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == _items.length) {
              return const Padding(padding: EdgeInsets.all(16), child: LoadingView());
            }
            final item = _items[i];
            return VideoCardCompact(
              video: item.video,
              progress: item.progress,
              onTap: () => context.push(AppRoutes.video(item.video.id)),
            );
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('Nhật ký xem')), body: body);
  }
}
```

## 7. Màn cần đăng nhập

| Màn | Khi là khách |
| --- | --- |
| 4 Bạn, 12 Kênh đăng ký, 13 Lịch sử, 16 Thông báo | Hiện `EmptyView` có nút "Đăng nhập" → `context.push(AppRoutes.login)` |
| 15 Tải lên | Không mở được (nút (+) đã gọi `requireLogin`) |
| Các nút Like, Đăng ký, Bình luận, Lưu | Gọi `requireLogin(context)` trước |

Theo dõi trạng thái đăng nhập bằng `context.watch<AuthProvider>().isLoggedIn`. Màn sẽ tự build lại khi người dùng vừa đăng nhập xong.

## 8. Backend (khi cần thêm API)

- Một nhóm chức năng = một package (`video`, `comment`...) gồm `XxxController` (nhận request) và `XxxService` (SQL qua `Db`).
- SQL viết tay bằng `NamedParameterJdbcTemplate`, tham số dạng `:ten`. **Không** nối chuỗi giá trị người dùng vào SQL.
- Lỗi thì ném `ApiException.badRequest("...")`, `notFound("...")`, `forbidden()`. Message viết tiếng Việt.
- API cần đăng nhập: gọi `Auth.requireUserId()`. API cho cả khách: dùng `Auth.userId()` (có thể `null`).
- Thêm hoặc sửa API thì **cập nhật `docs/API.md` trong cùng PR**.
- Đổi cấu trúc bảng: sửa `schema.sql` (chỉ **thêm** cột hoặc bảng), báo nhóm xóa `vtube.db` để tạo lại.
