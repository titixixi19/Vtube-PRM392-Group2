# video_thumbnail (bản vá cục bộ)

Bản sao của gói [`video_thumbnail` 0.5.6](https://pub.dev/packages/video_thumbnail) (MIT, xem `LICENSE`),
dùng qua `dependency_overrides` trong `mobile/pubspec.yaml`.

**Lý do:** bản gốc dùng `jcenter()` và Android Gradle Plugin 4.1 trong `android/build.gradle`.
Gradle 9 đã bỏ `jcenter()`, nên app không build được cho Android.

**Đã sửa:** chỉ `android/build.gradle` (bỏ `buildscript`/`jcenter()`, dùng AGP của app, `lintOptions` → `lint`).
Code Dart (`lib/`), Java và iOS giữ nguyên bản gốc.

Khi có bản `video_thumbnail` mới hỗ trợ Gradle 9 (hoặc đổi sang gói khác), xóa thư mục này
và bỏ phần `dependency_overrides` trong `pubspec.yaml`.
