# Người 2: Xem video (lõi của app)

- **Thư mục code**: `mobile/lib/features/watch/`
- **Review chéo với**: Người 1
- **Thứ tự nên làm**: Màn 5 → Màn 6 → Màn 7 → Màn 8. Màn 6 và 8 khó nhất (trình phát video), nên bắt đầu sớm.

Phần dùng chung đã có sẵn:
- **Service**: `VideoService`, `CommentService`, `ChannelService`, `HistoryService`, `PlaylistService`
- **Widget**: `VtubeLogo`, `topBarActions`, `ChipBar`, `VideoCardLarge`, `ShortsShelf`, `SubscribeButton`, `ChannelAvatar`, `showVideoOptionsSheet`, `showSaveToPlaylistSheet` (Người 4 làm phần trong)
- **Tiện ích**: `Fmt`, `requireLogin`, `ApiConfig.resolveUrl`
- **Package**: `video_player`, `chewie`, `share_plus`

---

## Màn 5: Trang chủ (`home_screen.dart`, tab 1)

- **Thiết kế**: `design/stitch/5._trang_ch/`
- **Hiện trạng**: đang có các nút "Mở nhanh" để cả nhóm thử màn. Xóa chúng khi bạn làm xong feed (nhắn nhóm trước).

**Việc cần làm**
- [ ] `CustomScrollView` + `SliverAppBar(floating: true, snap: true)`:
  - Bên trái: `VtubeLogo`
  - Bên phải: `topBarActions(context)`
  - App bar ẩn khi cuộn xuống, hiện khi cuộn lên
- [ ] Hàng chip ghim dưới app bar: "Tất cả" + danh mục từ `VideoService.categories()` + "Trực tiếp" (`live`) + "Mới tải lên" (`recent`).
- [ ] Feed:
  - `VideoService.feed(category: slug, page:)`, cuộn vô hạn theo mẫu trong `docs/CONVENTIONS.md`
  - Đổi chip → tải lại từ đầu và cuộn lên đầu
  - Kéo xuống để làm mới
- [ ] Chèn `ShortsShelf` (`VideoService.shorts(size: 10)`) sau video thứ 3. Bấm 1 short → `context.go(AppRoutes.shortsAt(short.id))`.
- [ ] Hành vi của card:
  - Bấm card → `AppRoutes.video(id)`
  - Bấm avatar → `AppRoutes.channel(channel.id)`
  - Bấm 3 chấm → `showVideoOptionsSheet(context, video, onHidden: () => xóa khỏi danh sách)`
- [ ] Bấm lại tab Trang chủ khi đang ở đó → cuộn lên đầu (tùy chọn).
- [ ] Trạng thái: shimmer hoặc `LoadingView`; danh mục trống "Chưa có video nào trong mục này"; lỗi `ErrorView`. Lỗi khi tải trang sau chỉ hiện nút "Thử lại" ở cuối.

**Nghiệm thu**
1. Mở app → thấy video "TRỰC TIẾP" đầu tiên, kệ Shorts sau video 3.
2. Cuộn tới cuối → tải thêm, không lặp video.
3. Chọn "Âm nhạc" → chỉ còn video nhạc.
4. "Không quan tâm" 1 video → biến mất. Kéo làm mới vẫn không thấy lại.

## Màn 6: Xem video (`video_screen.dart`)

- **Thiết kế**: `design/stitch/6._xem_video/`
- **Lỗi của Stitch cần tránh**: player không được đè lên thanh trạng thái; chỉ 1 icon cài đặt; không có badge "4K".
- Nên chia nhiều PR: (a) khung + thông tin, (b) trình phát, (c) tương tác, (d) video gợi ý.

**Việc cần làm**
- [ ] Tải dữ liệu: gọi song song `VideoService.detail(id)` và `related(id)`.
- [ ] **Trình phát** (`video_player` + `chewie`):
  - URL lấy từ `ApiConfig.resolveUrl(video.videoUrl)`
  - Ghim trên cùng (`Column`: player cố định, phần dưới là `Expanded` + list)
  - Tự phát khi mở; tua tới `viewer.progressSeconds` nếu có
  - Gọi `addView` 1 lần khi bắt đầu phát
  - Chạm đúp trái/phải để lùi/tới 10 giây (tùy chọn)
  - Cài đặt: tốc độ phát
  - Toàn màn hình xoay ngang (chewie hỗ trợ sẵn)
- [ ] **Lưu tiến độ**: `Timer.periodic(10 giây)` gọi `HistoryService.saveProgress`, và gọi thêm 1 lần trong `dispose`. Chỉ khi đã đăng nhập.
- [ ] **Thông tin video**:
  - Tiêu đề 2 dòng, dòng "245 N lượt xem · 2 tuần trước ...thêm"
  - Bấm → bottom sheet mô tả: 3 cột Lượt thích / Lượt xem / Ngày, mô tả đầy đủ, tags
- [ ] **Hàng kênh**:
  - Avatar, tên, `Fmt.subscribers(...)`
  - `SubscribeButton` → `ChannelService.subscribe` / `unsubscribe`
  - Đã đăng ký mà bấm lại → sheet: Tất cả, Cá nhân hóa, Không nhận, Hủy đăng ký (có xác nhận)
- [ ] **Hàng hành động** cuộn ngang:
  - Like/Dislike chung 1 pill → `VideoService.react` (optimistic, xem CONVENTIONS mục 5)
  - Chia sẻ → `share_plus`
  - Tải xuống → giả lập: tiến độ trên nút rồi đổi thành "Đã tải xuống"
  - Lưu → `showSaveToPlaylistSheet`
- [ ] **Thẻ "Bình luận 1,2 N"**: hiện 1 bình luận đầu (`CommentService.list(size: 1)`). Bấm → `showCommentsSheet`.
- [ ] **Video gợi ý**:
  - Chip "Tất cả / Từ kênh này / Có liên quan / Mới tải lên" → `related(id, filter: all | channel | related | recent)`
  - Bấm video gợi ý → `context.pushReplacement(AppRoutes.video(id))`
- [ ] Mọi thao tác cần tài khoản đều gọi `requireLogin` trước.
- [ ] Lỗi 404 → màn đen "Video này không còn khả dụng".
- [ ] `dispose`: controller, timer.

**Nghiệm thu**
1. Đăng nhập demo, mở video #1 → phát từ phút 5:00 (progress 300 giây), nút Like đang sáng, "Đã đăng ký".
2. Bỏ like → số like giảm 1; mở tab Bạn → "Video đã thích" bớt 1 video.
3. Xem 15 giây rồi Back → màn 13 hiện video này đầu tiên với thanh tiến độ.
4. Khách bấm Đăng ký → dialog đăng nhập.

## Màn 7: Bình luận (`comments_sheet.dart`)

- **Thiết kế**: `design/stitch/7._b_nh_lu_n/`

**Việc cần làm**
- [ ] Sheet:
  - `showModalBottomSheet(isScrollControlled: true)` + `DraggableScrollableSheet(initialChildSize: 0.75)`
  - Kéo lên 100%, kéo xuống để đóng
  - Video phía sau vẫn phát
- [ ] Header "Bình luận" + tổng số + nút X; chip "Hàng đầu" (`sort: top`) / "Mới nhất" (`sort: new`).
- [ ] Danh sách bình luận phân trang 20/lần. Bình luận ghim có dòng "Được ghim bởi ...". Chủ kênh có nhãn tên nền xám (`byChannelOwner`).
- [ ] Mỗi bình luận:
  - Avatar, "@handle · thời gian", nội dung (quá 4 dòng thì có "Đọc thêm")
  - Like (số) / Dislike / Trả lời; trái tim nếu `hearted`
  - "n phản hồi" → mở rộng tại chỗ, gọi `CommentService.replies(id)`
- [ ] Ô nhập cố định ở đáy:
  - Avatar mình + "Thêm bình luận..."; nút gửi chỉ hiện khi có chữ
  - Tối đa 500 ký tự, hiện bộ đếm khi gần đầy
  - Gửi xong: chèn lên đầu danh sách, xóa ô, ẩn bàn phím
- [ ] Trả lời: ô nhập tự điền "@handle " và focus; gửi kèm `parentId`.
- [ ] Menu 3 chấm:
  - Của mình: Chỉnh sửa, Xóa (có xác nhận)
  - Người khác: Báo cáo
  - Mình là chủ kênh: Ghim / Bỏ ghim, Thả tim
- [ ] Khách: ô nhập thay bằng "Đăng nhập để bình luận". Video tắt bình luận: "Bình luận đã bị tắt".

**Nghiệm thu**
1. Video #1: bình luận của VTech Studio đứng đầu và có ghim.
2. Mở "2 phản hồi" của bình luận thứ 2 → thấy 2 phản hồi.
3. Gửi bình luận → hiện ngay, số bình luận ở màn 6 tăng.
4. Đăng nhập `vtech@vtube.vn` → ghim / thả tim được bình luận người khác.

## Màn 8: Shorts (`shorts_screen.dart`, tab 2)

- **Thiết kế**: `design/stitch/8._shorts/` (bản đã sửa).

**Việc cần làm**
- [ ] `PageView.builder(scrollDirection: Axis.vertical)`, mỗi trang 1 short. Video `BoxFit.cover` toàn màn và tự lặp lại.
- [ ] Trang hiện → phát + `addView`; rời trang → pause.
- [ ] Bộ nhớ:
  - Preload 1 video kế tiếp
  - `dispose` controller cách trang hiện tại quá 2 trang
- [ ] Chạm 1 lần → pause/play, có icon lớn mờ dần. Chạm đúp → like, có tim bay lên.
- [ ] Cột phải: Like (số), Dislike, Bình luận (số) → `showCommentsSheet`, Chia sẻ, Remix (giả lập), đĩa nhạc xoay.
- [ ] Góc dưới trái:
  - Avatar + @handle + `SubscribeButton(red: true)`
  - Chú thích 2 dòng, dòng nhạc chạy chữ
  - Thanh tiến độ mảnh ngay trên bottom nav
- [ ] Tải thêm khi còn 3 short chưa xem.
- [ ] `startVideoId`: mở từ kệ Shorts thì bắt đầu đúng short đó. Nếu không có trong trang đầu → `VideoService.detail(id)` rồi chèn lên đầu.
- [ ] Đổi sang tab khác → dừng video. Gợi ý: kiểm tra route hiện tại, hoặc nhận `isActive` từ `MainShell` (nhờ trưởng nhóm thêm tham số).

**Nghiệm thu**
1. Từ Trang chủ bấm short thứ 2 trong kệ → Shorts mở đúng short đó.
2. Vuốt qua 10 short không giật, không tràn bộ nhớ (xem DevTools → Memory).
3. Chạm đúp → like tăng. Qua tab Trang chủ thì không còn nghe tiếng.

---

## Màn mở rộng

- **Mini player**: thu nhỏ video khi Back từ màn 6 về tab. Khó, cần sửa `MainShell`, nên phối hợp với trưởng nhóm.
- **Khám phá / Thịnh hành**: từ chip la bàn ở Trang chủ.
