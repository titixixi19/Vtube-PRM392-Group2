# VTube: ứng dụng giả lập YouTube (PRM393)

App Flutter gồm 16 màn hình, chia cho 4 người, chạy trên backend Spring Boot + SQLite.

| Thư mục | Nội dung |
| --- | --- |
| `backend/` | REST API Java 17 · Spring Boot 3.3 · SQLite (file `vtube.db`) |
| `mobile/` | App Flutter (khung dùng chung đã có sẵn, mỗi người code màn của mình) |
| `docs/` | Tài liệu: API, database, luồng, quy ước, phân công |
| `design/stitch/` | Thiết kế từ Google Stitch (mở `code.html` bằng trình duyệt để xem) |

Tài liệu đặc tả chi tiết từng màn (bản online, có sơ đồ điều hướng): **Đặc tả màn hình VTube** trên Claude. Bản copy nằm ở `docs/DAC-TA-MAN-HINH.md`.

## Đọc gì trước?

1. [`CONTRIBUTING.md`](CONTRIBUTING.md): **luật làm việc với Git**. Bắt buộc đọc trước khi commit.
2. [`docs/tasks/`](docs/tasks): việc của từng người (`NGUOI-1.md` ... `NGUOI-4.md`).
3. [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md): quy ước code Flutter và mẫu màn hình có phân trang.
4. [`docs/API.md`](docs/API.md): danh sách API. [`docs/DATABASE.md`](docs/DATABASE.md): bảng dữ liệu. [`docs/FLOW.md`](docs/FLOW.md): luồng điều hướng và nghiệp vụ.

## Phân công

| Người | Luồng | Màn hình | Thư mục code |
| --- | --- | --- | --- |
| Người 1 | Xác thực & Tài khoản | 1 Splash, 2 Đăng nhập, 3 Đăng ký, 4 Trang "Bạn" | `mobile/lib/features/auth/` |
| Người 2 | Xem video | 5 Trang chủ, 6 Xem video, 7 Bình luận, 8 Shorts | `mobile/lib/features/watch/` |
| Người 3 | Khám phá & Kênh | 9 Tìm kiếm, 10 Kết quả, 11 Trang kênh, 12 Kênh đăng ký | `mobile/lib/features/explore/` |
| Người 4 | Thư viện & Tạo nội dung | 13 Lịch sử, 14 Playlist, 15 Tải lên, 16 Thông báo | `mobile/lib/features/library/` |

Điền tên thật vào bảng này và vào [`.github/CODEOWNERS`](.github/CODEOWNERS) ở commit đầu tiên.

## Chạy backend

Yêu cầu: **JDK 17 trở lên**. Không cần cài database, SQLite là một file.

**Cách 1: IntelliJ IDEA (khuyên dùng)**

1. File → Open → chọn thư mục `backend`.
2. Đợi Maven tải thư viện.
3. Chạy `VtubeApiApplication`.

**Cách 2: dòng lệnh** (máy đã cài Maven):

```bash
cd backend
mvn spring-boot:run
```

Sau khi chạy:
- Lần đầu chạy, backend tạo file `backend/vtube.db` và nạp dữ liệu mẫu: 7 kênh, 33 video (25 video thường + 8 Shorts), bình luận, playlist, thông báo.
- Swagger để thử API: http://localhost:8080/swagger-ui.html
- Tài khoản demo: `demo@vtube.vn` / `123456`
- Muốn làm lại dữ liệu từ đầu: tắt backend, xóa `vtube.db`, chạy lại.
- File upload được lưu ở `backend/uploads/`.

## Chạy app Flutter

Yêu cầu: Flutter 3.24 trở lên (`flutter --version`).

**Lần đầu (chỉ trưởng nhóm làm 1 lần, rồi commit)**: tạo các thư mục nền tảng Android/iOS. Lệnh này không ghi đè code trong `lib/`.

```bash
cd mobile
flutter create . --project-name vtube --org com.vtube --platforms android,ios
```

Sau đó mở `android/app/src/main/AndroidManifest.xml` và sửa hai chỗ:
- Thêm `<uses-permission android:name="android.permission.INTERNET"/>` ngay trên thẻ `<application`.
- Thêm `android:usesCleartextTraffic="true"` vào thẻ `<application ...>` (cho phép gọi `http://` tới backend).

Commit với message `chore(mobile): tạo thư mục android, ios`.

**Mỗi người, mỗi lần chạy**

```bash
cd mobile
flutter pub get
flutter run                     # Android Emulator, gọi http://10.0.2.2:8080
```

Nếu không chạy trên Android Emulator, truyền địa chỉ backend khi chạy:
- Điện thoại thật cùng Wi-Fi: `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080`
- iOS Simulator: `flutter run --dart-define=API_BASE_URL=http://localhost:8080`

Màn nào chưa làm sẽ hiện khung "Màn X · Người Y đang làm". Trang chủ tạm thời có các nút mở nhanh mọi màn để mỗi người thử màn của mình trước khi Trang chủ xong.

## Cấu trúc app Flutter

```
mobile/lib/
├── main.dart
├── app/                 # DÙNG CHUNG: theme, router, routes, bottom nav
├── core/                # DÙNG CHUNG: ApiClient, AuthProvider, requireLogin, Fmt (định dạng số, thời gian)
├── data/
│   ├── models/          # DÙNG CHUNG: Video, Channel, Comment, Playlist, ...
│   └── services/        # DÙNG CHUNG: mỗi file gọi 1 nhóm API (VideoService, ChannelService, ...)
├── shared/widgets/      # DÙNG CHUNG: VideoCardLarge, VideoCardCompact, ShortsShelf, ChipBar, ...
└── features/
    ├── auth/            # Người 1
    ├── watch/           # Người 2
    ├── explore/         # Người 3
    └── library/         # Người 4
```

Thư mục **DÙNG CHUNG** chỉ sửa theo quy trình trong `CONTRIBUTING.md` (mục 6).
