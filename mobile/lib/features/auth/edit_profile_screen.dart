import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/require_login.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/channel_service.dart';
import '../../data/services/upload_service.dart';
import '../../shared/widgets/state_views.dart';
import 'auth_validators.dart';
import 'image_pick.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/avatar_picker.dart';
import 'widgets/banner_picker.dart';

/// MÀN 17 (mở rộng) · CHỈNH SỬA HỒ SƠ · Người 1
/// API:
///   - ChannelService.get(user.channel.id)                    (mô tả, ảnh bìa hiện tại)
///   - UploadService.upload(path, type: 'image')              (avatar / ảnh bìa mới, upload trước khi lưu)
///   - AuthService.updateMe(displayName?, avatarUrl?)         (PUT /api/me; avatar tự đồng bộ sang kênh)
///   - ChannelService.updateMine(name?, description?, bannerUrl?)   (PUT /api/channels/me)
///   - AuthProvider.refreshMe()                               (Trang "Bạn" cập nhật ngay sau khi lưu)
/// Mở từ: Trang "Bạn" (chip "Chỉnh sửa hồ sơ" hoặc bấm avatar).
/// Chỉ gửi những gì đã đổi. Handle và email chỉ hiển thị (API không cho đổi).
class EditProfileScreen extends StatefulWidget {
  final PickImage pickAvatar;
  final PickImage pickBanner;

  const EditProfileScreen({
    super.key,
    this.pickAvatar = pickAvatarFromDevice,
    this.pickBanner = pickBannerFromDevice,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _ImageAction { camera, gallery, undo }

/// Ảnh vừa chọn, chưa lưu. [uploadedUrl] giữ lại để lưu lỗi rồi bấm lại không phải upload lần nữa.
class _PendingImage {
  final XFile file;
  final Uint8List bytes;
  String? uploadedUrl;

  _PendingImage(this.file, this.bytes);
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _channelName = TextEditingController();
  final _description = TextEditingController();

  // Tải thông tin kênh (mô tả, ảnh bìa) của tài khoản [_userId].
  int? _userId;
  Channel? _channel;
  String? _loadError;

  // Giá trị đang lưu trên server: so với ô nhập để biết đã đổi gì.
  String _baseName = '';
  String _baseChannelName = '';
  String _baseDescription = '';
  String? _avatarUrl;
  String? _bannerUrl;

  _PendingImage? _avatar;
  _PendingImage? _banner;

  bool _saving = false;
  bool _saved = false;

  List<TextEditingController> get _controllers => [_name, _channelName, _description];

  bool get _dirty =>
      _channel != null &&
      (_avatar != null ||
          _banner != null ||
          _name.text.trim() != _baseName ||
          _channelName.text.trim() != _baseChannelName ||
          _description.text.trim() != _baseDescription);

  // Giá trị _dirty ở lần build gần nhất: chỉ build lại cả màn khi nó đổi (nút Lưu, PopScope cần biết),
  // không build lại theo từng ký tự.
  bool _builtDirty = false;

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = Provider.of<AuthProvider>(context).user?.id;
    // Đăng xuất (hết phiên): giữ nguyên dữ liệu, màn hiện lời mời đăng nhập.
    // refreshMe() sau khi lưu: cùng id nên không tải lại.
    if (userId == null || userId == _userId) return;
    _userId = userId;
    // Tài khoản khác: bỏ dữ liệu của tài khoản cũ rồi tải lại.
    _channel = null;
    _loadError = null;
    _avatar = null;
    _banner = null;
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (_dirty != _builtDirty) setState(() {});
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final service = context.read<ChannelService>();
    if (_loadError != null) setState(() => _loadError = null);
    try {
      final channel = await service.get(user.channel.id);
      // Đã đổi sang tài khoản khác trong lúc tải: bỏ kết quả của tài khoản cũ.
      if (!mounted || _userId != user.id) return;
      // Điền ô trước khi gán _channel: lúc này _dirty còn false nên listener của ô không build lại thừa.
      _name.text = user.displayName;
      _channelName.text = channel.name;
      _description.text = channel.description ?? '';
      setState(() {
        _channel = channel;
        // So với ô nhập đã bỏ khoảng trắng hai đầu (xem _dirty).
        _baseName = _name.text.trim();
        _baseChannelName = _channelName.text.trim();
        _baseDescription = _description.text.trim();
        _avatarUrl = user.avatarUrl ?? channel.avatarUrl;
        _bannerUrl = channel.bannerUrl;
      });
    } catch (e) {
      if (mounted && _userId == user.id) {
        setState(() => _loadError = e is ApiException ? e.message : 'Không tải được hồ sơ, vui lòng thử lại');
      }
    }
  }

  // ---------------------------------------------------------------- Ảnh

  Future<void> _pickImage({required bool banner}) async {
    final pending = banner ? _banner : _avatar;
    final action = await showModalBottomSheet<_ImageAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(banner ? 'Ảnh bìa kênh' : 'Ảnh đại diện'),
            titleTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(ctx, _ImageAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(ctx, _ImageAction.gallery),
          ),
          if (pending != null)
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Dùng lại ảnh cũ'),
              onTap: () => Navigator.pop(ctx, _ImageAction.undo),
            ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _ImageAction.undo) {
      _setPending(banner: banner, image: null);
      return;
    }
    final fromCamera = action == _ImageAction.camera;
    final pick = banner ? widget.pickBanner : widget.pickAvatar;
    try {
      final file = await pick(fromCamera ? ImageSource.camera : ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) _setPending(banner: banner, image: _PendingImage(file, bytes));
    } on PlatformException {
      if (mounted) showSnack(context, fromCamera ? 'Không mở được camera' : 'Không mở được thư viện ảnh');
    }
  }

  void _setPending({required bool banner, required _PendingImage? image}) {
    setState(() {
      if (banner) {
        _banner = image;
      } else {
        _avatar = image;
      }
    });
  }

  /// Upload ảnh vừa chọn (nếu có), trả url. Lỗi đọc file (không phải lỗi API) cũng báo gọn bằng ApiException.
  Future<String?> _upload(_PendingImage? image, UploadService service, String what) async {
    if (image == null) return null;
    try {
      return image.uploadedUrl ??= (await service.upload(image.file.path, type: 'image')).url;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không tải được $what, hãy chọn ảnh khác');
    }
  }

  // ---------------------------------------------------------------- Lưu

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || !_dirty) return;

    final auth = context.read<AuthProvider>();
    final authService = context.read<AuthService>();
    final channelService = context.read<ChannelService>();
    final uploads = context.read<UploadService>();
    final name = _name.text.trim();
    final channelName = _channelName.text.trim();
    final description = _description.text.trim();

    setState(() => _saving = true);
    var changed = false; // đã lưu được ít nhất một phần -> tải lại tài khoản
    try {
      // Upload ảnh trước: lỗi ở bước này thì chưa có gì bị đổi trên server.
      final avatarUrl = await _upload(_avatar, uploads, 'ảnh đại diện');
      final bannerUrl = await _upload(_banner, uploads, 'ảnh bìa');

      if (name != _baseName || avatarUrl != null) {
        await authService.updateMe(displayName: name != _baseName ? name : null, avatarUrl: avatarUrl);
        changed = true;
        // Phần này đã lưu: nếu bước sau lỗi, bấm Lưu lại sẽ không gửi lại.
        if (mounted) {
          setState(() {
            _baseName = name;
            if (avatarUrl != null) {
              _avatarUrl = avatarUrl;
              _avatar = null;
            }
          });
        }
      }

      if (channelName != _baseChannelName || description != _baseDescription || bannerUrl != null) {
        await channelService.updateMine(
          name: channelName != _baseChannelName ? channelName : null,
          // Chuỗi rỗng = xóa mô tả; null = giữ nguyên.
          description: description != _baseDescription ? description : null,
          bannerUrl: bannerUrl,
        );
        changed = true;
        if (mounted) {
          setState(() {
            _baseChannelName = channelName;
            _baseDescription = description;
            if (bannerUrl != null) {
              _bannerUrl = bannerUrl;
              _banner = null;
            }
          });
        }
      }

      await _refreshAccount(auth);
      if (!mounted) return;
      _saved = true;
      showSnack(context, 'Đã lưu thay đổi');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.you);
      }
    } on ApiException catch (e) {
      if (changed) await _refreshAccount(auth);
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Cập nhật tên, avatar trên Trang "Bạn" và bottom nav. Lỗi thì bỏ qua: dữ liệu đã lưu trên server.
  Future<void> _refreshAccount(AuthProvider auth) => auth.refreshMe().catchError((_) {});

  /// Hỏi lại trước khi rời màn khi còn thay đổi chưa lưu. Trả về true nếu được rời.
  Future<bool> _confirmDiscard() async {
    if (!_dirty || _saved) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Những thay đổi chưa lưu sẽ bị mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tiếp tục sửa')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  // ---------------------------------------------------------------- Giao diện

  @override
  Widget build(BuildContext context) {
    _builtDirty = _dirty;
    final user = context.watch<AuthProvider>().user;
    return PopScope(
      // Đang lưu thì chặn Back để không rời màn giữa chừng.
      canPop: !_saving && (!_dirty || _saved),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          // BackButton không cho đổi tooltip (mặc định "Back") nên tự dựng; maybePop vẫn tôn trọng PopScope.
          leading: (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
              ? IconButton(
                  icon: const BackButtonIcon(),
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.maybePop(context),
                )
              : null,
          title: const Text('Chỉnh sửa hồ sơ'),
          actions: [if (user != null) _buildSaveButton()],
        ),
        body: SafeArea(top: false, child: _buildBody(user)),
      ),
    );
  }

  Widget _buildSaveButton() {
    if (_saving) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      );
    }
    return TextButton(
      onPressed: _dirty ? _save : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.link,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: const Text('Lưu'),
    );
  }

  Widget _buildBody(Me? user) {
    // Phiên đăng nhập hết hạn khi đang ở màn này.
    if (user == null) {
      return EmptyView(
        icon: Icons.account_circle_outlined,
        title: 'Bạn chưa đăng nhập',
        message: 'Đăng nhập để chỉnh sửa hồ sơ của bạn',
        actionLabel: 'Đăng nhập',
        onAction: () => context.push(AppRoutes.login),
      );
    }
    if (_loadError != null) return ErrorView(message: _loadError!, onRetry: _load);
    if (_channel == null) return const LoadingView();

    const gap = SizedBox(height: 12);
    return Form(
      key: _formKey,
      // Không dùng ListView: ô cuộn khuất sẽ bị gỡ khỏi cây và Form.validate() bỏ qua nó.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BannerPicker(
            imageBytes: _banner?.bytes,
            imageUrl: _bannerUrl,
            onTap: _saving ? null : () => _pickImage(banner: true),
          ),
          const SizedBox(height: 16),
          Center(
            child: AvatarPicker(
              imageBytes: _avatar?.bytes,
              imageUrl: _avatarUrl,
              onTap: _saving ? null : () => _pickImage(banner: false),
            ),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            label: 'Tên hiển thị',
            hint: 'Ví dụ: Nguyễn Văn An',
            icon: Icons.badge_outlined,
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: AuthValidators.displayName,
          ),
          gap,
          AuthTextField(
            label: 'Tên kênh',
            hint: 'Tên hiển thị của kênh',
            icon: Icons.smart_display_outlined,
            controller: _channelName,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.channelName,
          ),
          gap,
          AuthTextField(
            label: 'Mô tả kênh',
            hint: 'Giới thiệu kênh của bạn với người xem',
            icon: Icons.notes,
            controller: _description,
            enabled: !_saving,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 3,
            maxLines: 6,
            maxLength: AuthValidators.channelDescriptionMax,
            validator: AuthValidators.channelDescription,
          ),
          const SizedBox(height: 8),
          _ReadOnlyInfo(handle: user.channel.handle, email: user.email),
        ]),
      ),
    );
  }
}

/// Handle và email: chỉ hiển thị, kèm lý do không sửa được.
class _ReadOnlyInfo extends StatelessWidget {
  final String handle;
  final String email;

  const _ReadOnlyInfo({required this.handle, required this.email});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined, color: AppColors.textSecondary),
          title: const Text('Handle', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          subtitle: Text('@$handle', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          trailing: const Icon(Icons.lock_outline, size: 18, color: AppColors.textSecondary),
        ),
        ListTile(
          leading: const Icon(Icons.mail_outline, color: AppColors.textSecondary),
          title: const Text('Email', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          subtitle: Text(email, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          trailing: const Icon(Icons.lock_outline, size: 18, color: AppColors.textSecondary),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Handle và email dùng để nhận diện tài khoản nên không thể thay đổi.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ]),
    );
  }
}
