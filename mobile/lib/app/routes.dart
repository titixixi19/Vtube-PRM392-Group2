/// Tất cả đường dẫn trong app. Dùng: context.push(AppRoutes.video(12));
class AppRoutes {
  AppRoutes._();

  // Không có bottom nav
  static const splash = '/splash'; // Màn 1
  static const login = '/login'; // Màn 2
  static const register = '/register'; // Màn 3

  // 4 tab có bottom nav (tab (+) Tạo mở bottom sheet, không phải route)
  static const home = '/home'; // Màn 5
  static const shorts = '/shorts'; // Màn 8  (?start=<videoId>)
  static const subscriptions = '/subscriptions'; // Màn 12
  static const you = '/you'; // Màn 4

  // Màn chi tiết (đè lên bottom nav)
  static const search = '/search'; // Màn 9
  static const history = '/history'; // Màn 13
  static const notifications = '/notifications'; // Màn 16
  static const upload = '/upload'; // Màn 15 (?short=1)

  static String video(int id) => '/video/$id'; // Màn 6 (Màn 7 là bottom sheet trong màn 6)
  static String shortsAt(int videoId) => '$shorts?start=$videoId';
  static String searchResults(String q) => '/search/results?q=${Uri.encodeQueryComponent(q)}'; // Màn 10
  static String channel(int id) => '/channel/$id'; // Màn 11
  static String playlist(int id) => '/playlist/$id'; // Màn 14
  static String uploadShort() => '$upload?short=1';
}
