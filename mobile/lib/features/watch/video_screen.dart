import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/comment_service.dart';
import '../../data/services/history_service.dart';
import '../../data/services/video_service.dart';
import '../../shared/widgets/state_views.dart';
import 'comments_sheet.dart';
import 'widgets/related_videos_section.dart';
import 'widgets/video_info_section.dart';
import 'widgets/video_player_view.dart';

/// MÀN 6 · XEM VIDEO · Người 2
class VideoScreen extends StatefulWidget {
  final int videoId;

  const VideoScreen({super.key, required this.videoId});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final _playerKey = GlobalKey<VideoPlayerViewState>();
  Video? _video;
  Comment? _previewComment;
  bool _loading = true;
  String? _error;

  Timer? _progressTimer;
  int _lastSavedSeconds = 0;
  int _currentPositionSeconds = 0;
  HistoryService? _historyService;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadVideoData();
    _startProgressTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _historyService = context.read<HistoryService>();
    _isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
  }

  @override
  void didUpdateWidget(covariant VideoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _saveProgressDirect(oldWidget.videoId, _currentPositionSeconds);
      _currentPositionSeconds = 0;
      _lastSavedSeconds = 0;
      _loadVideoData();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    if (_currentPositionSeconds > 0) {
      _saveProgressDirect(widget.videoId, _currentPositionSeconds);
    }
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_currentPositionSeconds > 0) {
        _saveProgressDirect(widget.videoId, _currentPositionSeconds);
      }
    });
  }

  void _saveProgressDirect(int videoId, int seconds) {
    if (!_isLoggedIn || _historyService == null) return;
    // Tối thiểu 1 giây để đảm bảo xem dưới 10s rồi Back vẫn vào lịch sử
    final progressToSave = seconds > 0 ? seconds : 1;
    if (progressToSave == _lastSavedSeconds) return;

    _lastSavedSeconds = progressToSave;
    _historyService!.saveProgress(videoId, progressToSave).catchError((_) => false);
  }

  Future<void> _loadVideoData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final videoService = context.read<VideoService>();
      final commentService = context.read<CommentService>();

      // Tải song song thông tin video và 1 bình luận xem trước
      final results = await Future.wait([
        videoService.detail(widget.videoId),
        commentService.list(widget.videoId, size: 1).catchError((_) => const PageResult<Comment>(
              items: [],
              page: 0,
              size: 1,
              hasMore: false,
            )),
      ]);

      if (!mounted) return;

      final video = results[0] as Video;
      final comments = results[1] as PageResult<Comment>;

      setState(() {
        _video = video;
        _previewComment = comments.items.isNotEmpty ? comments.items.first : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404 ? 'Video này không còn khả dụng' : e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải video. Vui lòng thử lại';
        _loading = false;
      });
    }
  }

  void _onVideoStarted() async {
    // Đánh dấu ít nhất 1 giây để nếu người dùng Back ngay vẫn lưu lịch sử
    if (_currentPositionSeconds == 0) {
      _currentPositionSeconds = 1;
    }
    try {
      await context.read<VideoService>().addView(widget.videoId);
    } catch (_) {
      // Bỏ qua lỗi tăng view
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const LoadingView(),
      );
    }

    if (_error != null || _video == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: _error ?? 'Video này không còn khả dụng',
          onRetry: _loadVideoData,
        ),
      );
    }

    final video = _video!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Trình phát video cố định trên cùng (16:9)
            VideoPlayerView(
              key: _playerKey,
              videoUrl: video.videoUrl,
              initialProgressSeconds: video.viewer?.progressSeconds ?? 0,
              onStarted: _onVideoStarted,
              onProgress: (seconds) => _currentPositionSeconds = seconds,
            ),
            // Phần cuộn bên dưới: thông tin, tương tác, gợi ý
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VideoInfoSection(
                      video: video,
                      previewComment: _previewComment,
                      onOpenComments: () => showCommentsSheet(
                        context,
                        video.id,
                        channelId: video.channel.id,
                        commentsEnabled: video.commentsEnabled,
                        totalCommentCount: video.commentCount,
                      ),
                    ),
                    const Divider(height: 1),
                    RelatedVideosSection(videoId: video.id),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
