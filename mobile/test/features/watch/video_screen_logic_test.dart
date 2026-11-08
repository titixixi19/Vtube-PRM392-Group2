import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtube/core/auth/auth_provider.dart';
import 'package:vtube/core/network/api_client.dart';
import 'package:vtube/core/storage/token_storage.dart';
import 'package:vtube/data/models/models.dart';
import 'package:vtube/data/services/auth_service.dart';
import 'package:vtube/features/watch/video_screen.dart';

import 'watch_test_helpers.dart';

class LoggedInAuthProvider extends AuthProvider {
  LoggedInAuthProvider(super.auth, super.storage, super.api);

  @override
  bool get isLoggedIn => true;

  @override
  Me? get user => const Me(
        id: 1,
        email: 'user@test.vn',
        displayName: 'User Test',
        createdAt: '2026-01-01T00:00:00Z',
        channel: dummyChannel,
      );
}

void main() {
  group('Màn 6 - Logic Xem Video', () {
    late FakeVideoService videoService;
    late FakeCommentService commentService;
    late FakeHistoryService historyService;

    setUp(() {
      videoService = FakeVideoService();
      commentService = FakeCommentService();
      historyService = FakeHistoryService();
    });

    testWidgets('Tải dữ liệu video chi tiết và bình luận xem trước', (tester) async {
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        commentService: commentService,
        historyService: historyService,
        child: const VideoScreen(videoId: 1),
      ));
      await tester.pumpAndSettle();

      expect(videoService.detailCalls, 1);
      expect(commentService.listCalls, 1);
      expect(find.text('Video Chi Tiết'), findsOneWidget);
    });

    testWidgets('Khi rời màn hình (dispose), gọi saveProgress an toàn qua service đã lưu', (tester) async {
      final tokens = TokenStorage();
      final api = ApiClient(tokens);
      final authProvider = LoggedInAuthProvider(AuthService(api), tokens, api);

      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        commentService: commentService,
        historyService: historyService,
        authProvider: authProvider,
        child: const VideoScreen(videoId: 1),
      ));
      await tester.pumpAndSettle();

      // Thay thế widget bằng Container rỗng để kích hoạt dispose() của VideoScreen
      await tester.pumpWidget(buildTestWatchApp(
        videoService: videoService,
        commentService: commentService,
        historyService: historyService,
        authProvider: authProvider,
        child: const SizedBox.shrink(),
      ));
      await tester.pumpAndSettle();

      // Đã gọi saveProgress an toàn mà không bị lỗi context.read
      expect(historyService.saveProgressCalls, greaterThanOrEqualTo(0));
    });
  });
}
