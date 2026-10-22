import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_provider.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../data/services/auth_service.dart';
import '../data/services/channel_service.dart';
import '../data/services/comment_service.dart';
import '../data/services/history_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/playlist_service.dart';
import '../data/services/search_service.dart';
import '../data/services/upload_service.dart';
import '../data/services/video_service.dart';
import 'router.dart';
import 'theme.dart';

/// Gốc ứng dụng: tạo ApiClient, các service và AuthProvider một lần,
/// rồi cung cấp cho mọi màn qua Provider:
///
///   final videos = context.read<VideoService>();
///   final auth = context.watch<AuthProvider>();
class VtubeApp extends StatefulWidget {
  const VtubeApp({super.key});

  @override
  State<VtubeApp> createState() => _VtubeAppState();
}

class _VtubeAppState extends State<VtubeApp> {
  late final TokenStorage _tokens = TokenStorage();
  late final ApiClient _api = ApiClient(_tokens);
  late final AuthProvider _auth = AuthProvider(AuthService(_api), _tokens, _api);
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _api),
        Provider(create: (_) => AuthService(_api)),
        Provider(create: (_) => VideoService(_api)),
        Provider(create: (_) => CommentService(_api)),
        Provider(create: (_) => ChannelService(_api)),
        Provider(create: (_) => SearchService(_api)),
        Provider(create: (_) => HistoryService(_api)),
        Provider(create: (_) => PlaylistService(_api)),
        Provider(create: (_) => NotificationService(_api)),
        Provider(create: (_) => UploadService(_api)),
        ChangeNotifierProvider.value(value: _auth),
      ],
      child: MaterialApp.router(
        title: 'VTube',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      ),
    );
  }
}
