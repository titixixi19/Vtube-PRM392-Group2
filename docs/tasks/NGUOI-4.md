# Người 4: Thư viện & Tạo nội dung

- **Thư mục code**: `mobile/lib/features/library/`, và file dùng chung được giao: `mobile/lib/shared/widgets/save_to_playlist_sheet.dart`
- **Review chéo với**: Người 3
- **Thứ tự nên làm**: Màn 16 → Màn 13 → Màn 14 (+ sheet Lưu vào danh sách phát) → Màn 15

Phần dùng chung đã có sẵn:
- **Service**: `HistoryService`, `PlaylistService`, `NotificationService`, `UploadService`, `VideoService`, `AuthService`
- **Widget**: `VideoCardCompact`, `VideoThumbnail`, `ChannelAvatar`, `AppNetworkImage`, `ChipBar`, `EmptyView`
- **Package**: `image_picker`, `video_player` (để xem trước video ở màn 15)

---

## Màn 16: Thông báo (`notifications_screen.dart`)

- **Thiết kế**: `design/stitch/16._th_ng_b_o/` (ảnh chụp bị lỗi, mở `code.html` để xem).

**Việc cần làm**
- [ ] AppBar gồm Back, "Thông báo", icon Cast, Tìm kiếm, 3 chấm (Đánh dấu tất cả đã đọc, Cài đặt thông báo).
- [ ] Chip "Tất cả" (`type: all`) / "Lượt nhắc" (`mention`).
- [ ] Nhóm "Mới" (chưa đọc) và "Trước đó" (đã đọc); "Đánh dấu tất cả đã đọc" → `markAllRead`.
- [ ] Mỗi mục:
  - Chấm xanh khi chưa đọc, avatar `actor` kèm icon nhỏ theo `type`
  - Nội dung 3 dòng, thời gian
  - Thumbnail video (nếu có) bên phải, menu 3 chấm (Ẩn thông báo → `delete`)
- [ ] Mục đã đọc hiển thị mờ hơn.
- [ ] Bấm mục → `markRead(id)` rồi điều hướng theo `type` (bảng trong `docs/API.md`):
  - `new_short` → `AppRoutes.shortsAt`
  - `new_subscriber` → `AppRoutes.channel(actor.id)`
  - Các loại còn lại → `AppRoutes.video(videoId)`
- [ ] Phân trang, kéo làm mới. Khách: nút Đăng nhập. Trống: "Thông báo của bạn sẽ hiển thị ở đây".

**Nghiệm thu**
1. Demo: 2 thông báo "Mới" có chấm xanh, badge chuông ở Trang chủ hiện 2.
2. Bấm thông báo video mới → mở đúng video; quay lại thì mục đó đã mờ, badge còn 1.
3. Chip "Lượt nhắc" chỉ còn thông báo trả lời bình luận.

## Màn 13: Lịch sử xem (`history_screen.dart`)

- **Thiết kế**: `design/stitch/13._l_ch_s_xem/`
- **Mẫu code**: `docs/CONVENTIONS.md` mục 6 chính là màn này ở dạng tối giản.

**Việc cần làm**
- [ ] Chip: Tất cả, Video, Shorts, Nhạc (`all`, `video`, `short`, `music`).
- [ ] Nhóm theo `watchedAt`: "Hôm nay", "Hôm qua", "Tuần này", "Tháng này", rồi "dd thg mm, yyyy"; mỗi nhóm có số video.
- [ ] `VideoCardCompact(progress: item.progress)`, cuộn vô hạn.
- [ ] Vuốt trái (`Dismissible`) hoặc menu "Xóa khỏi nhật ký xem" → `HistoryService.delete` + SnackBar có nút "Hoàn tác". Hoàn tác thì gọi `saveProgress(videoId, progressSeconds)`.
- [ ] Icon tìm kiếm → ô tìm thay tiêu đề, lọc bằng `list(q:)` (debounce 300 ms).
- [ ] Menu 3 chấm:
  - "Xóa toàn bộ nhật ký xem" (dialog chữ đỏ) → `clear()`
  - "Tạm dừng nhật ký xem" → `AuthService.setHistoryPaused` rồi `AuthProvider.refreshMe()`; khi đang dừng có banner vàng
- [ ] Nút "Xóa toàn bộ nhật ký xem" ở cuối danh sách (như thiết kế).

**Nghiệm thu**
1. Demo: thấy 6 mục chia theo ngày, có thanh tiến độ.
2. Vuốt xóa rồi Hoàn tác → mục quay lại.
3. Tạm dừng nhật ký → xem 1 video mới → không xuất hiện trong lịch sử.

## Màn 14: Chi tiết Playlist (`playlist_screen.dart`) + sheet "Lưu vào danh sách phát"

- **Thiết kế**: `design/stitch/14._chi_ti_t_playlist/`
- **Bổ sung so với Stitch**: header nền là thumbnail đầu tiên làm mờ (`ImageFiltered` + `ImageFilter.blur`) phủ lớp tối.

**Việc cần làm (màn)**
- [ ] `PlaylistService.detail(id, sort:)`. Header gồm:
  - Thumbnail lớn, tên
  - "chủ sở hữu · n video · lượt xem", icon chế độ hiển thị (khóa / link / quả cầu)
  - Hàng icon Tải xuống (giả lập), Chia sẻ, Sửa (chỉ khi `mine`)
- [ ] "Phát tất cả" → `AppRoutes.video(items.first.video.id)`. "Trộn bài" → chọn ngẫu nhiên.
- [ ] Chip "Sắp xếp" với 5 kiểu: `manual`, `added_new`, `added_old`, `popular`, `published`.
- [ ] Danh sách đánh số:
  - `mine && sort == manual` → `ReorderableListView` có tay kéo; thả xong gọi `reorder(id, videoIds)`
  - Trường hợp khác → list thường
- [ ] Menu 3 chấm mỗi video: Xóa khỏi danh sách (SnackBar Hoàn tác), Chuyển lên đầu / xuống cuối (gọi `reorder`), Lưu vào danh sách phát khác, Chia sẻ.
- [ ] Sửa → dialog tên, mô tả, chế độ hiển thị → `update`. Playlist hệ thống (`isSystem`) không cho đổi tên hay xóa.
- [ ] Menu app bar: Xóa danh sách phát (dialog) → `delete` → `context.pop()`.
- [ ] Lỗi 403 → "Danh sách phát này là riêng tư". Trống → "Chưa có video nào trong danh sách phát này".

**Việc cần làm (sheet dùng chung `save_to_playlist_sheet.dart`)**
- [ ] `PlaylistService.mine(videoId:)` → danh sách có checkbox theo `containsVideo`.
- [ ] Tick → `addVideo`; bỏ tick → `removeVideo`.
- [ ] Nút "+ Danh sách phát mới" → dialog → `create` rồi `addVideo`.
- [ ] Làm trên nhánh riêng, ví dụ `feature/n4-shared-luu-playlist`. Người 2 sẽ dùng sheet này ở nút Lưu của màn 6.

**Nghiệm thu**
1. Demo mở "Học Flutter" (#100) → kéo video 4 lên đầu → thoát vào lại vẫn đúng thứ tự.
2. Từ menu 3 chấm ở Trang chủ chọn "Lưu vào danh sách phát" → tick "Học Flutter" → mở playlist thấy video mới.
3. Khách mở playlist #1 (riêng tư) → báo riêng tư.

## Màn 15: Tải video lên (`upload_screen.dart`)

- **Thiết kế**: `design/stitch/15._t_i_video_l_n/`

**Việc cần làm**
- [ ] Bước 1: chọn video.
  - `ImagePicker().pickVideo(source: gallery)`, kèm lựa chọn quay bằng camera
  - Video dưới 60 giây và quay dọc (hoặc mở với `isShort`) → hỏi "Tải lên dưới dạng Short?"
- [ ] Bước 2: form.
  - Xem trước video bằng `video_player`; lấy thời lượng từ `controller.value.duration`
  - "Đổi hình thu nhỏ" → `pickImage`
  - Tiêu đề (bắt buộc, bộ đếm 0/100), Mô tả (≤ 5000 ký tự)
  - Các dòng cài đặt, mỗi dòng mở sheet chọn: Chế độ hiển thị, Danh sách phát (`PlaylistService.mine`), Đối tượng người xem, Danh mục (`VideoService.categories`), Thẻ (nhập rồi Enter thành chip), Bình luận Cho phép / Tắt
- [ ] Nút "Tải lên" chỉ bật khi có tiêu đề. Bấm vào:
  1. `UploadService.upload(path, type: 'video', onProgress:, cancelToken:)` và hiện thẻ tiến độ "Đang tải lên 65%" + nút Hủy
  2. Upload thumbnail nếu có
  3. `VideoService.create(...)` (gửi `durationSeconds`, `isShort`)
  4. Nếu có chọn playlist → `PlaylistService.addVideo`
- [ ] Hủy giữa chừng → dialog → `cancelToken.cancel()`. Bấm X khi đã nhập → dialog "Hủy tải lên?".
- [ ] Xong → SnackBar "Video đã được tải lên" → `context.go(AppRoutes.channel(myChannelId))`.
- [ ] File sai định dạng hoặc quá 500 MB → hiện `e.message` của backend.

**Nghiệm thu**
1. Upload 1 video mp4 ngắn → thấy trên trang kênh của mình, phát được.
2. Đăng nhập tài khoản khác đã đăng ký kênh đó → có thông báo "đã tải lên".
3. Hủy giữa chừng → không tạo video.

---

## Màn mở rộng

- **Video đã tải xuống**: danh sách giả lập.
- **VTube Studio**: thống kê lượt xem kênh mình, danh sách video với Sửa (`VideoService.update`) / Xóa.
