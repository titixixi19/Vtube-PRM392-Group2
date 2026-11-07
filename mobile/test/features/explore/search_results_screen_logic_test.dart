import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/core/network/api_exception.dart';
import 'package:vtube/data/models/models.dart';

import 'search_test_helpers.dart';

void main() {
  group('Màn 10 - Logic Nghiệp vụ Kết quả tìm kiếm', () {
    late FakeSearchService searchService;
    late FakeChannelService channelService;

    setUp(() {
      searchService = FakeSearchService();
      channelService = FakeChannelService();
    });

    testWidgets('Mở màn hình: tự động gọi API tìm kiếm trang 0 với bộ lọc mặc định', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      expect(searchService.searchCalls, 1);
      expect(searchService.lastSearchQuery, 'flutter');
      expect(searchService.lastSearchPage, 0);
      expect(searchService.lastSearchFilters?.type, 'all');
      expect(searchService.lastSearchFilters?.isDefault, isTrue);

      // Có thẻ kênh, video
      expect(find.byKey(const Key('channel_card_1')), findsOneWidget);
      expect(find.byKey(const Key('video_card_1')), findsOneWidget);

      // Cuộn để thấy kệ shorts và thẻ playlist
      await tester.scrollUntilVisible(
        find.byKey(const Key('search_shorts_shelf')),
        200,
        scrollable: findMainVerticalScrollable(),
      );
      expect(find.byKey(const Key('search_shorts_shelf')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('playlist_card_1')),
        300,
        scrollable: findMainVerticalScrollable(),
      );
      expect(find.byKey(const Key('playlist_card_1')), findsOneWidget);
    });

    testWidgets('Chọn chip loại: cập nhật filter và tải lại từ trang 0', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      final callsBefore = searchService.searchCalls;

      // Bấm chip "Kênh"
      await tester.tap(find.text('Kênh'));
      await tester.pumpAndSettle();

      expect(searchService.searchCalls, callsBefore + 1);
      expect(searchService.lastSearchFilters?.type, 'channel');
      expect(searchService.lastSearchPage, 0);
    });

    testWidgets('Mở bottom sheet bộ lọc, chọn các tiêu chí và bấm Áp dụng', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      // Mở bottom sheet bộ lọc
      await tester.tap(find.byKey(const Key('search_filter_button')));
      await tester.pumpAndSettle();

      // Chọn Ngày tải lên: Hôm nay
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();

      // Chọn Thời lượng: Trên 20 phút
      await tester.tap(find.text('Trên 20 phút'));
      await tester.pumpAndSettle();

      // Chọn Sắp xếp: Lượt xem
      await tester.tap(find.text('Lượt xem'));
      await tester.pumpAndSettle();

      // Bấm Áp dụng
      await tester.ensureVisible(find.byKey(const Key('filter_apply_button')));
      await tester.tap(find.byKey(const Key('filter_apply_button')));
      await tester.pumpAndSettle();

      expect(searchService.lastSearchFilters?.uploadDate, 'today');
      expect(searchService.lastSearchFilters?.duration, 'long');
      expect(searchService.lastSearchFilters?.sort, 'views');
      expect(searchService.lastSearchFilters?.isDefault, isFalse);

      // Icon bộ lọc có chấm đỏ
      expect(find.byKey(const Key('filter_active_dot')), findsOneWidget);
    });

    testWidgets('Bấm Đặt lại trong bộ lọc: trả về bộ lọc mặc định', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      // Mở filter và chọn vài tiêu chí
      await tester.tap(find.byKey(const Key('search_filter_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tuần này'));
      await tester.pumpAndSettle();

      // Bấm Đặt lại
      await tester.ensureVisible(find.byKey(const Key('filter_reset_button')));
      await tester.tap(find.byKey(const Key('filter_reset_button')));
      await tester.pumpAndSettle();

      // Bấm Áp dụng
      await tester.ensureVisible(find.byKey(const Key('filter_apply_button')));
      await tester.tap(find.byKey(const Key('filter_apply_button')));
      await tester.pumpAndSettle();

      expect(searchService.lastSearchFilters?.isDefault, isTrue);
      expect(find.byKey(const Key('filter_active_dot')), findsNothing);
    });

    testWidgets('Trạng thái không có kết quả: hiện EmptyView với thông báo', (tester) async {
      searchService.returnSearchResult = const SearchResult(
        channels: [],
        videos: [],
        shorts: [],
        playlists: [],
        page: 0,
        hasMore: false,
      );

      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'từ khóa lạ không có',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy kết quả nào cho "từ khóa lạ không có"'), findsOneWidget);
      expect(find.text('Hãy thử từ khóa khác hoặc bỏ bộ lọc'), findsOneWidget);
    });

    testWidgets('Trạng thái lỗi: hiện ErrorView và nút Thử lại hoạt động', (tester) async {
      searchService.searchError = const ApiException('Lỗi máy chủ tìm kiếm');

      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Lỗi máy chủ tìm kiếm'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Hết lỗi và bấm Thử lại
      searchService.searchError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(searchService.searchCalls, 2);
      expect(find.byKey(const Key('channel_card_1')), findsOneWidget);
    });

    testWidgets('Bấm Đăng ký kênh trên thẻ kênh: gọi ChannelService', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        channelService: channelService,
        query: 'flutter',
        isLoggedIn: true,
      ));
      await tester.pumpAndSettle();

      // Bấm Đăng ký trên thẻ kênh
      await tester.tap(find.byKey(const Key('channel_card_subscribe_button')));
      await tester.pumpAndSettle();

      expect(channelService.subscribeCalls, 1);
      expect(channelService.lastChannelId, 1);
    });

    testWidgets('Kéo xuống làm mới (pull to refresh) gọi lại trang 0', (tester) async {
      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      expect(searchService.searchCalls, 1);

      // Kéo RefreshIndicator
      await tester.fling(find.byKey(const Key('search_results_list_view')), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(searchService.searchCalls, 2);
      expect(searchService.lastSearchPage, 0);
    });

    testWidgets('Response cũ đè lên response mới (race condition): kết quả cũ về sau không đè kết quả mới',
        (tester) async {
      final compChannel = Completer<SearchResult>();
      final compVideo = Completer<SearchResult>();

      searchService.searchCompleters['channel'] = compChannel;
      searchService.searchCompleters['video'] = compVideo;

      await tester.pumpWidget(buildTestSearchResultsScreen(
        searchService: searchService,
        query: 'flutter',
      ));
      await tester.pumpAndSettle();

      // Đổi sang tab Kênh (bắt đầu request 1 cho channel)
      await tester.tap(find.text('Kênh'));
      await tester.pump();

      // Đổi tiếp sang tab Video (bắt đầu request 2 cho video)
      await tester.tap(find.text('Video'));
      await tester.pump();

      // Request 2 (video) trả về trước
      compVideo.complete(SearchResult(
        channels: [],
        videos: [testVideo(id: 99, title: 'Video Mới Nhất')],
        shorts: [],
        playlists: [],
        page: 0,
        hasMore: false,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Video Mới Nhất'), findsOneWidget);

      // Request 1 (channel) về sau request 2
      compChannel.complete(SearchResult(
        channels: [testChannel(id: 88, name: 'Kênh Cũ Về Sau')],
        videos: [],
        shorts: [],
        playlists: [],
        page: 0,
        hasMore: false,
      ));
      await tester.pumpAndSettle();

      // Kết quả cũ của channel bị bỏ qua, vẫn giữ video mới
      expect(find.text('Video Mới Nhất'), findsOneWidget);
      expect(find.text('Kênh Cũ Về Sau'), findsNothing);
    });
  });
}
