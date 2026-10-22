# Luồng điều hướng và nghiệp vụ

GitHub hiển thị trực tiếp các sơ đồ dưới đây. Bản có hình vẽ đẹp hơn nằm trong tài liệu đặc tả online.

## Điều hướng giữa 16 màn

```mermaid
flowchart TD
    S1[1 · Splash] -->|đã đăng nhập / khách| SHELL
    S1 -.->|bắt buộc đăng nhập| S2
    S2[2 · Đăng nhập] <--> S3[3 · Đăng ký]
    S2 -->|thành công| SHELL
    S3 -->|thành công| SHELL

    subgraph SHELL[Khung tab · Bottom Navigation]
        S5[5 · Trang chủ]
        S8[8 · Shorts]
        PLUS(("(+) Tạo"))
        S12[12 · Kênh đăng ký]
        S4[4 · Bạn]
    end

    PLUS --> S15[15 · Tải video lên]
    S5 --> S6[6 · Xem video]
    S5 -->|kệ Shorts| S8
    S6 --> S7[7 · Bình luận - sheet]
    S8 --> S7
    S5 & S12 & S4 -->|icon kính lúp| S9[9 · Tìm kiếm]
    S9 --> S10[10 · Kết quả]
    S10 --> S6
    S10 --> S11[11 · Trang kênh]
    S5 & S6 & S8 & S12 --> S11
    S11 --> S6
    S11 --> S14[14 · Playlist]
    S4 --> S13[13 · Lịch sử]
    S4 --> S14
    S13 --> S6
    S14 --> S6
    S5 & S12 & S4 -->|icon chuông| S16[16 · Thông báo]
    S16 --> S6
    S16 --> S11
```

| Màn | Route (`AppRoutes`) | Ghi chú |
| --- | --- | --- |
| 1 | `/splash` | Màn khởi động |
| 2 | `/login` | Mở bằng `context.push`, xong thì `pop` về màn trước |
| 3 | `/register` | |
| 5, 8, 12, 4 | `/home`, `/shorts`, `/subscriptions`, `/you` | 4 tab, giữ trạng thái khi đổi tab |
| 6 | `/video/:id` | |
| 7 | (không có route) | Bottom sheet: `showCommentsSheet(context, videoId)` |
| 8 | `/shorts?start=<id>` | Mở đúng short đã bấm |
| 9, 10 | `/search`, `/search/results?q=` | |
| 11 | `/channel/:id` | |
| 13 | `/history` | |
| 14 | `/playlist/:id` | |
| 15 | `/upload`, `/upload?short=1` | |
| 16 | `/notifications` | |

## Đăng nhập khi đang làm thao tác cần tài khoản

```mermaid
sequenceDiagram
    actor U as Người dùng
    participant A as Màn bất kỳ
    participant L as Màn 2 Đăng nhập
    participant P as AuthProvider
    participant B as Backend
    U->>A: Bấm Like (đang là khách)
    A->>A: requireLogin(context)
    A-->>U: Dialog "Đăng nhập để tiếp tục"
    U->>L: Chọn Đăng nhập
    L->>P: login(email, pass)
    P->>B: POST /api/auth/login
    B-->>P: { token, user }
    P->>P: lưu token (shared_preferences)
    L-->>A: pop() về màn cũ
    A->>B: PUT /api/videos/{id}/reaction (kèm Bearer token)
```

## Xem video và lưu tiến độ

```mermaid
sequenceDiagram
    participant V as Màn 6
    participant B as Backend
    V->>B: GET /api/videos/{id}
    V->>B: GET /api/videos/{id}/related
    B-->>V: video + viewer.progressSeconds
    V->>V: seekTo(progressSeconds), play()
    V->>B: POST /api/videos/{id}/view
    loop mỗi 10 giây và khi rời màn
        V->>B: PUT /api/me/history/{id} { progressSeconds }
    end
```

## Tải video lên

```mermaid
sequenceDiagram
    participant U as Màn 15
    participant B as Backend
    U->>B: POST /api/uploads (file video, type=video)
    B-->>U: { url: "/uploads/abc.mp4" }
    U->>B: POST /api/uploads (ảnh thumbnail, type=image)
    B-->>U: { url: "/uploads/def.jpg" }
    U->>B: POST /api/videos { title, videoUrl, thumbnailUrl, ... }
    B->>B: tạo thông báo new_video cho người đăng ký kênh
    B-->>U: Video
    U->>U: SnackBar "Video đã được tải lên" → Trang kênh của mình
```

## Thông báo được tạo khi nào

| Sự kiện | Ai nhận | `type` |
| --- | --- | --- |
| Đăng video công khai | Người đăng ký kênh (trừ `notify_mode = none`) | `new_video` / `new_short` |
| Trả lời bình luận | Người viết bình luận được trả lời | `comment_reply` |
| Chủ kênh thả tim bình luận | Người viết bình luận | `comment_heart` |
| Có người đăng ký kênh | Chủ kênh | `new_subscriber` |

Không ai nhận thông báo về hành động của chính mình.
