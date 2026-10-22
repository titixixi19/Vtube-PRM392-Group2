# Đặc tả màn hình VTube

Oct 22, 2026 · @Son Tung

VTube gồm 16 màn hình chính chia cho 4 người, mỗi người một luồng tính năng khép kín. Tài liệu này mô tả từng màn: hiển thị gì, làm được gì, đi tới đâu, cần dữ liệu gì và xử lý các trạng thái ra sao.

## Quy ước chung

### Phân công

| Người | Luồng | Màn hình |
| --- | --- | --- |
| Người 1 | Xác thực & Tài khoản | Splash, Đăng nhập, Đăng ký, Trang "Bạn" |
| Người 2 | Xem video | Trang chủ, Xem video, Bình luận, Shorts |
| Người 3 | Khám phá & Kênh | Tìm kiếm, Kết quả tìm kiếm, Trang kênh, Kênh đăng ký |
| Người 4 | Thư viện & Tạo nội dung | Lịch sử xem, Chi tiết Playlist, Tải video lên, Thông báo |

### Bottom Navigation (dùng chung)

Thanh điều hướng dưới có 5 mục, hiện ở 4 màn tab chính và ẩn ở các màn con (Xem video, Tìm kiếm, Upload...).

1. **Trang chủ** → Màn 5
2. **Shorts** → Màn 8
3. **(+) Tạo** → mở bottom sheet: Tạo Short, Tải video lên (Màn 15), Phát trực tiếp (giả lập), Tạo bài đăng
4. **Kênh đăng ký** → Màn 12
5. **Bạn** → Màn 4 (chưa đăng nhập thì chuyển sang Màn 2)

Giữ trạng thái từng tab khi chuyển qua lại (trong Flutter dùng `IndexedStack` hoặc `StatefulShellRoute` của go\_router).

### Component dùng chung

Làm trước trong tuần đầu, mỗi người chỉ gọi lại, không tự viết riêng.

- **VideoCardLarge**: thumbnail 16:9 + badge thời lượng, avatar kênh, tiêu đề 2 dòng, dòng meta, nút 3 chấm. Dùng ở Trang chủ, Kênh đăng ký.
- **VideoCardCompact**: thumbnail bên trái (\~40% chiều rộng), thông tin bên phải. Dùng ở Kết quả tìm kiếm, Lịch sử, Playlist, Trang kênh.
- **ShortsShelf**: hàng ngang thumbnail dọc 9:16.
- **ChannelAvatar**: ảnh tròn, có tùy chọn chấm xanh báo video mới.
- **SubscribeButton**: 2 trạng thái "Đăng ký" (nền trắng) / "Đã đăng ký" (nền xám + icon chuông).
- **VideoOptionsSheet**: bottom sheet 3 chấm gồm Lưu vào Xem sau, Lưu vào danh sách phát, Tải xuống, Chia sẻ, Không quan tâm, Báo cáo.
- **ChipBar**: hàng chip lọc cuộn ngang, một chip được chọn.
- **Shimmer, EmptyState, ErrorState**: khung loading, màn trống, màn lỗi có nút "Thử lại".

### Model dữ liệu

> Bảng dưới là phác thảo ban đầu. Tên trường chính xác theo [`API.md`](API.md) và [`DATABASE.md`](DATABASE.md).

| Model | Trường chính |
| --- | --- |
| User | id, email, displayName, handle, avatarUrl, createdAt |
| Channel | id, ownerId, name, handle, avatarUrl, bannerUrl, description, subscriberCount, videoCount, verified |
| Video | id, channelId, title, description, thumbnailUrl, videoUrl, duration, viewCount, likeCount, publishedAt, category, isShort, visibility |
| Comment | id, videoId, userId, parentId, content, likeCount, isPinned, createdAt |
| Playlist | id, ownerId, title, visibility, videoIds, updatedAt |
| Subscription | userId, channelId, notifyMode, createdAt |
| WatchHistory | userId, videoId, watchedAt, progressSeconds |
| Notification | id, userId, type, actorChannelId, videoId, message, isRead, createdAt |
| SearchHistory | userId, keyword, searchedAt |

### Quy ước hiển thị

- **Số lượng rút gọn**: 999 → "999", 1.200 → "1,2 N", 1.500.000 → "1,5 Tr", 2.000.000.000 → "2 T".
- **Thời gian tương đối**: "5 phút trước", "3 ngày trước", "2 tuần trước", "1 năm trước".
- **Thời lượng**: "4:05", "1:02:30"; video trực tiếp hiện badge đỏ "TRỰC TIẾP".
- **Trạng thái chung** mỗi màn phải có: Loading (shimmer), Empty (icon + câu hướng dẫn), Error (thông báo + "Thử lại"), Mất mạng (banner "Không có kết nối mạng").
- **Yêu cầu đăng nhập**: khi khách bấm Like, Đăng ký, Bình luận, Lưu, Tải lên, hiện dialog "Đăng nhập để tiếp tục" dẫn về Màn 2.

## Luồng điều hướng

Sơ đồ điều hướng: xem [`FLOW.md`](FLOW.md) (bản hình vẽ nằm trong tài liệu đặc tả online).

Màn 15 (Tải video lên) mở từ nút (+) Tạo; màn 7 (Bình luận) là bottom sheet nên không rời màn video. Mọi màn chi tiết dùng nút Back để quay về đúng tab đã mở nó.

## Kiến trúc hệ thống

App Flutter gọi REST API của backend Spring Boot (Java 17), dữ liệu lưu trong một file SQLite `vtube.db`; video và ảnh tải lên được lưu trong thư mục `uploads/` của backend. Đăng nhập trả về một token, app gửi kèm trong header `Authorization: Bearer <token>` cho mọi API cần tài khoản. Chi tiết endpoint nằm ở `docs/API.md` trong repo và Swagger tại `http://localhost:8080/swagger-ui.html`.

## Luồng nghiệp vụ chính

**1. Mở app và đăng nhập**

1. Splash đọc token trong `shared_preferences`.
2. Có token → gọi `GET /api/me`. Thành công → vào khung tab; lỗi 401 → xóa token, vào khung tab ở chế độ khách.
3. Khách bấm Like, Đăng ký, Bình luận, Lưu, (+) Tạo hoặc tab Bạn → dialog "Đăng nhập để tiếp tục" → Màn 2.
4. Đăng nhập hoặc đăng ký thành công → lưu token + user vào `AuthProvider` → quay lại màn trước đó.
5. Đăng xuất → `POST /api/auth/logout` → xóa token → về Trang chủ chế độ khách.

**2. Xem video**

1. Bấm một video → Màn 6 gọi song song `GET /api/videos/{id}` và `GET /api/videos/{id}/related`.
2. Bắt đầu phát → `POST /api/videos/{id}/view` (tăng lượt xem 1 lần).
3. Mỗi 10 giây và khi rời màn → `PUT /api/me/history/{videoId}` với `progressSeconds` (chỉ khi đã đăng nhập và chưa tạm dừng lịch sử).
4. Lần sau mở lại video, app tua tới `progressSeconds` đã lưu.

**3. Tương tác (Like, Đăng ký, Lưu)**

1. App đổi giao diện ngay (optimistic update) rồi mới gọi API.
2. Like → `PUT /api/videos/{id}/reaction` với `value` = 1, -1 hoặc 0. Backend tự thêm/bớt video trong playlist "Video đã thích".
3. Đăng ký → `PUT /api/channels/{id}/subscription`; hủy → `DELETE` cùng đường dẫn. Backend tạo thông báo cho chủ kênh.
4. API lỗi → trả giao diện về trạng thái cũ + SnackBar.

**4. Bình luận**

1. Mở sheet → `GET /api/videos/{id}/comments?sort=top`.
2. Gửi → `POST /api/videos/{id}/comments`; trả lời thì gửi kèm `parentId`.
3. Backend tăng `commentCount` của video, `replyCount` của bình luận cha, và tạo thông báo cho người được trả lời.

**5. Tải video lên**

1. Chọn file → `POST /api/uploads` (multipart, `type=video`) → nhận `url`.
2. Chọn thumbnail (hoặc dùng ảnh mặc định) → `POST /api/uploads` (`type=image`).
3. Bấm "Tải lên" → `POST /api/videos` với tiêu đề, mô tả, url, thumbnail, chế độ hiển thị...
4. Backend tạo thông báo "đã tải lên" cho mọi người đăng ký kênh (trừ người chọn "Không nhận").

**6. Thông báo**

1. Badge chuông lấy từ `GET /api/me/notifications/unread-count` khi mở app và khi quay lại tab.
2. Màn 16 gọi `GET /api/me/notifications`; bấm một mục → `PUT /api/notifications/{id}/read` rồi điều hướng theo `type`.

**7. Tìm kiếm**

1. Gõ phím → sau 300 ms gọi `GET /api/search/suggestions?q=`.
2. Bấm tìm → `GET /api/search?q=...`; backend tự lưu từ khóa vào lịch sử tìm kiếm nếu đã đăng nhập.

## Người 1: Xác thực & Tài khoản

### Màn 1: Splash

Màn đầu tiên khi mở app, hiện logo trong lúc kiểm tra phiên đăng nhập rồi tự chuyển hướng, không có thao tác nào của người dùng.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Giữa màn | Logo | Hình chữ nhật bo góc đỏ + tam giác play trắng, có hiệu ứng scale/fade-in 600 ms |
| Dưới logo | Tên app | "VTube", chữ đậm, màu trắng |
| Gần đáy | Loading | Vòng tròn quay nhỏ màu đỏ |
| Đáy | Phiên bản | "v1.0.0", chữ xám nhỏ |

**Chức năng**

1. Khởi tạo dịch vụ: Firebase/API client, đọc cài đặt (theme sáng/tối, ngôn ngữ) từ `shared_preferences`.
2. Kiểm tra token đăng nhập đã lưu; nếu có thì gọi API lấy thông tin user để xác nhận token còn hạn.
3. Lần đầu mở app (chưa có cờ `onboarded`): chuyển sang Onboarding 3 trang (tùy chọn, xem phần mở rộng).
4. Giữ splash tối thiểu khoảng 1,5 giây để hiệu ứng logo chạy xong.

**Điều hướng**

- Token hợp lệ → Trang chủ (Màn 5), dùng `pushReplacement` để không quay lại được splash.
- Không có token hoặc token hết hạn → Trang chủ ở chế độ khách (vẫn xem được video), hoặc Đăng nhập (Màn 2) nếu nhóm muốn bắt buộc đăng nhập.

**Trạng thái**

- Mất mạng: dòng chữ "Không có kết nối mạng" + nút "Thử lại" thay cho vòng loading.
- Lỗi server: vẫn vào Trang chủ, hiện dữ liệu cache nếu có.

### Màn 2: Đăng nhập

Cho người dùng đăng nhập bằng email/mật khẩu hoặc Google (giả lập) để dùng các tính năng cần tài khoản như Like, Đăng ký kênh, Bình luận, Tải lên.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | Nút đóng (X) | Chỉ hiện khi mở từ dialog "Đăng nhập để tiếp tục" |
| Đầu màn | Logo + tiêu đề | "Đăng nhập", phụ đề "để tiếp tục với VTube" |
| Form | Ô Email | Bàn phím kiểu email, icon thư bên trái |
| Form | Ô Mật khẩu | Ẩn ký tự, icon con mắt để hiện/ẩn |
| Form | Link "Quên mật khẩu?" | Căn phải, màu xanh |
| Form | Checkbox "Ghi nhớ đăng nhập" | Mặc định bật |
| Nút chính | "Đăng nhập" | Nền đỏ, full-width, mờ (disabled) khi form chưa hợp lệ, hiện vòng quay khi đang gửi |
| Giữa | Đường kẻ + chữ "hoặc" |  |
| Nút phụ | "Tiếp tục với Google" | Viền xám, icon G |
| Đáy | "Chưa có tài khoản? Đăng ký" | "Đăng ký" là link |

**Chức năng & kiểm tra dữ liệu**

1. Email: không được trống, đúng định dạng email. Lỗi hiện ngay dưới ô (chữ đỏ), kiểm tra khi rời ô hoặc khi bấm nút.
2. Mật khẩu: không trống, tối thiểu 6 ký tự.
3. Bấm "Đăng nhập": ẩn bàn phím, khóa nút, gọi API. Thành công → lưu token (`flutter_secure_storage`) + thông tin user vào state chung.
4. Sai email/mật khẩu: SnackBar hoặc dòng đỏ trên nút "Email hoặc mật khẩu không đúng", giữ nguyên email đã nhập, xóa ô mật khẩu.
5. Sai quá 5 lần: khóa nút 30 giây kèm đếm ngược (tùy chọn).
6. "Tiếp tục với Google": giả lập đăng nhập bằng tài khoản mẫu, hoặc dùng `google_sign_in` nếu nhóm làm Firebase.
7. Bấm Enter ở ô Email thì nhảy sang ô Mật khẩu; Enter ở ô Mật khẩu thì gửi form.

**Điều hướng**

- Thành công → quay về màn trước đó (nếu mở từ dialog) hoặc Trang chủ (Màn 5).
- "Đăng ký" → Màn 3.
- "Quên mật khẩu?" → màn Quên mật khẩu (mở rộng) hoặc dialog nhập email.
- Nút Back hệ thống: nếu mở từ splash thì thoát app, ngược lại quay lại.

**API**

- `POST /api/auth/login` { email, password } → { token, user }

**Trạng thái**

- Đang gửi: nút hiện vòng quay, các ô bị khóa.
- Mất mạng: SnackBar "Không có kết nối mạng".

### Màn 3: Đăng ký

Tạo tài khoản mới; khi đăng ký xong, hệ thống tự tạo luôn một kênh gắn với tài khoản để người dùng có thể tải video lên.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | Nút Back + tiêu đề | "Tạo tài khoản" |
| Đầu form | Chọn avatar | Ảnh tròn mặc định + icon máy ảnh; bấm mở bottom sheet "Chụp ảnh / Chọn từ thư viện" |
| Form | Họ tên | Bắt buộc |
| Form | Tên kênh | Bắt buộc, gợi ý tự điền từ Họ tên |
| Form | Handle | Có tiền tố "@", hiện dấu tích xanh / chữ đỏ "Đã có người dùng" |
| Form | Email | Bắt buộc |
| Form | Mật khẩu | Ẩn/hiện, có thanh độ mạnh (Yếu / Trung bình / Mạnh) |
| Form | Xác nhận mật khẩu | Ẩn/hiện |
| Form | Ngày sinh, Giới tính | Tùy chọn; ngày sinh dùng DatePicker |
| Cuối form | Checkbox điều khoản | "Tôi đồng ý với Điều khoản dịch vụ", phần chữ gạch chân mở dialog điều khoản |
| Nút chính | "Đăng ký" | Nền đỏ, disabled khi chưa tick điều khoản |
| Đáy | "Đã có tài khoản? Đăng nhập" |  |

**Chức năng & kiểm tra dữ liệu**

1. Họ tên: 2–50 ký tự.
2. Handle: 3–30 ký tự, chỉ chữ thường, số, dấu chấm, gạch dưới; kiểm tra trùng sau khi ngừng gõ 500 ms (debounce).
3. Email: đúng định dạng, kiểm tra trùng khi gửi ("Email đã được sử dụng").
4. Mật khẩu: tối thiểu 8 ký tự, có chữ và số; thanh độ mạnh cập nhật theo từng ký tự gõ.
5. Xác nhận mật khẩu: phải trùng mật khẩu.
6. Avatar: dùng `image_picker`, cắt vuông (tùy chọn `image_cropper`), giới hạn 2 MB.
7. Bấm "Đăng ký": kiểm tra toàn form, cuộn tới ô lỗi đầu tiên nếu có; hợp lệ thì gọi API, upload avatar, tạo kênh.
8. Nút Back khi form đã nhập dở: dialog "Hủy đăng ký? Thông tin đã nhập sẽ bị mất".

**Điều hướng**

- Thành công → SnackBar "Tạo tài khoản thành công" rồi tự đăng nhập, vào Trang chủ (Màn 5). Hoặc quay về Đăng nhập với email đã điền sẵn.
- "Đăng nhập" → quay lại Màn 2.

**API**

- `GET /api/users/check-handle?handle=` → { available }
- `POST /api/uploads` (multipart, type=image) → { url } cho avatar
- `POST /api/auth/register` { displayName, channelName, handle, email, password, avatarUrl } → { token, user }

**Trạng thái**

- Đang gửi: overlay loading, khóa form.
- Lỗi server: SnackBar + giữ nguyên dữ liệu đã nhập.

### Màn 4: Trang "Bạn" (Account)

Trung tâm cá nhân của người dùng: thông tin tài khoản, lối tắt tới Lịch sử, Playlist, Video của bạn, Cài đặt; khi chưa đăng nhập thì mời đăng nhập.

**Thành phần hiển thị (đã đăng nhập)**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | Icon Cast, Chuông, Tìm kiếm, Cài đặt | Chuông có badge số thông báo chưa đọc |
| Header | Avatar lớn, tên hiển thị | Bấm avatar → bottom sheet đổi ảnh đại diện |
| Header | "@handle · Xem kênh >" | Bấm → Trang kênh của chính mình (Màn 11) |
| Header | Chip "Chuyển đổi tài khoản", "Tài khoản Google" | Cuộn ngang |
| Mục 1 | "Nhật ký xem" + "Xem tất cả" | Hàng ngang 10 video gần nhất, thumbnail nhỏ có thanh tiến độ đỏ |
| Mục 2 | "Danh sách phát" + nút "+" | Hàng ngang: Video đã thích, Xem sau, các playlist tự tạo (thumbnail + tên + số video) |
| Danh sách | Video của bạn | Icon play, dẫn tới danh sách video đã tải lên |
| Danh sách | Video đã tải xuống | Kèm dòng phụ "12 video" |
| Danh sách | Phim của bạn, Thời gian xem | Tùy chọn |
| Danh sách | Cài đặt, Trợ giúp & phản hồi |  |
| Danh sách | Đăng xuất | Chữ đỏ, cuối cùng |
| Đáy | Bottom Navigation | Tab "Bạn" đang chọn, icon tab là avatar người dùng |

**Thành phần hiển thị (chưa đăng nhập)**

- Icon người dùng lớn, câu "Tận hưởng các video yêu thích", phụ đề "Đăng nhập để xem video đã thích, lịch sử và hơn thế nữa", nút "Đăng nhập" → Màn 2.
- Vẫn hiện mục Cài đặt và Trợ giúp.

**Chức năng**

1. Kéo xuống để làm mới (pull-to-refresh) lịch sử và playlist.
2. Bấm 1 video trong "Nhật ký xem" → Xem video (Màn 6), phát tiếp từ vị trí đã xem.
3. Nút "+" ở Danh sách phát → dialog tạo playlist: tên (bắt buộc, tối đa 150 ký tự) + chế độ Công khai / Không công khai / Riêng tư.
4. Nhấn giữ playlist → menu Đổi tên, Xóa (có xác nhận).
5. "Chuyển đổi tài khoản": bottom sheet danh sách tài khoản đã lưu + "Thêm tài khoản".
6. Đăng xuất: dialog xác nhận → xóa token, xóa cache người dùng → về Trang chủ chế độ khách.

**Điều hướng**

- "Xem tất cả" Nhật ký xem → Màn 13; playlist → Màn 14; Chuông → Màn 16; Tìm kiếm → Màn 9.
- "Video của bạn" → tab Video trên Trang kênh của mình (Màn 11) hoặc màn Studio (mở rộng).
- Cài đặt → màn Cài đặt (mở rộng).

**API**

- `GET /api/me` · `GET /api/me/history?size=10` · `GET /api/me/playlists` · `POST /api/playlists` · `POST /api/auth/logout`

**Trạng thái**

- Loading: shimmer cho header và 2 hàng ngang.
- Lịch sử trống: "Video bạn xem sẽ hiển thị ở đây".
- Lỗi: mỗi mục có nút "Thử lại" riêng, không làm hỏng cả màn.

## Người 2: Xem video

### Màn 5: Trang chủ (Home)

Feed video đề xuất cuộn vô hạn, lọc theo danh mục; đây là màn người dùng thấy nhiều nhất nên cần mượt và tải nhanh.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| App bar | Logo VTube | Bên trái; bấm khi đang ở Home thì cuộn lên đầu |
| App bar | Cast, Chuông (badge đỏ), Tìm kiếm | Bên phải |
| Dưới app bar | ChipBar danh mục | Chip đầu là icon la bàn "Khám phá", sau đó: Tất cả, Âm nhạc, Trò chơi, Trực tiếp, Tin tức, Hoạt hình, Thể thao, Mới tải lên, Đã xem |
| Feed | VideoCardLarge | Lặp lại theo danh sách |
| Feed | ShortsShelf | Chèn sau video thứ 3, tiêu đề "Shorts", 6–10 thumbnail dọc |
| Feed | Video trực tiếp | Badge đỏ "TRỰC TIẾP", dòng meta "1,2 N người đang xem" |
| Đáy | Bottom Navigation | Tab "Trang chủ" đang chọn |

**Chi tiết VideoCardLarge**

- Thumbnail 16:9 full chiều rộng, badge thời lượng góc dưới phải; video đã xem dở có thanh đỏ dưới thumbnail.
- Avatar kênh 36 px; tiêu đề tối đa 2 dòng, cắt "..."; dòng meta "Tên kênh · 1,2 Tr lượt xem · 3 ngày trước".
- Nút 3 chấm → VideoOptionsSheet.

**Chức năng**

1. Tải trang đầu 10–20 video; cuộn gần cuối (còn \~3 item) thì tải trang tiếp theo (phân trang bằng `page` hoặc `cursor`), hiện vòng quay ở cuối danh sách.
2. Kéo xuống để làm mới: tải lại feed từ đầu.
3. Chọn chip → lọc theo danh mục, cuộn về đầu, chip được chọn đổi nền trắng chữ đen.
4. App bar tự ẩn khi cuộn xuống và hiện lại khi cuộn lên (`SliverAppBar` với `floating: true, snap: true`).
5. Bấm thumbnail hoặc tiêu đề → Xem video; bấm avatar kênh → Trang kênh.
6. Menu 3 chấm: Lưu vào Xem sau, Lưu vào danh sách phát, Tải xuống, Chia sẻ (`share_plus`), Không quan tâm (ẩn video khỏi feed + SnackBar "Hoàn tác"), Báo cáo.
7. Nâng cao: tự phát không tiếng (autoplay muted) video đang nằm giữa màn hình khi cuộn dừng.

**Điều hướng**

- Video → Màn 6 · Shorts trong shelf → Màn 8, mở đúng short đã bấm · Avatar kênh → Màn 11 · Tìm kiếm → Màn 9 · Chuông → Màn 16.

**API**

- `GET /api/categories` · `GET /api/videos/feed?category=&page=` → { items, page, size, hasMore }
- `GET /api/shorts?size=10` · `POST /api/videos/{id}/not-interested` · `PUT /api/me/watch-later/{videoId}`

**Trạng thái**

- Loading lần đầu: 3–4 khung shimmer hình card.
- Danh mục không có video: "Chưa có video nào trong mục này".
- Lỗi: icon + "Đã xảy ra lỗi" + nút "Thử lại"; lỗi khi tải trang tiếp thì chỉ hiện nút "Thử lại" ở cuối danh sách.

### Màn 6: Xem video (Video Detail)

Màn phức tạp nhất app: phát video, hiện thông tin, tương tác (like, đăng ký, lưu) và gợi ý video tiếp theo. Nên bắt đầu sớm nhất.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Trên cùng (cố định) | Trình phát 16:9 | Luôn ghim trên đầu khi cuộn phần dưới |
| Overlay player | Nút thu nhỏ (mũi tên xuống), Cast, Phụ đề, Cài đặt | Góc trên |
| Overlay player | Lùi 10 giây, Play/Pause, Tới 10 giây | Giữa |
| Overlay player | Thời gian "1:23 / 10:05", thanh tiến độ đỏ (có lớp đã buffer màu xám), nút Toàn màn hình | Dưới |
| Thông tin | Tiêu đề | Tối đa 2 dòng, bấm mở mô tả |
| Thông tin | "245 N lượt xem · 2 tuần trước #hashtag ...thêm" |  |
| Hàng kênh | Avatar, tên kênh, "1,5 Tr" người đăng ký, SubscribeButton |  |
| Hàng hành động | Like/Dislike, Chia sẻ, Remix, Tải xuống, Lưu, Báo cáo | Pill cuộn ngang; Like và Dislike chung một pill, hiện số like |
| Bình luận | Thẻ "Bình luận 1,2 N" | Hiện avatar + 1 bình luận nổi bật; bấm mở Màn 7 |
| Gợi ý | Chip: Tất cả, Từ kênh này, Có liên quan, Mới tải lên |  |
| Gợi ý | Danh sách VideoCardLarge | Cuộn vô hạn |

**Chức năng trình phát**

1. Tự phát khi mở màn; dùng `video_player` + `chewie` hoặc `better_player`.
2. Chạm 1 lần: hiện/ẩn overlay, tự ẩn sau 3 giây.
3. Chạm đúp nửa trái/phải: lùi/tới 10 giây, có hiệu ứng gợn sóng và chữ "10 giây".
4. Kéo thanh tiến độ để tua, hiện thời gian đang tua.
5. Cài đặt (bottom sheet): Chất lượng (Tự động, 1080p, 720p, 480p, 360p), Tốc độ phát (0,25x → 2x), Phụ đề, Lặp lại video.
6. Toàn màn hình: xoay ngang (`SystemChrome.setPreferredOrientations`), ẩn status bar; xoay điện thoại cũng tự vào toàn màn hình.
7. Hết video: hiện màn "Tiếp theo" đếm ngược 5 giây rồi tự phát video gợi ý đầu tiên, có nút Hủy.
8. Ghi lịch sử: cứ 10 giây (và khi rời màn) lưu `progressSeconds` để phát tiếp lần sau.
9. Nâng cao: kéo player xuống → thu thành Mini player ở đáy màn hình.

**Chức năng tương tác**

1. Like/Dislike: đổi icon đặc/rỗng, cập nhật số ngay lập tức (optimistic update), gọi API; lỗi thì hoàn lại. Like và Dislike loại trừ nhau.
2. Đăng ký: "Đăng ký" → "Đã đăng ký" + chuông; bấm lại mở sheet: Tất cả thông báo, Cá nhân hóa, Không nhận, Hủy đăng ký (có dialog xác nhận).
3. Lưu: bottom sheet danh sách playlist có checkbox (Xem sau, các playlist) + "Danh sách phát mới".
4. Chia sẻ: sheet hệ thống, nội dung là link video giả lập.
5. Tải xuống: chọn chất lượng → hiện tiến độ trên nút, xong đổi thành "Đã tải xuống" (giả lập hoặc tải file thật).
6. Mô tả (bấm "...thêm"): bottom sheet gồm tiêu đề, số like / lượt xem / ngày đăng dạng 3 cột, mô tả đầy đủ có link bấm được, hashtag.

**Điều hướng**

- Avatar/tên kênh → Màn 11 · Thẻ bình luận → Màn 7 · Video gợi ý → thay video hiện tại (không chồng thêm màn mới) · Back → màn trước.

**API**

- `GET /api/videos/{id}` (có `viewer` khi đã đăng nhập) · `GET /api/videos/{id}/related?filter=all|channel|related|recent&page=`
- `POST /api/videos/{id}/view` · `PUT /api/videos/{id}/reaction` { value: 1 | -1 | 0 }
- `PUT /api/channels/{id}/subscription` { notifyMode } · `DELETE /api/channels/{id}/subscription` · `PUT /api/me/history/{videoId}` { progressSeconds }

**Trạng thái**

- Đang buffer: vòng quay giữa player.
- Video lỗi/bị xóa: player đen + "Video này không còn khả dụng".
- Video riêng tư: "Video riêng tư" kèm icon khóa.
- Mất mạng giữa chừng: dừng phát, hiện "Không có kết nối. Nhấn để thử lại".

### Màn 7: Bình luận

Bottom sheet nổi trên màn Xem video (video vẫn phát phía trên), cho đọc, viết, trả lời và tương tác với bình luận.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Đầu sheet | Thanh kéo + tiêu đề "Bình luận" + tổng số | Nút X bên phải |
| Đầu sheet | Chip "Hàng đầu" / "Mới nhất" | Sắp xếp |
| Danh sách | Bình luận được ghim | Icon ghim + "Được ghim bởi @kenh", luôn đứng đầu |
| Mỗi bình luận | Avatar, "@username · 2 ngày trước" | Chủ kênh có nhãn tên nền xám |
| Mỗi bình luận | Nội dung | Dài hơn 4 dòng thì cắt + "Đọc thêm" |
| Mỗi bình luận | Like + số, Dislike, Trả lời, 3 chấm | Có biểu tượng tim nếu chủ kênh đã thả tim |
| Mỗi bình luận | Link "12 phản hồi" | Màu xanh, bấm mở luồng trả lời |
| Đáy (cố định) | Avatar mình + ô "Thêm bình luận..." | Nút gửi hiện khi có chữ |

**Chức năng**

1. Sheet mở ở 75% chiều cao, kéo lên được 100%, kéo xuống để đóng (`DraggableScrollableSheet`).
2. Phân trang 20 bình luận/lần khi cuộn.
3. Viết bình luận: tối đa 500 ký tự (hiện bộ đếm khi gần đầy), không cho gửi chuỗi toàn khoảng trắng. Gửi xong chèn lên đầu danh sách, xóa ô nhập, ẩn bàn phím.
4. Trả lời: bấm "Trả lời" → mở luồng phản hồi (sheet con hoặc trang con có nút Back), ô nhập tự điền "@username " và focus.
5. Like/Dislike bình luận: optimistic update như màn Xem video.
6. Menu 3 chấm: bình luận của mình → Chỉnh sửa, Xóa (có xác nhận); của người khác → Báo cáo; nếu mình là chủ kênh → Ghim, Thả tim, Ẩn người dùng.
7. Chưa đăng nhập: ô nhập thay bằng "Đăng nhập để bình luận".
8. Bấm avatar người bình luận → kênh của họ.

**Điều hướng**

- Đóng sheet → trở lại Xem video, video không bị dừng · Avatar → Màn 11.

**API**

- `GET /api/videos/{id}/comments?sort=top|new&page=` · `GET /api/comments/{id}/replies?page=`
- `POST /api/videos/{id}/comments` { content, parentId? } · `PUT /api/comments/{id}` · `DELETE /api/comments/{id}`
- `PUT /api/comments/{id}/reaction` { value } · `PUT /api/comments/{id}/pin` · `PUT /api/comments/{id}/heart`

**Trạng thái**

- Chưa có bình luận: "Chưa có bình luận nào. Hãy là người đầu tiên!".
- Chủ kênh tắt bình luận: "Bình luận đã bị tắt".
- Gửi lỗi: bình luận hiện mờ + "Không gửi được. Nhấn để thử lại".

### Màn 8: Shorts

Video dọc ngắn (tối đa 60 giây) phát toàn màn hình, vuốt lên/xuống để chuyển video, tự lặp lại.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Nền | Video 9:16 | Toàn màn hình, `BoxFit.cover` |
| Trên cùng | Icon Tìm kiếm, Camera, 3 chấm | Nền trong suốt |
| Cột phải | Like + số | Icon to, chữ số nhỏ bên dưới |
| Cột phải | Dislike, Bình luận + số, Chia sẻ, Remix |  |
| Cột phải (cuối) | Ô vuông nhạc | Ảnh bìa bài nhạc, xoay chậm |
| Góc dưới trái | Avatar + @kenh + nút "Đăng ký" đỏ |  |
| Góc dưới trái | Chú thích + hashtag | 2 dòng, bấm mở rộng |
| Góc dưới trái | Icon nốt nhạc + tên bài nhạc | Chữ chạy ngang nếu dài |
| Đáy video | Thanh tiến độ mảnh | Màu trắng/đỏ |
| Đáy | Bottom Navigation | Tab "Shorts" đang chọn, nền đen |

**Chức năng**

1. `PageView` dọc: mỗi trang một short, vuốt để chuyển, video tự phát khi trang hiện ra và dừng khi rời đi.
2. Tải trước (preload) 1–2 video tiếp theo; giải phóng controller của video đã cách xa để tránh tràn bộ nhớ.
3. Hết video thì tự phát lại từ đầu.
4. Chạm 1 lần: Tạm dừng/Tiếp tục, hiện icon play/pause lớn giữa màn rồi mờ dần.
5. Chạm đúp: Like, hiện trái tim bay lên tại vị trí chạm.
6. Nhấn giữ: phát 2x trong lúc giữ (tùy chọn).
7. Bình luận: mở lại Màn 7 dạng bottom sheet.
8. Đăng ký: nút đổi thành "Đã đăng ký" màu xám.
9. Tải thêm khi còn 3 short chưa xem.
10. Mở từ ShortsShelf: nhảy đúng tới short đã bấm (`initialPage`).

**Điều hướng**

- Avatar/@kenh → Màn 11 (tab Shorts) · Bình luận → Màn 7 · Tìm kiếm → Màn 9 · Đổi tab khác → dừng video.

**API**

- `GET /api/shorts?page=` · dùng chung API reaction, subscription, comments, view, history với video thường.

**Trạng thái**

- Đang tải: nền đen + vòng quay.
- Hết short: trang cuối "Bạn đã xem hết Shorts" + nút "Làm mới".
- Lỗi một video: tự bỏ qua sang video tiếp theo.

## Người 3: Khám phá & Kênh

### Màn 9: Tìm kiếm

Ô nhập từ khóa với lịch sử tìm kiếm và gợi ý theo thời gian thực; bấm một gợi ý là sang Kết quả tìm kiếm.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | Nút Back |  |
| Top bar | Ô tìm kiếm bo tròn | Placeholder "Tìm kiếm trên VTube", tự focus và mở bàn phím, nút X xóa chữ khi có nội dung |
| Top bar | Icon micro | Tìm bằng giọng nói |
| Danh sách (ô trống) | Lịch sử tìm kiếm | Icon đồng hồ + từ khóa + icon mũi tên chéo ↖ bên phải; tối đa 10 mục mới nhất |
| Danh sách (đang gõ) | Gợi ý | Icon kính lúp + từ khóa, phần trùng với chữ đã gõ in thường, phần còn lại in đậm |
| Danh sách (đang gõ) | Gợi ý có thumbnail | Tùy chọn: thumbnail nhỏ bên phải cho gợi ý khớp một video cụ thể |

**Chức năng**

1. Ô trống: hiện lịch sử tìm kiếm (lưu local bằng `shared_preferences`/SQLite, hoặc lấy từ server nếu đã đăng nhập).
2. Đang gõ: gọi API gợi ý sau khi ngừng gõ 300 ms (debounce), hủy request cũ nếu có request mới.
3. Bấm icon ↖: điền từ khóa đó vào ô để sửa tiếp, chưa tìm ngay.
4. Nhấn giữ một mục lịch sử: dialog "Xóa khỏi nhật ký tìm kiếm?".
5. Bấm Enter / nút tìm trên bàn phím hoặc bấm 1 gợi ý: lưu từ khóa vào lịch sử (đưa lên đầu, không trùng lặp) rồi chuyển sang Màn 10.
6. Không cho tìm chuỗi rỗng hoặc toàn khoảng trắng.
7. Micro: dùng `speech_to_text`, hiện dialog "Đang nghe..." với hiệu ứng sóng; nhận dạng xong thì tự tìm.

**Điều hướng**

- Tìm → Màn 10 (dùng `push`, Back từ kết quả quay lại đây và giữ nguyên từ khóa) · Back → màn trước.

**API**

- `GET /api/search/suggestions?q=` → { history, suggestions } · `DELETE /api/me/search-history?keyword=`

**Trạng thái**

- Chưa có lịch sử: màn trống, chỉ có ô tìm kiếm.
- Không có gợi ý: chỉ hiện 1 dòng "Tìm "\<từ khóa>"".
- Chưa cấp quyền micro: dialog giải thích + nút mở Cài đặt.

### Màn 10: Kết quả tìm kiếm

Hiện video, short và kênh khớp từ khóa, có chip phân loại và bộ lọc nâng cao.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | Back, ô chứa từ khóa, micro, icon bộ lọc | Bấm ô → quay về Màn 9 với từ khóa đã điền |
| Dưới top bar | Chip: Tất cả, Video, Shorts, Kênh, Danh sách phát, Chưa xem, Đã xem, Mới tải lên |  |
| Đầu kết quả | Thẻ kênh (nếu khớp tên kênh) | Avatar lớn, tên + tích xanh, "@handle · 1,5 Tr người đăng ký", SubscribeButton |
| Kết quả | VideoCardCompact | Thumbnail trái + tiêu đề 2 dòng, tên kênh, lượt xem · thời gian |
| Kết quả | ShortsShelf | Chèn sau khoảng 4 kết quả |
| Kết quả | Thẻ playlist | Thumbnail có lớp "12 video" + icon danh sách |
| Kết quả | Mục "Mọi người cũng tìm kiếm" | Danh sách từ khóa liên quan (tùy chọn) |

**Bộ lọc (bottom sheet khi bấm icon lọc)**

| Nhóm | Lựa chọn |
| --- | --- |
| Ngày tải lên | Mọi lúc, Hôm nay, Tuần này, Tháng này, Năm nay |
| Loại | Tất cả, Video, Kênh, Danh sách phát |
| Thời lượng | Mọi thời lượng, Dưới 4 phút, 4–20 phút, Trên 20 phút |
| Sắp xếp theo | Mức độ liên quan, Ngày tải lên, Lượt xem, Xếp hạng |

**Chức năng**

1. Tìm theo tiêu đề, mô tả, hashtag, tên kênh; phân trang khi cuộn.
2. Chọn chip hoặc áp bộ lọc → tải lại kết quả; icon lọc có chấm đỏ khi đang có bộ lọc khác mặc định.
3. Nút "Đặt lại" trong bottom sheet lọc đưa về mặc định.
4. Đăng ký kênh ngay trên thẻ kênh.
5. Menu 3 chấm của video dùng chung VideoOptionsSheet.
6. Tùy chọn: in đậm từ khóa trùng trong tiêu đề.

**Điều hướng**

- Video → Màn 6 · Short → Màn 8 · Kênh → Màn 11 · Playlist → Màn 14 · Ô tìm kiếm → Màn 9.

**API**

- `GET /api/search?q=&type=&uploadDate=&duration=&sort=&page=` → { channels, videos, shorts, playlists, page, hasMore }

**Trạng thái**

- Không có kết quả: hình minh họa + "Không tìm thấy kết quả nào cho "\<từ khóa>"" + gợi ý "Hãy thử từ khóa khác hoặc bỏ bộ lọc".
- Loading: shimmer dạng card compact.

### Màn 11: Trang kênh (Channel)

Hồ sơ công khai của một kênh: banner, thông tin, nút đăng ký và các tab nội dung; khi là kênh của chính mình thì đổi sang nút quản lý.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | Back, tên kênh (hiện khi cuộn qua header), Cast, Tìm kiếm, 3 chấm |  |
| Header | Banner | Tỉ lệ khoảng 6:1, ảnh mặc định nếu chưa có |
| Header | Avatar lớn + tên kênh + tích xanh |  |
| Header | "@handle · 1,5 Tr người đăng ký · 320 video" |  |
| Header | Mô tả ngắn "...thêm" + 1 link | Bấm mở sheet Giới thiệu |
| Header | Nút "Đăng ký" (kênh khác) | Hoặc "Tùy chỉnh kênh" + "Quản lý video" (kênh của mình) |
| Tab bar (ghim khi cuộn) | Trang chủ, Video, Shorts, Danh sách phát, Cộng đồng, Giới thiệu | Gạch chân đỏ dưới tab đang chọn |

**Nội dung từng tab**

| Tab | Hiển thị |
| --- | --- |
| Trang chủ | Video nổi bật (player lớn), hàng ngang "Video", hàng Shorts, hàng các playlist |
| Video | Chip Mới nhất / Phổ biến / Cũ nhất + danh sách VideoCardCompact |
| Shorts | Lưới 3 cột thumbnail dọc + lượt xem |
| Danh sách phát | Danh sách playlist (thumbnail + tên + số video) |
| Cộng đồng | Bài đăng chữ/ảnh của kênh, có like và bình luận (tùy chọn) |
| Giới thiệu | Mô tả đầy đủ, link, ngày tham gia, tổng lượt xem, quốc gia, nút Chia sẻ kênh |

**Chức năng**

1. Header co giãn khi cuộn (`NestedScrollView` + `SliverAppBar`), tab bar ghim lại (`SliverPersistentHeader`).
2. Đăng ký/Hủy đăng ký và chọn chế độ chuông như ở Màn 6; số người đăng ký cập nhật ngay.
3. Mỗi tab tải dữ liệu riêng khi lần đầu mở (lazy load) và phân trang khi cuộn.
4. Đổi sắp xếp ở tab Video → tải lại.
5. Menu 3 chấm: Chia sẻ kênh, Chặn người dùng, Báo cáo người dùng.
6. Kênh của mình: "Tùy chỉnh kênh" → màn Chỉnh sửa hồ sơ (mở rộng) để đổi banner, avatar, tên, mô tả; "Quản lý video" → danh sách video của mình có Sửa / Xóa.
7. Icon tìm kiếm trên top bar: tìm trong phạm vi kênh này.

**Điều hướng**

- Video → Màn 6 · Short → Màn 8 · Playlist → Màn 14 · Back → màn trước.

**API**

- `GET /api/channels/{id}` · `GET /api/channels/{id}/videos?sort=newest|popular|oldest&page=` · `GET /api/channels/{id}/shorts` · `GET /api/channels/{id}/playlists`
- `PUT /api/channels/me` (kênh của mình) · `PUT` / `DELETE /api/channels/{id}/subscription`

**Trạng thái**

- Kênh chưa có video: "Kênh này không có nội dung nào"; kênh của mình thì thêm nút "Tải video lên" → Màn 15.
- Kênh không tồn tại: "Kênh này không có sẵn".

### Màn 12: Kênh đăng ký (Subscriptions)

Feed video mới nhất từ các kênh người dùng đã đăng ký, sắp theo thời gian đăng, kèm hàng avatar kênh để lọc nhanh.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| App bar | Giống Trang chủ | Logo, Cast, Chuông, Tìm kiếm |
| Hàng kênh | Avatar tròn + tên kênh bên dưới | Cuộn ngang; chấm xanh dưới kênh có video chưa xem |
| Hàng kênh | Chữ "Tất cả" ở cuối | Màu xanh |
| Dưới hàng kênh | Chip: Tất cả, Hôm nay, Video, Shorts, Trực tiếp, Bài đăng, Tiếp tục xem, Chưa xem |  |
| Feed | VideoCardLarge | Sắp xếp mới nhất trước |
| Feed | ShortsShelf "Shorts từ kênh đăng ký" |  |
| Feed | Video trực tiếp | Badge đỏ "TRỰC TIẾP" |
| Đáy | Bottom Navigation | Tab "Kênh đăng ký" đang chọn |

**Chức năng**

1. Bấm 1 avatar: lọc feed chỉ còn video của kênh đó, avatar được viền nổi bật, hiện thêm nút "Xem kênh" → Màn 11. Bấm lại để bỏ lọc.
2. Bấm "Tất cả": mở trang danh sách tất cả kênh đã đăng ký (avatar, tên, icon chuông), có sắp xếp: Liên quan nhất, Hoạt động mới, A–Z.
3. Trong trang "Tất cả": đổi chế độ chuông hoặc hủy đăng ký từng kênh.
4. Chọn chip để lọc theo loại nội dung hoặc thời gian.
5. Kéo xuống để làm mới, phân trang khi cuộn.
6. Video đã xem xong thì hiện thanh đỏ đầy dưới thumbnail.

**Điều hướng**

- Video → Màn 6 · Short → Màn 8 · "Xem kênh" → Màn 11.

**API**

- `GET /api/me/subscriptions?sort=recent|az|relevance` · `GET /api/me/subscriptions/feed?channelId=&type=&page=` · `PUT /api/channels/{id}/subscription` { notifyMode }

**Trạng thái**

- Chưa đăng nhập: icon + "Đừng bỏ lỡ video mới" + nút "Đăng nhập".
- Chưa đăng ký kênh nào: "Hãy đăng ký kênh để xem video mới nhất tại đây" + nút "Khám phá kênh" → Trang chủ.

## Người 4: Thư viện & Tạo nội dung

### Màn 13: Lịch sử xem

Danh sách video đã xem, nhóm theo ngày, có tìm kiếm trong lịch sử, xóa từng mục, xóa tất cả và tạm dừng ghi lịch sử.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | Back, tiêu đề "Nhật ký xem", Tìm kiếm, 3 chấm |  |
| Dưới top bar | Chip: Tất cả, Video, Shorts, Nhạc |  |
| Danh sách | Tiêu đề nhóm ngày | "Hôm nay", "Hôm qua", "Thứ Hai", "Tuần trước", "15 thg 9, 2026" |
| Danh sách | VideoCardCompact | Thanh đỏ dưới thumbnail theo % đã xem, nút 3 chấm |
| Danh sách | ShortsShelf theo ngày | Các short đã xem trong ngày gom thành 1 hàng ngang |

**Chức năng**

1. Nhóm theo ngày dựa trên `watchedAt`; một video xem nhiều lần chỉ giữ lần mới nhất.
2. Vuốt trái 1 mục (`Dismissible`) hoặc chọn "Xóa khỏi nhật ký xem" trong menu → xóa, SnackBar "Đã xóa" + "Hoàn tác".
3. Tìm trong lịch sử: ô tìm kiếm thay tiêu đề, lọc theo tiêu đề video/tên kênh ngay khi gõ.
4. Menu 3 chấm trên top bar: "Xóa toàn bộ nhật ký xem" (dialog xác nhận, chữ đỏ), "Tạm dừng nhật ký xem" (bật/tắt; khi tạm dừng thì hiện banner vàng "Nhật ký xem đang bị tạm dừng"), "Quản lý toàn bộ hoạt động".
5. Bấm video → Xem video, phát tiếp từ `progressSeconds`.
6. Phân trang khi cuộn.

**Điều hướng**

- Video → Màn 6 · Short → Màn 8 · Back → Màn 4.

**API**

- `GET /api/me/history?type=all|video|short|music&q=&page=` · `DELETE /api/me/history/{videoId}` · `DELETE /api/me/history` · `PATCH /api/me/settings` { historyPaused }

**Trạng thái**

- Trống: icon đồng hồ + "Nhật ký xem của bạn sẽ xuất hiện tại đây".
- Chưa đăng nhập: "Đăng nhập để xem nhật ký" + nút Đăng nhập.
- Tìm không thấy: "Không tìm thấy video nào trong nhật ký".

### Màn 14: Chi tiết Playlist

Xem và quản lý một danh sách phát: Video đã thích, Xem sau, playlist tự tạo, hoặc playlist công khai của kênh khác.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Nền header | Ảnh thumbnail video đầu, làm mờ + phủ màu tối | Màu phủ lấy theo màu chủ đạo của ảnh (`palette_generator`, tùy chọn) |
| Top bar | Back, Cast, Tìm kiếm, 3 chấm |  |
| Header | Thumbnail lớn 16:9 |  |
| Header | Tên playlist | Chữ to, đậm |
| Header | "Tên người tạo · 48 video · 2,3 N lượt xem" |  |
| Header | Chế độ hiển thị + icon | Riêng tư (khóa), Không công khai (link), Công khai (quả địa cầu) |
| Header | Icon Sửa, Chia sẻ, Tải xuống | Hàng icon tròn nhỏ |
| Header | Nút "Phát tất cả" (trắng) + "Trộn bài" (xám) |  |
| Danh sách | Chip "Sắp xếp" | Thủ công, Ngày thêm (mới nhất), Ngày thêm (cũ nhất), Phổ biến nhất, Ngày xuất bản |
| Danh sách | Mỗi video | Số thứ tự hoặc icon kéo thả, thumbnail nhỏ, tiêu đề, tên kênh, 3 chấm |

**Chức năng**

1. "Phát tất cả": mở Xem video với video đầu; màn Xem video hiện thêm khung "Danh sách phát" (tên, 3/48, nút Lặp lại, Trộn) và tự chuyển video kế tiếp khi hết.
2. "Trộn bài": như trên nhưng thứ tự ngẫu nhiên.
3. Kéo thả để đổi thứ tự (`ReorderableListView`), chỉ bật khi sắp xếp "Thủ công" và là playlist của mình.
4. Menu 3 chấm của video: Xóa khỏi danh sách (SnackBar "Hoàn tác"), Di chuyển lên đầu/xuống cuối, Lưu vào danh sách phát khác, Chia sẻ.
5. Icon Sửa: dialog đổi tên, mô tả, chế độ hiển thị.
6. Menu 3 chấm trên top bar: Xóa danh sách phát (dialog xác nhận). "Video đã thích" và "Xem sau" không cho xóa hay đổi tên.
7. Playlist của người khác: thay icon Sửa bằng nút "Lưu vào thư viện".
8. Tải xuống: tải cả playlist (giả lập), hiện tiến độ "Đang tải 3/48".

**Điều hướng**

- Video → Màn 6 (kèm ngữ cảnh playlist) · Tên người tạo → Màn 11 · Back → màn trước.

**API**

- `GET /api/playlists/{id}?sort=` · `PUT /api/playlists/{id}` · `DELETE /api/playlists/{id}` · `DELETE /api/playlists/{id}/videos/{videoId}` · `PUT /api/playlists/{id}/order` { videoIds }
- Sheet "Lưu vào danh sách phát": `GET /api/me/playlists?videoId=` · `POST /api/playlists/{id}/videos` { videoId }

**Trạng thái**

- Playlist trống: "Chưa có video nào trong danh sách phát này".
- Playlist riêng tư của người khác: "Danh sách phát này là riêng tư".

### Màn 15: Tải video lên (Upload)

Luồng 2 bước: chọn video từ máy, rồi nhập thông tin và tải lên; video xuất hiện trên kênh khi xử lý xong.

**Bước 1: Chọn video**

- Top bar: X đóng, tiêu đề "Chọn video".
- Lưới 3 cột video trong máy (thumbnail + thời lượng), ô đầu là nút "Quay video" mở camera.
- Chọn 1 video → sang Bước 2. Video dưới 60 giây và quay dọc thì hỏi "Tải lên dưới dạng Short?".

**Bước 2: Thêm thông tin (thành phần hiển thị)**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | X, tiêu đề "Thêm thông tin", nút "Tải lên" | Nút đỏ, disabled khi thiếu tiêu đề |
| Đầu màn | Xem trước video 16:9 | Phát/tạm dừng được |
| Dưới video | Nút "Đổi hình thu nhỏ" | Chọn 1 khung hình từ video hoặc ảnh từ thư viện |
| Form | Tiêu đề | Bắt buộc, bộ đếm 0/100 |
| Form | Mô tả | Nhiều dòng, tối đa 5000 ký tự |
| Cài đặt | Chế độ hiển thị | Công khai / Không công khai / Riêng tư / Lên lịch (chọn ngày giờ) |
| Cài đặt | Danh sách phát | Chọn nhiều playlist |
| Cài đặt | Đối tượng người xem | "Có, nội dung dành cho trẻ em" / "Không" |
| Cài đặt | Danh mục | Âm nhạc, Trò chơi, Giáo dục, Giải trí... |
| Cài đặt | Thẻ (tags) | Nhập rồi Enter thành chip, xóa được |
| Cài đặt | Bình luận | Cho phép / Tắt |
| Đáy | Thẻ tiến độ | "Đang tải lên 65%", thanh đỏ, nút Hủy |

**Chức năng**

1. Xin quyền truy cập ảnh/video (`permission_handler`); chọn file bằng `image_picker` hoặc `file_picker`.
2. Giới hạn dung lượng (ví dụ 200 MB) và định dạng (mp4, mov); vượt quá thì báo lỗi.
3. Tự tạo thumbnail mặc định từ giây thứ 1 (`video_thumbnail`).
4. Bấm "Tải lên": kiểm tra form → upload file video và thumbnail (multipart, có `onSendProgress` nếu dùng Dio, hoặc Firebase Storage) → tạo bản ghi video.
5. Có thể rời màn khi đang tải; tiến độ hiện bằng notification hệ thống hoặc thanh nhỏ trên Trang chủ (nâng cao).
6. Hủy giữa chừng: dialog xác nhận → hủy request.
7. Bấm X khi đã nhập: dialog "Hủy tải lên? Thông tin sẽ không được lưu".
8. Xong: SnackBar "Video đã được tải lên" + "Xem".

**Điều hướng**

- Mở từ nút (+) Tạo trên Bottom Navigation hoặc từ Trang kênh của mình · Xong → Trang kênh của mình, tab Video (Màn 11).

**API**

- `POST /api/uploads` (multipart: file, type=video | image) → { url, fileName, size }
- `POST /api/videos` { title, description, thumbnailUrl, videoUrl, durationSeconds, categoryId, shortVideo, visibility, commentsEnabled, madeForKids, tags }

**Trạng thái**

- Chưa cấp quyền: màn giải thích + nút "Cho phép truy cập".
- Lỗi tải lên: thẻ tiến độ đổi đỏ "Tải lên thất bại" + "Thử lại".
- Không có video trong máy: "Không tìm thấy video nào".

### Màn 16: Thông báo

Danh sách thông báo về video mới từ kênh đã đăng ký, phản hồi bình luận, lượt nhắc; đọc rồi thì mờ đi và badge chuông giảm.

**Thành phần hiển thị**

| Vị trí | Thành phần | Chi tiết |
| --- | --- | --- |
| Top bar | Back, tiêu đề "Thông báo", Cast, Tìm kiếm, 3 chấm |  |
| Dưới top bar | Chip "Tất cả" / "Lượt nhắc" |  |
| Danh sách | Tiêu đề nhóm | "Quan trọng", "Mới", "Trước đó" |
| Mỗi thông báo | Chấm xanh chưa đọc | Bên trái |
| Mỗi thông báo | Avatar kênh/người dùng |  |
| Mỗi thông báo | Nội dung 3 dòng | Ví dụ "Kênh ABC đã tải lên: Tên video...", "@user đã trả lời: "Hay quá!"" |
| Mỗi thông báo | Thời gian | "2 giờ trước" |
| Mỗi thông báo | Thumbnail 16:9 nhỏ | Bên phải |
| Mỗi thông báo | 3 chấm |  |

**Các loại thông báo**

| Loại | Nội dung mẫu | Bấm vào sẽ mở |
| --- | --- | --- |
| Video mới | "Kênh ABC đã tải lên: ..." | Màn 6 |
| Short mới | "Kênh ABC đã đăng một Short" | Màn 8 |
| Đang phát trực tiếp | "Kênh ABC đang phát trực tiếp: ..." | Màn 6 |
| Trả lời bình luận | "@user đã trả lời bình luận của bạn: ..." | Màn 6 + mở Màn 7 cuộn tới bình luận đó |
| Thích bình luận / thả tim | "Kênh ABC đã thả tim bình luận của bạn" | Như trên |
| Người đăng ký mới (kênh của mình) | "@user đã đăng ký kênh của bạn" | Màn 11 của người đó |
| Video đã xử lý xong | "Video của bạn đã sẵn sàng" | Màn 6 |

**Chức năng**

1. Mở màn: đánh dấu tất cả là "đã xem" để badge chuông về 0; từng mục chỉ thành "đã đọc" (mờ, mất chấm xanh) khi bấm vào.
2. Menu 3 chấm của mục: Ẩn thông báo này, Tắt thông báo từ kênh này.
3. Menu 3 chấm top bar: Đánh dấu tất cả là đã đọc, Cài đặt thông báo.
4. Kéo xuống làm mới, phân trang khi cuộn.
5. Nâng cao: nhận push notification thật bằng Firebase Cloud Messaging; bấm push thì mở thẳng nội dung tương ứng.

**Điều hướng**

- Theo bảng "Các loại thông báo" · Back → màn trước.

**API**

- `GET /api/me/notifications?type=all|mention&page=` · `GET /api/me/notifications/unread-count` · `PUT /api/notifications/{id}/read` · `PUT /api/me/notifications/read-all` · `DELETE /api/notifications/{id}`

**Trạng thái**

- Trống: icon chuông + "Thông báo của bạn sẽ hiển thị ở đây" + "Đăng ký kênh để nhận thông báo về video mới nhất".
- Chưa đăng nhập: nút "Đăng nhập".

## Màn hình mở rộng (khi còn thời gian)

Mỗi màn dưới đây gắn với luồng của một người để dễ nhận thêm; cột "Gợi ý giao cho" chỉ là đề xuất.

| Màn hình | Hiển thị & chức năng chính | Mở từ | Gợi ý giao cho |
| --- | --- | --- | --- |
| Onboarding | 3 trang giới thiệu có hình minh họa, chấm chỉ trang, nút "Bỏ qua" và "Bắt đầu"; chỉ hiện lần đầu mở app | Splash | Người 1 |
| Quên mật khẩu | Nhập email → nhập mã OTP 6 số (đếm ngược 60 giây, gửi lại) → đặt mật khẩu mới | Đăng nhập | Người 1 |
| Chỉnh sửa hồ sơ / kênh | Đổi avatar, banner, tên, handle, mô tả, link; nút Lưu, cảnh báo khi rời màn chưa lưu | Trang "Bạn", Trang kênh | Người 1 |
| Cài đặt | Giao diện Sáng/Tối/Theo hệ thống, ngôn ngữ, chất lượng mặc định (Wi-Fi / dữ liệu di động), tự phát video, bật/tắt thông báo, xóa lịch sử tìm kiếm, phiên bản app | Trang "Bạn" | Người 1 |
| Mini player | Player thu nhỏ ở đáy (thumbnail, tiêu đề, Play/Pause, X), vuốt lên để mở lại, giữ vị trí phát khi chuyển tab | Xem video | Người 2 |
| Toàn màn hình ngang | Player xoay ngang, vuốt lên để xem video gợi ý, vuốt dọc mép trái/phải để chỉnh độ sáng/âm lượng | Xem video | Người 2 |
| Khám phá / Thịnh hành | Lưới danh mục (Thịnh hành, Âm nhạc, Trò chơi, Tin tức, Thể thao...) + top 50 video thịnh hành có số thứ tự | Chip la bàn ở Trang chủ | Người 3 |
| Tất cả kênh đăng ký | Danh sách kênh, sắp xếp, đổi chuông, hủy đăng ký | Kênh đăng ký | Người 3 |
| Video đã tải xuống | Danh sách video offline, dung lượng đã dùng, xóa, phát không cần mạng | Trang "Bạn" | Người 4 |
| VTube Studio | Tổng quan kênh (lượt xem, thời gian xem, người đăng ký 28 ngày qua dạng biểu đồ), danh sách video của mình với Sửa / Xóa / đổi chế độ hiển thị | Trang "Bạn", Trang kênh | Người 4 |
| Chỉnh sửa video | Sửa tiêu đề, mô tả, thumbnail, chế độ hiển thị của video đã đăng; xóa video | Studio | Người 4 |
| Báo cáo video | Danh sách lý do (radio) + ô mô tả + nút Gửi | Menu 3 chấm | Người 4 |
