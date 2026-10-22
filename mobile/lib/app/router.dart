import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/explore/channel_screen.dart';
import '../features/explore/search_results_screen.dart';
import '../features/explore/search_screen.dart';
import '../features/explore/subscriptions_screen.dart';
import '../features/library/history_screen.dart';
import '../features/library/notifications_screen.dart';
import '../features/library/playlist_screen.dart';
import '../features/library/upload_screen.dart';
import '../features/watch/home_screen.dart';
import '../features/watch/shorts_screen.dart';
import '../features/watch/video_screen.dart';
import 'main_shell.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bảng định tuyến. File dùng chung: muốn thêm màn mới, tạo PR riêng và báo cả nhóm (xem CONTRIBUTING.md).
GoRouter buildRouter() => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppRoutes.splash,
      routes: [
        GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
        GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
        GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),

        // ---- 4 tab có bottom nav ----
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.shorts, builder: (context, state) {
                final start = int.tryParse(state.uri.queryParameters['start'] ?? '');
                return ShortsScreen(key: ValueKey('shorts-$start'), startVideoId: start);
              }),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.subscriptions, builder: (context, state) => const SubscriptionsScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.you, builder: (context, state) => const AccountScreen()),
            ]),
          ],
        ),

        // ---- Màn chi tiết: đè lên bottom nav ----
        GoRoute(
          path: '/video/:id',
          builder: (context, state) => VideoScreen(videoId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) => SearchScreen(initialQuery: state.uri.queryParameters['q']),
        ),
        GoRoute(
          path: '/search/results',
          builder: (context, state) => SearchResultsScreen(query: state.uri.queryParameters['q'] ?? ''),
        ),
        GoRoute(
          path: '/channel/:id',
          builder: (context, state) => ChannelScreen(channelId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(path: AppRoutes.history, builder: (context, state) => const HistoryScreen()),
        GoRoute(
          path: '/playlist/:id',
          builder: (context, state) => PlaylistScreen(playlistId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: AppRoutes.upload,
          builder: (context, state) => UploadScreen(isShort: state.uri.queryParameters['short'] == '1'),
        ),
        GoRoute(path: AppRoutes.notifications, builder: (context, state) => const NotificationsScreen()),
      ],
    );
