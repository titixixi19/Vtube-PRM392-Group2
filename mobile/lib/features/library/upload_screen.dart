import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/services/playlist_service.dart';
import '../../data/services/upload_service.dart';
import '../../data/services/video_service.dart';
import 'widgets/upload_setting_sheets.dart';

typedef ExtractThumbnail = Future<String?> Function(String videoPath, {int timeMs});

Future<String?> _defaultExtractThumbnail(String videoPath, {int timeMs = 1000}) async {
  return VideoThumbnail.thumbnailFile(
    video: videoPath,
    imageFormat: ImageFormat.JPEG,
    timeMs: timeMs,
    quality: 80,
  );
}

/// MÀN 15 · TẢI VIDEO LÊN · Người 4
/// Luồng: chọn video (image_picker: pickVideo) -> UploadService.upload(path, type: 'video', onProgress:)
///        -> (tùy chọn) upload thumbnail type: 'image' -> VideoService.create(title:, videoUrl:, ...)
class UploadScreen extends StatefulWidget {
  final bool isShort;
  final PickVideoFile? pickVideo;
  final PickImageFile? pickImage;
  final ExtractThumbnail? extractThumbnail;

  const UploadScreen({
    super.key,
    this.isShort = false,
    this.pickVideo,
    this.pickImage,
    this.extractThumbnail,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late bool _isShort;
  XFile? _videoFile;
  XFile? _thumbnailFile;
  bool _hasCustomThumbnail = false;
  VideoPlayerController? _videoController;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagInputController = TextEditingController();

  int _durationSeconds = 0;
  String _visibility = 'public';
  bool _madeForKids = false;
  bool _commentsEnabled = true;
  Category? _selectedCategory;
  final _selectedPlaylistIds = <int>{};
  final _tags = <String>[];

  List<Category> _categories = [];
  List<Playlist> _myPlaylists = [];

  bool _uploading = false;
  double _uploadProgress = 0.0;
  bool _uploadFailed = false;
  String? _uploadError;
  CancelToken? _cancelToken;
  bool _isCancelled = false;
  String? _uploadedVideoUrl;
  String? _uploadedThumbnailUrl;

  bool get _isCreatingRecord => _uploading && _uploadProgress >= 0.95;
  bool? _lastLoggedIn;

  @override
  void initState() {
    super.initState();
    _isShort = widget.isShort;
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (_lastLoggedIn != loggedIn) {
      _lastLoggedIn = loggedIn;
      if (loggedIn) {
        _loadAuxiliaryData();
      } else {
        setState(() {
          _myPlaylists = [];
          _selectedPlaylistIds.clear();
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagInputController.dispose();
    _videoController?.dispose();
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _loadAuxiliaryData() async {
    final videoService = context.read<VideoService>();
    final playlistService = context.read<PlaylistService>();

    try {
      final categories = await videoService.categories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {}

    try {
      final playlists = await playlistService.mine();
      if (mounted) {
        setState(() => _myPlaylists = playlists.where((p) => p.kind != 'liked').toList());
      }
    } catch (_) {}
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picker = widget.pickVideo != null ? widget.pickVideo!(source) : ImagePicker().pickVideo(source: source);
      final picked = await picker;
      if (picked == null || !mounted) return;

      try {
        final file = File(picked.path);
        final fileSize = file.existsSync() ? file.lengthSync() : null;
        if (fileSize != null && fileSize > 500 * 1024 * 1024) {
          if (!mounted) return;
          showSnack(context, 'Tệp quá lớn. Giới hạn dung lượng là 500MB.');
          return;
        }
      } catch (_) {}

      // Reset cached URLs because a new video file is selected
      _uploadedVideoUrl = null;
      _uploadedThumbnailUrl = null;

      setState(() {
        _videoFile = picked;
        if (!_hasCustomThumbnail) {
          _thumbnailFile = null;
        }
      });
      _loadAuxiliaryData();

      VideoPlayerController? controller;
      int durationMs = 0;
      try {
        controller = VideoPlayerController.file(File(picked.path));
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          return;
        }
        _videoController?.dispose();
        setState(() {
          _videoController = controller;
          _durationSeconds = controller!.value.duration.inSeconds;
        });
        durationMs = controller.value.duration.inMilliseconds;

        // Tự động gợi ý Short nếu video ngắn <= 60s và có tỉ lệ dọc (có tính rotationCorrection)
        final rot = controller.value.rotationCorrection;
        final rawRatio = controller.value.aspectRatio;
        final isRotated = rot == 90 || rot == 270;
        final effectiveRatio = isRotated && rawRatio > 0 ? (1.0 / rawRatio) : rawRatio;

        if (!_isShort && _durationSeconds > 0 && _durationSeconds <= 60 && effectiveRatio < 1.0) {
          _promptSuggestShort();
        }
      } catch (_) {
        controller?.dispose();
        _videoController?.dispose();
        if (mounted) {
          setState(() {
            _videoController = null;
            _durationSeconds = 0;
          });
          showSnack(context, 'Không thể phát video đã chọn');
        }
      }

      if (!_hasCustomThumbnail) {
        String? thumbPath;
        try {
          // Tính toán offset khung hình an toàn không bằng 0
          int targetTimeMs = 1000;
          if (durationMs > 0 && durationMs < 1000) {
            targetTimeMs = (durationMs ~/ 2).clamp(1, durationMs);
          }

          final extractor = widget.extractThumbnail ?? _defaultExtractThumbnail;
          thumbPath = await extractor(picked.path, timeMs: targetTimeMs);
        } catch (_) {}

        if (thumbPath != null && !_hasCustomThumbnail && mounted) {
          setState(() {
            _thumbnailFile = XFile(thumbPath!);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Không thể chọn video');
    }
  }

  void _promptSuggestShort() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tải lên dưới dạng Short?'),
        content: const Text(
          'Video của bạn dưới 60 giây và có khung hình dọc. Bạn có muốn chuyển sang tải lên dưới dạng Shorts không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Giữ video thường'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isShort = true);
            },
            child: const Text('Tải dạng Short'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickThumbnail() async {
    try {
      final picker = widget.pickImage != null
          ? widget.pickImage!(ImageSource.gallery)
          : ImagePicker().pickImage(source: ImageSource.gallery);
      final picked = await picker;
      if (picked == null || !mounted) return;
      setState(() {
        _thumbnailFile = picked;
        _hasCustomThumbnail = true;
        _uploadedThumbnailUrl = null;
      });
    } catch (_) {
      if (!mounted) return;
      showSnack(context, 'Không thể chọn hình thu nhỏ');
    }
  }

  void _addTag(String raw) {
    final clean = raw.trim().replaceAll(',', '');
    if (clean.isNotEmpty && !_tags.contains(clean)) {
      setState(() {
        _tags.add(clean);
        _tagInputController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _startUpload() async {
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    if (_titleController.text.trim().isEmpty || _videoFile == null) return;

    final uploadService = context.read<UploadService>();
    final videoService = context.read<VideoService>();
    final playlistService = context.read<PlaylistService>();
    final authProvider = context.read<AuthProvider>();

    _isCancelled = false;
    _cancelToken = CancelToken();

    setState(() {
      _uploading = true;
      _uploadProgress = 0.05;
      _uploadFailed = false;
      _uploadError = null;
    });

    try {
      // 1. Tải lên tệp video nếu chưa có URL đã tải (chiếm 80% tiến độ)
      if (_uploadedVideoUrl == null) {
        final videoRes = await uploadService.upload(
          _videoFile!.path,
          type: 'video',
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = 0.05 + (p * 0.75));
          },
          cancelToken: _cancelToken,
        );
        _uploadedVideoUrl = videoRes.url;
      }

      if (_cancelToken?.isCancelled == true || _isCancelled || !mounted) return;

      // 2. Tải lên ảnh thumbnail nếu có và chưa có URL (chiếm 15% tiến độ)
      if (_thumbnailFile != null && _uploadedThumbnailUrl == null) {
        final thumbRes = await uploadService.upload(
          _thumbnailFile!.path,
          type: 'image',
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = 0.80 + (p * 0.15));
          },
          cancelToken: _cancelToken,
        );
        _uploadedThumbnailUrl = thumbRes.url;
      }

      if (_cancelToken?.isCancelled == true || _isCancelled || !mounted) return;
      setState(() => _uploadProgress = 0.95);

      // 3. Tạo bản ghi video
      final desc = _descController.text.trim();
      final created = await videoService.create(
        title: _titleController.text.trim(),
        description: desc.isEmpty ? null : desc,
        thumbnailUrl: _uploadedThumbnailUrl,
        videoUrl: _uploadedVideoUrl!,
        durationSeconds: _durationSeconds,
        categoryId: _selectedCategory?.id,
        isShort: _isShort,
        visibility: _visibility,
        commentsEnabled: _commentsEnabled,
        madeForKids: _madeForKids,
        tags: _tags.isEmpty ? null : _tags.join(','),
      );

      // 4. Thêm vào các playlist đã chọn
      for (final plId in _selectedPlaylistIds) {
        if (!mounted) return;
        try {
          await playlistService.addVideo(plId, created.id);
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _uploadProgress = 1.0;
        _uploading = false;
      });

      showSnack(context, 'Video đã được tải lên');
      final myChannelId = authProvider.user?.channel.id;
      if (myChannelId != null) {
        context.go(AppRoutes.channel(myChannelId));
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (_cancelToken?.isCancelled == true || _isCancelled) {
        return;
      }
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Tải lên thất bại. Vui lòng thử lại sau.';
      setState(() {
        _uploading = false;
        _uploadFailed = true;
        _uploadError = msg;
      });
      showSnack(context, msg);
    }
  }

  Future<bool> _cancelUpload() async {
    if (_isCreatingRecord) {
      if (mounted) {
        showSnack(context, 'Đang tạo bản ghi video, không thể hủy lúc này');
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy tải lên?'),
        content: const Text('Tiến trình tải lên video hiện tại sẽ bị hủy bỏ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tiếp tục tải')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hủy tải lên'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (!_uploading) return false;
      if (_isCreatingRecord) {
        showSnack(context, 'Đang tạo bản ghi video, không thể hủy lúc này');
        return false;
      }
      _isCancelled = true;
      _uploadedVideoUrl = null;
      _uploadedThumbnailUrl = null;
      _cancelToken?.cancel();
      setState(() {
        _uploading = false;
        _uploadProgress = 0.0;
      });
      return true;
    }
    return false;
  }

  Future<void> _confirmDiscard() async {
    if (_uploading) {
      if (_isCreatingRecord) {
        showSnack(context, 'Đang tạo bản ghi video, không thể hủy lúc này');
        return;
      }
      final cancelled = await _cancelUpload();
      if (cancelled && mounted) {
        context.pop();
      }
      return;
    }

    final hasContent = _titleController.text.isNotEmpty || _descController.text.isNotEmpty;
    if (hasContent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hủy tải lên?'),
          content: const Text('Mọi thông tin bạn đã nhập sẽ bị mất.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tiếp tục')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Bỏ video'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        context.pop();
      }
    } else {
      context.pop();
    }
  }

  String _visibilityLabel(String vis) {
    switch (vis) {
      case 'unlisted':
        return 'Không công khai';
      case 'private':
        return 'Riêng tư';
      case 'public':
      default:
        return 'Công khai';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_uploading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_uploading) {
          if (_isCreatingRecord) {
            if (context.mounted) {
              showSnack(context, 'Đang tạo bản ghi video, không thể hủy lúc này');
            }
            return;
          }
          final cancelled = await _cancelUpload();
          if (cancelled && context.mounted) {
            context.pop();
          }
        }
      },
      child: _videoFile == null ? _buildPickerScreen() : _buildFormScreen(),
    );
  }

  Widget _buildPickerScreen() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_isShort ? 'Chọn video Short' : 'Chọn video'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isShort ? Icons.slow_motion_video : Icons.upload_file,
                  size: 48,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isShort ? 'Tạo một video Short' : 'Tải video lên kênh của bạn',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chia sẻ câu chuyện và nội dung sáng tạo với cộng đồng người xem trên toàn thế giới.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Chọn từ thư viện'),
                  onPressed: () => _pickVideo(ImageSource.gallery),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Quay video mới'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    minimumSize: const Size(64, 48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => showSnack(context, 'Tính năng đang phát triển'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormScreen() {
    final canSubmit = _titleController.text.trim().isNotEmpty && !_uploading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmDiscard,
        ),
        title: const Text('Thêm thông tin'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: canSubmit ? _startUpload : null,
              child: const Text('Tải lên'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_uploading || _uploadFailed)
              UploadProgressCard(
                progress: _uploadProgress,
                isFailed: _uploadFailed,
                errorMessage: _uploadError,
                onCancel: _isCreatingRecord ? null : _cancelUpload,
                onRetry: _startUpload,
              ),

            // Video Preview & Thumbnail Box
            _buildMediaPreview(),

            const SizedBox(height: 16),

            // Tiêu đề
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Tiêu đề (bắt buộc)',
                  hintText: 'Thêm tiêu đề hấp dẫn...',
                  counterText: '${_titleController.text.length}/100',
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Mô tả
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _descController,
                maxLines: 3,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  hintText: 'Chia sẻ thêm thông tin cho người xem video của bạn...',
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // Các dòng cài đặt
            UploadSettingTile(
              icon: Icons.public,
              title: 'Chế độ hiển thị',
              value: _visibilityLabel(_visibility),
              onTap: () async {
                final selected = await showVisibilityPickerSheet(context, _visibility);
                if (selected != null) {
                  setState(() => _visibility = selected);
                }
              },
            ),
            UploadSettingTile(
              icon: Icons.playlist_add,
              title: 'Danh sách phát',
              value: _selectedPlaylistIds.isEmpty ? 'Không có' : '${_selectedPlaylistIds.length} danh sách',
              onTap: () async {
                if (!await requireLogin(context)) return;
                if (!mounted) return;
                if (_myPlaylists.isEmpty) {
                  await _loadAuxiliaryData();
                  if (!mounted) return;
                }
                final selected = await showUploadPlaylistsSheet(context, _myPlaylists, _selectedPlaylistIds);
                if (selected != null) {
                  setState(() {
                    _selectedPlaylistIds
                      ..clear()
                      ..addAll(selected);
                  });
                }
              },
            ),
            UploadSettingTile(
              icon: Icons.people_outline,
              title: 'Đối tượng người xem',
              value: _madeForKids ? 'Dành cho trẻ em' : 'Không dành cho trẻ em',
              onTap: () async {
                final selected = await showAudiencePickerSheet(context, _madeForKids);
                if (selected != null) {
                  setState(() => _madeForKids = selected);
                }
              },
            ),
            UploadSettingTile(
              icon: Icons.category_outlined,
              title: 'Danh mục nội dung',
              value: _selectedCategory?.name ?? 'Chưa chọn',
              onTap: () async {
                final selected = await showCategoryPickerSheet(context, _categories, _selectedCategory?.id);
                if (selected != null) {
                  setState(() => _selectedCategory = selected);
                }
              },
            ),

            // Thẻ (Tags)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceHigh,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.tag, color: AppColors.textPrimary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Thẻ (tags)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tagInputController,
                    decoration: InputDecoration(
                      hintText: 'Nhập thẻ rồi nhấn Enter (vd: vlog, âm nhạc)...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.link),
                        onPressed: () => _addTag(_tagInputController.text),
                      ),
                    ),
                    onSubmitted: _addTag,
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _tags
                          .map((t) => InputChip(
                                label: Text(t),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => _removeTag(t),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            UploadSettingTile(
              icon: Icons.comment_outlined,
              title: 'Bình luận',
              value: _commentsEnabled ? 'Cho phép' : 'Tắt',
              onTap: () async {
                final selected = await showCommentsPolicySheet(context, _commentsEnabled);
                if (selected != null) {
                  setState(() => _commentsEnabled = selected);
                }
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 220),
      child: AspectRatio(
        aspectRatio: _isShort ? 9 / 16 : 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_videoController != null && _videoController!.value.isInitialized)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_videoController!),
                        IconButton(
                          icon: Icon(
                            _videoController!.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                            size: 48,
                            color: AppColors.textPrimary.withValues(alpha: 0.7),
                          ),
                          onPressed: () {
                            setState(() {
                              _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                )
              else if (_thumbnailFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_thumbnailFile!.path),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Center(
                  child: Icon(Icons.movie, size: 48, color: AppColors.textSecondary),
                ),

              // Nút Đổi hình thu nhỏ
              Positioned(
                left: 10,
                bottom: 10,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.background.withValues(alpha: 0.75),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  label: const Text('Đổi hình thu nhỏ', style: TextStyle(fontSize: 12)),
                  onPressed: _pickThumbnail,
                ),
              ),

              // Thời lượng video
              if (_durationSeconds > 0)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      Fmt.duration(_durationSeconds),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
