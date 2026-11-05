import 'package:image_picker/image_picker.dart';

/// Mở camera hoặc thư viện để chọn ảnh. Tách thành tham số của màn để test truyền hàm giả.
typedef PickImage = Future<XFile?> Function(ImageSource source);

/// Ảnh đại diện: thu nhỏ còn 512 px là đủ nét cho avatar tròn.
Future<XFile?> pickAvatarFromDevice(ImageSource source) =>
    ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);

/// Ảnh bìa kênh: ảnh ngang, cần rộng hơn avatar.
Future<XFile?> pickBannerFromDevice(ImageSource source) =>
    ImagePicker().pickImage(source: source, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
