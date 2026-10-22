# Người 3: Khám phá & Kênh

- **Thư mục code**: `mobile/lib/features/explore/`
- **Review chéo với**: Người 4
- **Thứ tự nên làm**: Màn 9 → Màn 10 → Màn 12 → Màn 11

Phần dùng chung đã có sẵn:
- **Service**: `SearchService`, `ChannelService`, `PlaylistService`
- **Model**: `SearchFilters`, `SearchResult`, `SearchSuggestions`, `Channel`, `SubscribedChannel`
- **Widget**: `ChipBar`, `VideoCardCompact`, `VideoCardLarge`, `ShortsShelf`, `SubscribeButton`, `ChannelAvatar`, `AppNetworkImage`, `topBarActions`, `VtubeLogo`, `EmptyView`

---

## Màn 9: Tìm kiếm (`search_screen.dart`)

- **Thiết kế**: `design/stitch/9._t_m_ki_m/`
- **Bỏ khỏi Stitch**: logo lạ "RK", tiêu đề "Tìm kiếm" thừa. Ô tìm kiếm nằm luôn trên app bar.

**Việc cần làm**
- [ ] AppBar gồm nút Back + `TextField` bo tròn ("Tìm kiếm trên VTube", tự focus, nút X khi có chữ) + icon micro.
- [ ] Ô trống → `SearchService.suggestions('')` → lịch sử (icon đồng hồ).
- [ ] Đang gõ:
  - Debounce 300 ms rồi gọi `suggestions(q)`
  - Hiện lịch sử khớp (đồng hồ) rồi gợi ý (kính lúp)
  - Phần chữ trùng in thường, phần còn lại in đậm (`RichText`)
  - Bỏ kết quả của lần gõ cũ nếu về sau lần gõ mới (lưu biến `_lastQuery`)
- [ ] Icon ↖ bên phải → điền từ khóa vào ô, chưa tìm.
- [ ] Nhấn giữ mục lịch sử → dialog "Xóa khỏi nhật ký tìm kiếm?" → `deleteHistory(keyword:)`.
- [ ] Enter, nút tìm trên bàn phím, hoặc bấm gợi ý → `context.push(AppRoutes.searchResults(q))`. Chuỗi rỗng thì không tìm.
- [ ] `initialQuery`: điền sẵn khi mở lại từ màn 10.
- [ ] Micro (tùy chọn): package `speech_to_text`, cần thêm qua PR `chore(deps)`.

**Nghiệm thu**
1. Đăng nhập demo, mở Tìm kiếm → thấy 4 từ khóa lịch sử.
2. Gõ "flu" → gợi ý có tiêu đề video Flutter.
3. Nhấn giữ 1 lịch sử → xóa được.

## Màn 10: Kết quả tìm kiếm (`search_results_screen.dart`)

- **Thiết kế**: `design/stitch/10._k_t_qu_t_m_ki_m/`

**Việc cần làm**
- [ ] AppBar:
  - Ô chứa `query`, bấm vào → `context.pushReplacement('/search?q=...')` để sửa từ khóa
  - Icon micro, icon bộ lọc (chấm đỏ khi `!filters.isDefault`)
- [ ] Chip loại: Tất cả (`all`), Video, Shorts (`short`), Kênh (`channel`), Danh sách phát (`playlist`), Chưa xem (`unwatched`).
- [ ] Kết quả `SearchService.search(query, filters:, page:)`:
  - `type=all` ở trang 0: thẻ kênh (`channels`) trên cùng, rồi video `VideoCardCompact`, chèn `ShortsShelf` sau ~4 video
  - Các type khác: hiện đúng danh sách tương ứng; cuộn vô hạn theo `hasMore`
- [ ] Thẻ kênh:
  - Avatar lớn, tên + tích xanh, "@handle · n người đăng ký"
  - `SubscribeButton` hoạt động thật
- [ ] Bottom sheet bộ lọc gồm 4 nhóm (xem bảng trong đặc tả màn 10), nút "Đặt lại" và "Áp dụng".
- [ ] Bấm kết quả:
  - Video → `AppRoutes.video`
  - Kênh → `AppRoutes.channel`
  - Short → `AppRoutes.shortsAt`
  - Playlist → `AppRoutes.playlist`
- [ ] Không có kết quả: "Không tìm thấy kết quả nào cho "..."" + gợi ý bỏ bộ lọc.

**Nghiệm thu**
1. Tìm "flutter" → có video, kệ Shorts; tìm "vtech" → thẻ kênh VTech Studio.
2. Lọc Thời lượng "Trên 20 phút" → không còn video ngắn.
3. Đăng ký kênh ngay trên thẻ → mở trang kênh thấy "Đã đăng ký".

## Màn 11: Trang kênh (`channel_screen.dart`)

- **Thiết kế**: `design/stitch/11._trang_k_nh/`
- **Lưu ý**: tiêu đề app bar là **tên kênh**, không phải chữ "Trang kênh". Số liệu dùng `Fmt` ("45 N", không phải "45K").

**Việc cần làm**
- [ ] `NestedScrollView`. Header gồm:
  - Banner, avatar lớn, tên + tích xanh
  - "@handle · n người đăng ký · n video", mô tả "...thêm" → sheet Giới thiệu
- [ ] Nút theo chủ sở hữu:
  - Kênh người khác (`mine == false`): `SubscribeButton` + "Tham gia" (giả lập)
  - Kênh mình: "Tùy chỉnh kênh" (sheet sửa tên, mô tả → `ChannelService.updateMine`) + "Quản lý video"
- [ ] `TabBar` ghim khi cuộn (`SliverPersistentHeader`):
  - **Trang chủ**: video mới nhất + kệ Shorts + playlist
  - **Video**: chip Mới nhất / Phổ biến / Cũ nhất → `videos(id, sort:)`
  - **Shorts**: lưới 3 cột → `shorts(id)`
  - **Danh sách phát**: `playlists(id)`
  - **Giới thiệu**: mô tả, ngày tham gia (`createdAt`), tổng lượt xem (`totalViews`), nút Chia sẻ kênh
- [ ] Mỗi tab tải dữ liệu lần đầu khi được mở, có phân trang.
- [ ] Kênh không có video: "Kênh này không có nội dung nào"; kênh mình thì có thêm nút "Tải video lên" → `AppRoutes.upload`.
- [ ] Menu 3 chấm: Chia sẻ kênh, Báo cáo (giả lập).

**Nghiệm thu**
1. Mở kênh 2 → đủ banner, 1,5 Tr người đăng ký, tab Video đổi sắp xếp được.
2. Đăng ký / hủy → số người đăng ký đổi ngay.
3. Đăng nhập demo, mở kênh của mình (từ tab Bạn) → thấy nút "Tùy chỉnh kênh", sửa mô tả được.

## Màn 12: Kênh đăng ký (`subscriptions_screen.dart`, tab 4)

- **Thiết kế**: `design/stitch/12._k_nh_ng_k/` (bản đã sửa).

**Việc cần làm**
- [ ] App bar giống Trang chủ (`VtubeLogo` + `topBarActions`).
- [ ] Khách: `EmptyView` "Đừng bỏ lỡ video mới" + nút Đăng nhập. Dùng `context.watch<AuthProvider>()` để màn tự cập nhật sau khi đăng nhập.
- [ ] Hàng avatar kênh:
  - `ChannelService.mySubscriptions()`, cuộn ngang, chấm xanh nếu `hasNew`, cuối hàng là chữ "Tất cả"
  - Bấm avatar → lọc feed theo kênh đó (avatar được viền), hiện thêm nút "Xem kênh"; bấm lại → bỏ lọc
- [ ] Chip: Tất cả, Hôm nay, Video, Shorts, Trực tiếp, Tiếp tục xem (`continue`), Chưa xem (`unwatched`).
- [ ] Feed `subscriptionFeed(channelId:, type:, page:)` bằng `VideoCardLarge`, cuộn vô hạn, kéo làm mới. Hết video → "Bạn đã cập nhật hết video mới!".
- [ ] Trang "Tất cả" (push trong màn của bạn, không cần route mới; có thể dùng `Navigator.push`):
  - Danh sách kênh, sắp xếp Liên quan nhất / Hoạt động mới / A-Z
  - Mỗi kênh có nút chuông đổi `notifyMode` và có thể hủy đăng ký
- [ ] Chưa đăng ký kênh nào: "Hãy đăng ký kênh để xem video mới nhất tại đây" + nút về Trang chủ.

**Nghiệm thu**
1. Demo: thấy 5 kênh, Ẩm Thực Bụi có nhãn trực tiếp. Chip "Trực tiếp" chỉ còn 1 video.
2. Bấm avatar Vietnam Vibes → chỉ còn video của kênh đó.
3. Trong "Tất cả" hủy đăng ký 1 kênh → quay ra hàng avatar thấy kênh đó biến mất.

---

## Màn mở rộng

- **Khám phá / Thịnh hành**: lưới danh mục + top video theo lượt xem (`feed` theo từng danh mục).
