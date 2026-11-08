import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';

/// Trình phát video độc lập tỉ lệ 16:9 sử dụng video_player và chewie.
class VideoPlayerView extends StatefulWidget {
  final String videoUrl;
  final int initialProgressSeconds;
  final VoidCallback? onStarted;
  final void Function(int seconds)? onProgress;

  const VideoPlayerView({
    super.key,
    required this.videoUrl,
    this.initialProgressSeconds = 0,
    this.onStarted,
    this.onProgress,
  });

  @override
  State<VideoPlayerView> createState() => VideoPlayerViewState();
}

class VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasCalledStarted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeControllers();
      _hasCalledStarted = false;
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    final resolvedUrl = ApiConfig.resolveUrl(widget.videoUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Đường dẫn video không hợp lệ';
      });
      return;
    }

    try {
      final uri = Uri.parse(resolvedUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _videoPlayerController = controller;

      await controller.initialize();

      if (!mounted) return;

      if (widget.initialProgressSeconds > 0 &&
          widget.initialProgressSeconds < controller.value.duration.inSeconds) {
        await controller.seekTo(Duration(seconds: widget.initialProgressSeconds));
      }

      controller.addListener(_videoListener);

      final chewie = ChewieController(
        videoPlayerController: controller,
        aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
        autoPlay: true,
        looping: false,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
        allowFullScreen: true,
        deviceOrientationsOnEnterFullScreen: const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: const [
          DeviceOrientation.portraitUp,
        ],
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
      );

      _chewieController = chewie;

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Không thể phát video này';
      });
    }
  }

  void _videoListener() {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying && !_hasCalledStarted) {
      _hasCalledStarted = true;
      widget.onStarted?.call();
    }

    widget.onProgress?.call(controller.value.position.inSeconds);
  }

  int get currentPositionSeconds => _videoPlayerController?.value.position.inSeconds ?? 0;

  void _disposeControllers() {
    _videoPlayerController?.removeListener(_videoListener);
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: _hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Lỗi phát video',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          _disposeControllers();
                          setState(() {
                            _hasError = false;
                            _isInitialized = false;
                          });
                          _initPlayer();
                        },
                        child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              )
            : _isInitialized && _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
      ),
    );
  }
}
