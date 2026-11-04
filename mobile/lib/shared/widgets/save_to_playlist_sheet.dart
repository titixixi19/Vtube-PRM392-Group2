import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/playlist_service.dart';

/// Sheet "Lưu vào danh sách phát": danh sách playlist có checkbox + "Danh sách phát mới".
/// Được dùng ở: menu 3 chấm (mọi video) và nút "Lưu" ở màn 6.
Future<void> showSaveToPlaylistSheet(BuildContext context, int videoId) async {
  if (!await requireLogin(context)) return;

  if (!context.mounted) return;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SaveToPlaylistSheet(videoId: videoId),
  );
}

class SaveToPlaylistSheet extends StatefulWidget {
  final int videoId;

  const SaveToPlaylistSheet({super.key, required this.videoId});

  @override
  State<SaveToPlaylistSheet> createState() => _SaveToPlaylistSheetState();
}

class _SaveToPlaylistSheetState extends State<SaveToPlaylistSheet> {
  List<Playlist> _playlists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await context.read<PlaylistService>().mine(videoId: widget.videoId);
      if (!mounted) return;
      setState(() {
        _playlists = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Không thể tải danh sách phát';
      });
    }
  }

  Future<void> _togglePlaylist(Playlist playlist, bool check) async {
    final oldState = playlist.containsVideo == true;
    if (oldState == check) return;

    final index = _playlists.indexWhere((p) => p.id == playlist.id);
    if (index == -1) return;

    final updated = Playlist(
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      visibility: playlist.visibility,
      kind: playlist.kind,
      videoCount: check ? playlist.videoCount + 1 : (playlist.videoCount > 0 ? playlist.videoCount - 1 : 0),
      thumbnailUrl: playlist.thumbnailUrl,
      updatedAt: playlist.updatedAt,
      ownerUserId: playlist.ownerUserId,
      ownerName: playlist.ownerName,
      ownerChannelId: playlist.ownerChannelId,
      containsVideo: check,
    );

    setState(() => _playlists[index] = updated);

    try {
      final service = context.read<PlaylistService>();
      if (check) {
        await service.addVideo(playlist.id, widget.videoId);
        if (!mounted) return;
        showSnack(context, 'Đã thêm vào ${playlist.title}');
      } else {
        await service.removeVideo(playlist.id, widget.videoId);
        if (!mounted) return;
        showSnack(context, 'Đã xóa khỏi ${playlist.title}');
      }
    } catch (e) {
      if (!mounted) return;
      // Khôi phục trạng thái cũ khi lỗi
      setState(() => _playlists[index] = playlist);
      showSnack(context, e is ApiException ? e.message : 'Thao tác không thành công');
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    final titleController = TextEditingController();
    var visibility = 'private';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Danh sách phát mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề',
                      hintText: 'Nhập tên danh sách phát...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Quyền riêng tư', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: visibility,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'private',
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Riêng tư'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'unlisted',
                        child: Row(
                          children: [
                            Icon(Icons.link, size: 18),
                            SizedBox(width: 8),
                            Text('Không công khai'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'public',
                        child: Row(
                          children: [
                            Icon(Icons.public, size: 18),
                            SizedBox(width: 8),
                            Text('Công khai'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => visibility = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Tạo'),
              ),
            ],
          );
        },
      ),
    );

    if (created == true && titleController.text.trim().isNotEmpty && mounted) {
      final title = titleController.text.trim();
      try {
        final service = context.read<PlaylistService>();
        final newPl = await service.create(title, visibility: visibility);
        await service.addVideo(newPl.id, widget.videoId);
        if (!mounted) return;
        showSnack(context, 'Đã tạo và thêm vào $title');
        _loadPlaylists();
      } catch (e) {
        if (!mounted) return;
        showSnack(context, e is ApiException ? e.message : 'Không thể tạo danh sách phát');
      }
    }
  }

  IconData _visibilityIcon(String visibility) {
    switch (visibility) {
      case 'public':
        return Icons.public;
      case 'unlisted':
        return Icons.link;
      case 'private':
      default:
        return Icons.lock_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lưu vào danh sách phát',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18, color: AppColors.link),
                    label: const Text(
                      'Danh sách phát mới',
                      style: TextStyle(color: AppColors.link, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _showCreatePlaylistDialog,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading)
              const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _loadPlaylists, child: const Text('Thử lại')),
                    ],
                  ),
                ),
              )
            else if (_playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                child: Center(
                  child: Text(
                    'Bạn chưa có danh sách phát nào. Hãy tạo danh sách phát mới!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];
                    final isChecked = playlist.containsVideo == true;

                    return CheckboxListTile(
                      value: isChecked,
                      activeColor: AppColors.accent,
                      checkColor: Colors.white,
                      title: Text(
                        playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      secondary: Icon(
                        _visibilityIcon(playlist.visibility),
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          _togglePlaylist(playlist, val);
                        }
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
