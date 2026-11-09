// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../data/models/models.dart';

typedef PickVideoFile = Future<XFile?> Function(ImageSource source);
typedef PickImageFile = Future<XFile?> Function(ImageSource source);

/// Dòng cài đặt theo chuẩn Material 3 trong form upload video.
class UploadSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;

  const UploadSettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 13, color: AppColors.link, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Thẻ hiển thị tiến trình tải lên video hoặc thông báo lỗi khi thất bại.
class UploadProgressCard extends StatelessWidget {
  final double progress;
  final bool isFailed;
  final String? errorMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const UploadProgressCard({
    super.key,
    required this.progress,
    this.isFailed = false,
    this.errorMessage,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFailed ? AppColors.error : AppColors.surfaceHighest,
        ),
      ),
      child: isFailed
          ? Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tải lên thất bại',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          errorMessage!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Thử lại', style: TextStyle(color: AppColors.link, fontWeight: FontWeight.bold)),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đang tải lên ${(progress * 100).round()}%',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    if (onCancel != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Hủy tải lên',
                        onPressed: onCancel,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  color: AppColors.accent,
                  backgroundColor: AppColors.surfaceHighest,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
    );
  }
}

/// Sheet chọn Chế độ hiển thị (Công khai, Không công khai, Riêng tư).
Future<String?> showVisibilityPickerSheet(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Chế độ hiển thị', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          RadioListTile<String>(
            value: 'public',
            groupValue: current,
            title: const Text('Công khai'),
            subtitle: const Text('Mọi người đều có thể tìm kiếm và xem'),
            secondary: const Icon(Icons.public),
            onChanged: (val) => Navigator.pop(ctx, val),
          ),
          RadioListTile<String>(
            value: 'unlisted',
            groupValue: current,
            title: const Text('Không công khai'),
            subtitle: const Text('Bất kỳ ai có liên kết đều có thể xem'),
            secondary: const Icon(Icons.link),
            onChanged: (val) => Navigator.pop(ctx, val),
          ),
          RadioListTile<String>(
            value: 'private',
            groupValue: current,
            title: const Text('Riêng tư'),
            subtitle: const Text('Chỉ bạn mới có thể xem'),
            secondary: const Icon(Icons.lock_outline),
            onChanged: (val) => Navigator.pop(ctx, val),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Sheet chọn Đối tượng người xem.
Future<bool?> showAudiencePickerSheet(BuildContext context, bool currentMadeForKids) {
  return showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Đối tượng người xem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          RadioListTile<bool>(
            value: false,
            groupValue: currentMadeForKids,
            title: const Text('Không dành cho trẻ em'),
            subtitle: const Text('Video có thể xem bởi mọi lứa tuổi, hỗ trợ đầy đủ bình luận'),
            onChanged: (val) => Navigator.pop(ctx, val),
          ),
          RadioListTile<bool>(
            value: true,
            groupValue: currentMadeForKids,
            title: const Text('Nội dung dành cho trẻ em'),
            subtitle: const Text('Các tính năng như bình luận và thông báo sẽ bị hạn chế'),
            onChanged: (val) => Navigator.pop(ctx, val),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Sheet chọn Danh mục video.
Future<Category?> showCategoryPickerSheet(BuildContext context, List<Category> categories, int? currentId) {
  return showModalBottomSheet<Category>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Danh mục nội dung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.5),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              itemBuilder: (c, idx) {
                final cat = categories[idx];
                final isSelected = cat.id == currentId;
                return ListTile(
                  title: Text(cat.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSelected ? const Icon(Icons.check, color: AppColors.accent) : null,
                  onTap: () => Navigator.pop(ctx, cat),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Sheet chọn Chính sách bình luận.
Future<bool?> showCommentsPolicySheet(BuildContext context, bool currentEnabled) {
  return showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Bình luận', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          RadioListTile<bool>(
            value: true,
            groupValue: currentEnabled,
            title: const Text('Cho phép bình luận'),
            subtitle: const Text('Mọi người có thể gửi nhận xét về video của bạn'),
            onChanged: (val) => Navigator.pop(ctx, val),
          ),
          RadioListTile<bool>(
            value: false,
            groupValue: currentEnabled,
            title: const Text('Tắt bình luận'),
            subtitle: const Text('Không cho phép bình luận trên video này'),
            onChanged: (val) => Navigator.pop(ctx, val),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Sheet chọn danh sách phát mà video sẽ được thêm vào sau khi tạo.
Future<Set<int>?> showUploadPlaylistsSheet(BuildContext context, List<Playlist> playlists, Set<int> selectedIds) {
  final current = Set<int>.from(selectedIds);
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSheetState) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Chọn danh sách phát', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, current),
                      child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Bạn chưa có danh sách phát nào', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.45),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (c, idx) {
                      final pl = playlists[idx];
                      final checked = current.contains(pl.id);
                      return CheckboxListTile(
                        value: checked,
                        activeColor: AppColors.accent,
                        title: Text(pl.title),
                        onChanged: (val) {
                          setSheetState(() {
                            if (val == true) {
                              current.add(pl.id);
                            } else {
                              current.remove(pl.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
