# Người 1: Xác thực & Tài khoản

- **Thư mục code**: `mobile/lib/features/auth/`
- **Review chéo với**: Người 2
- **Thứ tự nên làm**: Màn 2 → Màn 3 → Màn 1 → Màn 4. Đăng nhập là thứ cả nhóm cần sớm.

Phần dùng chung đã có sẵn, chỉ việc dùng:
- `AuthProvider`: `login`, `register`, `logout`, `restoreSession`, `refreshMe`, `user`, `isLoggedIn`
- `AuthService.isHandleAvailable`, `UploadService.upload`
- `requireLogin`, `showSnack`
- `ChannelAvatar`, `AppNetworkImage`, `VideoThumbnail`, `topBarActions`, `EmptyView`

---

## Màn 2: Đăng nhập (`login_screen.dart`)

- **Thiết kế**: `design/stitch/2._ng_nh_p/`
- **Hiện trạng**: đã có form tối thiểu để cả nhóm đăng nhập thử. Bạn làm lại toàn bộ giao diện, giữ phần gọi `AuthProvider.login`.

**Việc cần làm**
- [ ] Giao diện:
  - Logo trên cùng, tiêu đề "Đăng nhập", phụ đề "để tiếp tục với VTube"
  - Ô Email (icon thư), ô Mật khẩu (icon khóa + con mắt ẩn/hiện)
  - "Quên mật khẩu?" căn phải
  - Nút đỏ full-width, đường kẻ "HOẶC", nút "Tiếp tục với Google", dòng "Chưa có tài khoản? Đăng ký ngay"
- [ ] Bỏ 2 khối "Bảo mật tài khoản" và "Mã hóa SSL" có trong Stitch (thừa).
- [ ] Kiểm tra dữ liệu bằng `Form` + `TextFormField.validator`:
  - Email không trống và đúng định dạng
  - Mật khẩu từ 6 ký tự
  - Lỗi hiện dưới ô, kiểm tra khi rời ô và khi bấm nút
- [ ] Nút mờ khi form chưa hợp lệ; trong lúc gửi thì hiện vòng quay và khóa các ô.
- [ ] Bàn phím:
  - Enter ở ô Email → nhảy sang ô Mật khẩu
  - Enter ở ô Mật khẩu → gửi form
- [ ] Sai mật khẩu: SnackBar `e.message` ("Email hoặc mật khẩu không đúng"), giữ email, xóa mật khẩu.
- [ ] Thành công:
  - Mở từ dialog `requireLogin` → `context.pop()`
  - Mở từ chỗ khác → `context.go(AppRoutes.home)`
- [ ] "Tiếp tục với Google": giả lập bằng cách đăng nhập `demo@vtube.vn`, có SnackBar "Đăng nhập Google (giả lập)".
- [ ] "Quên mật khẩu?": dialog nhập email → SnackBar "Đã gửi hướng dẫn tới email" (giả lập).

**Nghiệm thu**
1. Để trống email rồi bấm Đăng nhập → báo lỗi dưới ô, không gọi API.
2. Nhập `demo@vtube.vn` / `sai` → SnackBar lỗi, ô mật khẩu bị xóa.
3. Nhập `demo@vtube.vn` / `123456` → vào Trang chủ, tab Bạn hiện avatar.
4. Là khách, vào màn 6 bấm Like → dialog → Đăng nhập → tự quay lại màn 6.

## Màn 3: Đăng ký (`register_screen.dart`)

- **Thiết kế**: `design/stitch/3._ng_k/`
- **Bỏ khỏi Stitch**: "Bước 1/2", khối "Đặc quyền tài khoản mới".
- **Tách riêng** 2 ô: "Tên kênh" (chữ thường) và "Handle" (tiền tố @).

**Việc cần làm**
- [ ] Ô chọn avatar:
  - Bấm → bottom sheet "Chụp ảnh / Chọn từ thư viện" (`image_picker`)
  - Xem trước ảnh tròn
  - Khi bấm Đăng ký: upload trước bằng `UploadService.upload(path, type: 'image')` để lấy `url`
- [ ] Các ô: Họ tên (2–50 ký tự), Tên kênh (tự điền theo Họ tên nếu người dùng chưa sửa), Handle, Email, Mật khẩu, Xác nhận mật khẩu.
- [ ] Handle:
  - Gồm 3–30 ký tự: chữ thường, số, `.`, `_`
  - Sau khi ngừng gõ 500 ms → `AuthService.isHandleAvailable` → hiện ✓ xanh hoặc "Đã có người sử dụng" (đỏ)
  - Dùng `Timer` để debounce, nhớ `cancel` trong `dispose`
- [ ] Mật khẩu:
  - Từ 8 ký tự, có cả chữ và số
  - Thanh độ mạnh Yếu / Trung bình / Mạnh cập nhật theo từng ký tự
- [ ] Xác nhận mật khẩu phải trùng.
- [ ] Checkbox điều khoản: chưa tick thì nút Đăng ký mờ. Bấm chữ "Điều khoản dịch vụ" → dialog nội dung.
- [ ] Bấm Đăng ký:
  - Kiểm tra cả form, cuộn tới ô lỗi đầu tiên
  - Gọi `AuthProvider.register(...)`
  - Lỗi 409 (email hoặc handle trùng) → hiện dưới ô tương ứng
- [ ] Bấm Back khi đã nhập dở → dialog "Hủy đăng ký? Thông tin đã nhập sẽ bị mất" (`PopScope`).
- [ ] Thành công → SnackBar "Tạo tài khoản thành công" → `context.go(AppRoutes.home)`.

**Nghiệm thu**
1. Gõ handle `vtechstudio` → sau nửa giây báo đã có người dùng.
2. Đăng ký với email `demo@vtube.vn` → lỗi "Email đã được sử dụng".
3. Đăng ký mới có avatar → vào Trang chủ, tab Bạn hiện đúng avatar và tên.

## Màn 1: Splash (`splash_screen.dart`)

- **Thiết kế**: `design/stitch/1._splash_screen/` (bản đã sửa: không có app bar).
- **Hiện trạng**: đã có logic `restoreSession` + chuyển màn. Bạn làm giao diện và xử lý mất mạng.

**Việc cần làm**
- [ ] Giao diện:
  - Nền gradient tối, logo đỏ, chữ "VTube", dòng "WATCH • CREATE • CONNECT"
  - Vòng quay nhỏ gần đáy, "v1.0.0"
- [ ] Hiệu ứng logo scale + fade-in 600 ms (`AnimationController` hoặc `TweenAnimationBuilder`).
- [ ] Giữ splash tối thiểu 1,5 giây (đã có).
- [ ] Không kết nối được backend → thay vòng quay bằng "Không có kết nối mạng" + nút "Thử lại".
- [ ] (Mở rộng) Onboarding 3 trang khi mở app lần đầu, lưu cờ `onboarded` vào `shared_preferences`.

**Nghiệm thu**
1. Đang đăng nhập, mở lại app → vào Trang chủ, vẫn đăng nhập.
2. Tắt backend rồi mở app → hiện thông báo mất kết nối; bật backend, bấm Thử lại → vào được.

## Màn 4: Trang "Bạn" (`account_screen.dart`, tab thứ 5)

- **Thiết kế**: `design/stitch/4._trang_b_n/`
- **Bỏ khỏi Stitch**: banner "VTube Premium Creator". Logo app bar chỉ ghi "VTube" một lần.

**Việc cần làm**
- [ ] **Khách**: icon người lớn, "Tận hưởng các video yêu thích", phụ đề, nút "Đăng nhập". Vẫn hiện mục Cài đặt và Trợ giúp.
- [ ] **Header khi đã đăng nhập**:
  - Avatar lớn, tên, "@handle · Xem kênh >" → `AppRoutes.channel(user.channel.id)`
  - Số người đăng ký
  - Chip "Chuyển đổi tài khoản", "Tài khoản Google"
- [ ] **Hàng "Nhật ký xem"**:
  - `HistoryService.list(size: 10)`, cuộn ngang, có thanh tiến độ đỏ
  - "Xem tất cả" → `AppRoutes.history`
- [ ] **Hàng "Danh sách phát"**:
  - `PlaylistService.mine()`; mỗi thẻ có thumbnail, tên, "n video · Riêng tư"
  - Bấm → `AppRoutes.playlist(id)`
  - Nút "+" → dialog tạo playlist (tên ≤ 150 ký tự + chế độ hiển thị) → `PlaylistService.create`
- [ ] Nhấn giữ playlist tự tạo → menu Đổi tên, Xóa (có xác nhận). Playlist hệ thống không có menu này.
- [ ] **Danh sách mục**:
  - Video của bạn → trang kênh của mình
  - Video đã tải xuống → SnackBar giả lập
  - Video đã thích → playlist `kind == 'liked'`
  - Cài đặt, Trợ giúp & phản hồi
  - Đăng xuất (chữ đỏ, có dialog xác nhận → `AuthProvider.logout()`)
- [ ] Kéo xuống để làm mới.
- [ ] Mỗi hàng lỗi riêng có nút "Thử lại", không làm hỏng cả màn.

**Nghiệm thu**
1. Khách mở tab Bạn → thấy màn mời đăng nhập.
2. Đăng nhập demo → thấy 6 video trong Nhật ký xem, 3 playlist.
3. Tạo playlist "Test" → xuất hiện ngay. Xóa → biến mất.
4. Đăng xuất → về trạng thái khách, avatar ở bottom nav đổi thành icon.

---

## Màn mở rộng (khi còn thời gian)

- **Cài đặt**: giao diện sáng/tối, tự phát video, tạm dừng lịch sử (`AuthService.setHistoryPaused`), xóa lịch sử tìm kiếm, phiên bản.
- **Chỉnh sửa hồ sơ / kênh**: `ChannelService.updateMine` + upload avatar/banner, rồi `AuthProvider.refreshMe()`.
- **Quên mật khẩu**: email → OTP 6 số (giả lập) → mật khẩu mới.
