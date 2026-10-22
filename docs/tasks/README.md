# Phân công & kế hoạch

Mỗi người có 1 file việc riêng: [Người 1](NGUOI-1.md) · [Người 2](NGUOI-2.md) · [Người 3](NGUOI-3.md) · [Người 4](NGUOI-4.md).

Mỗi màn trong file việc gồm 4 phần:
- **Thiết kế**: thư mục Stitch trong `design/stitch/`. Mở `code.html` bằng Chrome, bật DevTools → chế độ điện thoại.
- **Đặc tả**: mục tương ứng trong tài liệu đặc tả (`docs/DAC-TA-MAN-HINH.md`).
- **Việc cần làm**: checklist, tick dần trong PR.
- **Nghiệm thu**: người review thử đúng các bước này trước khi approve.

## Kế hoạch 4 tuần

Nếu hạn nộp khác, giãn hoặc nén theo tỉ lệ.

| Tuần | Mục tiêu chung | Mốc |
| --- | --- | --- |
| 0 (1–2 ngày) | Trưởng nhóm: tạo repo GitHub, `flutter create`, sửa AndroidManifest, bảo vệ nhánh. Mọi người: clone, chạy được backend + app, đăng nhập `demo@vtube.vn` | `v0.1` |
| 1 | Mỗi người làm **2 màn dễ** (xem thứ tự trong file việc), đủ giao diện + gọi API | |
| 2 | **2 màn khó** + các trạng thái đang tải / trống / lỗi | `v0.5` giữa tuần 2 |
| 3 | Hoàn thiện theo đặc tả, sửa review, **test chéo** (mỗi người test 4 màn của cặp mình theo phần Nghiệm thu) | `v0.9` |
| 4 | Sửa lỗi, làm màn mở rộng nếu còn thời gian, quay video demo, chuẩn bị báo cáo | `v1.0` |

## Định nghĩa "Xong" (Definition of Done) cho 1 màn

- [ ] Giao diện giống thiết kế Stitch (màu, bo góc, khoảng cách tương đối)
- [ ] Gọi API thật, không dùng dữ liệu giả trong code
- [ ] Có đủ 3 trạng thái: đang tải, trống, lỗi (có nút Thử lại)
- [ ] Hoạt động đúng khi là **khách** và khi **đã đăng nhập**
- [ ] Danh sách dài có phân trang (cuộn tới cuối tự tải thêm) và kéo xuống để làm mới (nếu đặc tả yêu cầu)
- [ ] Không lỗi khi xoay màn hình hoặc bấm Back giữa chừng (`mounted`, `dispose`)
- [ ] `flutter analyze` sạch, PR được approve và đã merge vào `develop`

## Họp nhanh

Mỗi ngày (hoặc 3 buổi / tuần) nhắn vào nhóm theo mẫu:

```
[Người 2] Hôm qua: xong khung màn 6, phát video được
Hôm nay: like/dislike + đăng ký kênh
Vướng: chưa biết ẩn bottom nav khi xoay ngang -> ai biết chỉ với
```
