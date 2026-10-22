# VTube API

Base URL:

| Chạy app ở đâu | Base URL |
| --- | --- |
| Android Emulator | `http://10.0.2.2:8080` |
| iOS Simulator / Flutter web / Swagger | `http://localhost:8080` |
| Điện thoại thật (cùng Wi-Fi) | `http://<IP máy chạy backend>:8080` |

Swagger UI: `http://localhost:8080/swagger-ui.html`. Bấm **Authorize**, dán token (không cần chữ `Bearer`) để thử API cần đăng nhập.

Tài khoản mẫu: `demo@vtube.vn` / `123456`. Các kênh khác: `vtech@vtube.vn`, `amthucbui@vtube.vn`, `vietnamvibes@vtube.vn`, `laptrinhdd@vtube.vn`, `chillmelody@vtube.vn`, `goccongnghe@vtube.vn` (đều là `123456`).

## Quy ước chung

- **Đăng nhập:** gửi header `Authorization: Bearer <token>`. API có ký hiệu 🔒 bắt buộc đăng nhập (thiếu token → `401`). API không có 🔒 vẫn nhận token nếu có, để trả thêm trạng thái của người xem.
- **JSON:** tên trường dạng `camelCase`. Thời gian là chuỗi ISO-8601 UTC, ví dụ `"2026-10-22T04:30:00Z"` → Flutter dùng `DateTime.parse(...)`.
- **URL ảnh/video:** có thể là URL đầy đủ (`https://...`) hoặc đường dẫn tương đối (`/uploads/abc.mp4`). App phải ghép với base URL — dùng `ApiConfig.resolveUrl()` trong khung Flutter.
- **Phân trang:** tham số `page` (bắt đầu từ 0) và `size` (mặc định 20, tối đa 50). Kết quả:

```json
{ "items": [ ... ], "page": 0, "size": 20, "hasMore": true }
```

- **Lỗi:** mọi lỗi trả cùng một dạng, `message` là tiếng Việt, hiện thẳng lên SnackBar:

```json
{ "status": 409, "error": "Conflict", "message": "Email đã được sử dụng" }
```

| Mã | Ý nghĩa |
| --- | --- |
| 400 | Dữ liệu gửi lên sai |
| 401 | Chưa đăng nhập hoặc token hết hạn → xóa token, chuyển màn Đăng nhập |
| 403 | Không có quyền (sửa video của người khác...) |
| 404 | Không tìm thấy |
| 409 | Trùng (email, handle) |
| 413 | File upload quá 500 MB |

## Đối tượng dữ liệu

**ChannelBrief** (kênh rút gọn, đi kèm video / bình luận / thông báo)

```json
{ "id": 2, "name": "VTech Studio", "handle": "vtechstudio", "avatarUrl": "https://...", "verified": true, "subscriberCount": 1500000 }
```

**Video**

```json
{
  "id": 1, "title": "...", "description": "...",
  "thumbnailUrl": "https://...", "videoUrl": "https://....mp4",
  "durationSeconds": 596, "viewCount": 245000, "likeCount": 14000, "dislikeCount": 350, "commentCount": 6,
  "categoryId": 7, "shortVideo": false, "live": false, "visibility": "public",
  "commentsEnabled": true, "tags": "vtube,demo", "publishedAt": "2026-10-08T04:30:00Z",
  "channel": { ChannelBrief },
  "viewer": null
}
```

`viewer` chỉ có ở `GET /api/videos/{id}` khi đã đăng nhập:

```json
{ "myReaction": 1, "subscribed": true, "notifyMode": "all", "progressSeconds": 300, "inWatchLater": false, "owner": false }
```

`myReaction`: `1` = đã like, `-1` = đã dislike, `0` = chưa. `notifyMode`: `all` | `personalized` | `none`.

## 1. Auth & tài khoản (Người 1)

| Method | Đường dẫn | Body / Query | Trả về | Màn |
| --- | --- | --- | --- | --- |
| POST | `/api/auth/login` | `{ email, password }` | `{ token, user: Me }` | 2 |
| POST | `/api/auth/register` | `{ displayName, channelName?, handle, email, password, avatarUrl? }` | `201 { token, user: Me }` | 3 |
| POST | `/api/auth/logout` | header token | `204` | 4 |
| GET | `/api/users/check-handle?handle=abc` | | `{ available: true }` | 3 |
| GET 🔒 | `/api/me` | | `Me` | 1, 4 |
| PUT 🔒 | `/api/me` | `{ displayName?, avatarUrl? }` | `Me` | 4 |
| PATCH 🔒 | `/api/me/settings` | `{ historyPaused: true }` | `Me` | 13 |

**Me**: `{ id, email, displayName, avatarUrl, historyPaused, createdAt, channel: ChannelBrief }`

Ràng buộc đăng ký phía server:
- `displayName`: 2–50 ký tự.
- `handle`: 3–30 ký tự gồm chữ, số, `.`, `_`; có thể có `@` ở đầu; không phân biệt hoa thường.
- `password`: tối thiểu 6 ký tự. Màn Đăng ký trên app nên bắt chặt hơn: 8 ký tự, có cả chữ và số.

## 2. Video, Shorts (Người 2)

| Method | Đường dẫn | Body / Query | Trả về | Màn |
| --- | --- | --- | --- | --- |
| GET | `/api/categories` | | `[{ id, name, slug }]` | 5 |
| GET | `/api/videos/feed` | `category`, `page`, `size` | `Page<Video>` | 5 |
| GET | `/api/shorts` | `page`, `size` | `Page<Video>` | 5, 8 |
| GET | `/api/videos/{id}` | | `Video` (có `viewer`) | 6 |
| GET | `/api/videos/{id}/related` | `filter`, `page`, `size` | `Page<Video>` | 6 |
| POST | `/api/videos/{id}/view` | | `204` | 6, 8 |
| PUT 🔒 | `/api/videos/{id}/reaction` | `{ value: 1 \| -1 \| 0 }` | `{ likeCount, dislikeCount, myReaction }` | 6, 8 |
| POST 🔒 | `/api/videos/{id}/not-interested` | | `204` | 5 |

Giá trị tham số:
- `category`: `all`, `live`, `recent` (7 ngày gần đây), hoặc slug danh mục `music`, `gaming`, `news`, `education`, `food`, `travel`, `tech`, `entertainment`, `sports`.
- `filter` (video liên quan): `all` | `channel` (từ kênh này) | `related` (cùng danh mục) | `recent`.

Like / dislike tự đồng bộ playlist **Video đã thích**.

## 3. Bình luận (Người 2)

| Method | Đường dẫn | Body / Query | Trả về |
| --- | --- | --- | --- |
| GET | `/api/videos/{videoId}/comments` | `sort=top\|new`, `page`, `size` | `Page<Comment>` (chỉ bình luận gốc, bình luận ghim đứng đầu) |
| GET | `/api/comments/{id}/replies` | `page`, `size` | `Page<Comment>` |
| POST 🔒 | `/api/videos/{videoId}/comments` | `{ content, parentId? }` | `201 Comment` |
| PUT 🔒 | `/api/comments/{id}` | `{ content }` | `Comment` (chỉ tác giả) |
| DELETE 🔒 | `/api/comments/{id}` | | `204` (tác giả hoặc chủ kênh) |
| PUT 🔒 | `/api/comments/{id}/reaction` | `{ value }` | `Comment` |
| PUT 🔒 | `/api/comments/{id}/pin` | | `Comment` (bật/tắt, chỉ chủ kênh) |
| PUT 🔒 | `/api/comments/{id}/heart` | | `Comment` (bật/tắt, chỉ chủ kênh) |

**Comment**

```json
{ "id": 2, "videoId": 1, "parentId": null, "content": "...", "likeCount": 124, "replyCount": 2,
  "pinned": false, "hearted": true, "createdAt": "...", "updatedAt": null,
  "author": { "userId": 5, "channelId": 5, "name": "Lập Trình Di Động", "handle": "laptrinhdidong", "avatarUrl": "..." },
  "byChannelOwner": false, "myReaction": 0 }
```

Quy tắc:
- `content` dài 1–500 ký tự.
- Trả lời một phản hồi sẽ được gắn vào bình luận gốc (chỉ 2 cấp, giống YouTube).

## 4. Kênh & đăng ký (Người 3)

| Method | Đường dẫn | Body / Query | Trả về | Màn |
| --- | --- | --- | --- | --- |
| GET | `/api/channels/{id}` | | `Channel` | 11 |
| GET | `/api/channels/handle/{handle}` | | `Channel` | 11 |
| GET | `/api/channels/{id}/videos` | `sort=newest\|popular\|oldest`, `page` | `Page<Video>` | 11 |
| GET | `/api/channels/{id}/shorts` | `sort`, `page` | `Page<Video>` | 11 |
| GET | `/api/channels/{id}/playlists` | | `[Playlist]` | 11 |
| PUT 🔒 | `/api/channels/me` | `{ name?, description?, avatarUrl?, bannerUrl? }` | `Channel` | 11 |
| PUT 🔒 | `/api/channels/{id}/subscription` | `{ notifyMode? }` | `{ subscribed, notifyMode, subscriberCount }` | 6, 8, 10, 11 |
| DELETE 🔒 | `/api/channels/{id}/subscription` | | `{ subscribed: false, ... }` | 6, 11, 12 |
| GET 🔒 | `/api/me/subscriptions` | `sort=recent\|az\|relevance` | `[{ channel, notifyMode, hasNew, lastUploadAt }]` | 12 |
| GET 🔒 | `/api/me/subscriptions/feed` | `channelId?`, `type`, `page` | `Page<Video>` | 12 |

**Channel**: `{ id, userId, name, handle, description, avatarUrl, bannerUrl, verified, subscriberCount, videoCount, totalViews, createdAt, subscribed, notifyMode, mine }`

`type` của feed kênh đăng ký: `all` | `today` | `video` | `short` | `live` | `continue` (đang xem dở) | `unwatched`.

## 5. Tìm kiếm (Người 3)

| Method | Đường dẫn | Query | Trả về |
| --- | --- | --- | --- |
| GET | `/api/search` | `q`, `type`, `uploadDate`, `duration`, `sort`, `page` | `SearchResult` |
| GET | `/api/search/suggestions` | `q` | `{ history: [String], suggestions: [String] }` |
| GET 🔒 | `/api/me/search-history` | | `[{ keyword, searchedAt }]` |
| DELETE 🔒 | `/api/me/search-history` | `keyword?` (bỏ trống = xóa hết) | `204` |

Giá trị tham số:
- `type`: `all` | `video` | `short` | `channel` | `playlist` | `unwatched`
- `uploadDate`: `today` | `week` | `month` | `year`
- `duration`: `short` (dưới 4 phút) | `medium` (4–20 phút) | `long` (trên 20 phút)
- `sort`: `relevance` | `date` | `views` | `rating`

**SearchResult**: `{ channels: [Channel], videos: [Video], shorts: [Video], playlists: [Playlist], page, hasMore }`

- Với `type=all` ở trang 0, kết quả có thêm tối đa 3 kênh và 10 shorts.
- `hasMore` áp dụng cho danh sách chính của `type`.
- Khi đã đăng nhập, từ khóa tìm ở trang 0 được tự lưu vào lịch sử tìm kiếm.

## 6. Thư viện: lịch sử, playlist, upload, thông báo (Người 4)

### Lịch sử xem

| Method | Đường dẫn | Body / Query | Trả về |
| --- | --- | --- | --- |
| GET 🔒 | `/api/me/history` | `type=all\|video\|short\|music`, `q?`, `page` | `Page<{ watchedAt, progressSeconds, video }>` |
| PUT 🔒 | `/api/me/history/{videoId}` | `{ progressSeconds }` | `{ saved }` (`false` khi đang tạm dừng lịch sử) |
| DELETE 🔒 | `/api/me/history/{videoId}` | | `204` |
| DELETE 🔒 | `/api/me/history` | | `204` (xóa toàn bộ) |

### Playlist

| Method | Đường dẫn | Body / Query | Trả về |
| --- | --- | --- | --- |
| GET 🔒 | `/api/me/playlists` | `videoId?` | `[Playlist]` (có `containsVideo` khi truyền `videoId`) |
| POST 🔒 | `/api/playlists` | `{ title, description?, visibility? }` | `201 Playlist` |
| GET | `/api/playlists/{id}` | `sort=manual\|added_new\|added_old\|popular\|published` | `{ playlist, mine, totalViews, items: [{ position, addedAt, video }] }` |
| PUT 🔒 | `/api/playlists/{id}` | `{ title?, description?, visibility? }` | `Playlist` |
| DELETE 🔒 | `/api/playlists/{id}` | | `204` (không xóa được playlist hệ thống) |
| POST 🔒 | `/api/playlists/{id}/videos` | `{ videoId }` | `Playlist` |
| DELETE 🔒 | `/api/playlists/{id}/videos/{videoId}` | | `Playlist` |
| PUT 🔒 | `/api/playlists/{id}/order` | `{ videoIds: [3, 1, 2] }` | `Playlist` |
| PUT 🔒 | `/api/me/watch-later/{videoId}` | | `Playlist` (thêm vào Xem sau) |
| DELETE 🔒 | `/api/me/watch-later/{videoId}` | | `Playlist` |

**Playlist**: `{ id, title, description, visibility, kind, videoCount, thumbnailUrl, updatedAt, ownerUserId, ownerName, ownerChannelId, containsVideo }`

Quy tắc:
- `kind`: `liked` (Video đã thích) | `watch_later` (Xem sau) | `custom`.
- Hai playlist hệ thống không đổi tên hay xóa được.
- Xóa video khỏi **Video đã thích** đồng nghĩa với bỏ like video đó.

### Upload & tạo video

| Method | Đường dẫn | Body | Trả về |
| --- | --- | --- | --- |
| POST 🔒 | `/api/uploads` | `multipart/form-data`: `file`, `type=video\|image` | `201 { url, fileName, size, type }` |
| POST 🔒 | `/api/videos` | `{ title, description?, thumbnailUrl?, videoUrl, durationSeconds?, categoryId?, shortVideo?, visibility?, commentsEnabled?, madeForKids?, tags? }` | `201 Video` |
| PUT 🔒 | `/api/videos/{id}` | các trường như trên, trường `null` giữ nguyên | `Video` |
| DELETE 🔒 | `/api/videos/{id}` | | `204` |

Định dạng cho phép:
- Video: `mp4`, `mov`, `webm`, `mkv`, `3gp`
- Ảnh: `jpg`, `jpeg`, `png`, `webp`, `gif`

Khi tạo video `public`, backend gửi thông báo cho người đăng ký kênh (trừ người chọn `none`).

### Thông báo

| Method | Đường dẫn | Query | Trả về |
| --- | --- | --- | --- |
| GET 🔒 | `/api/me/notifications` | `type=all\|mention`, `page` | `Page<Notification>` |
| GET 🔒 | `/api/me/notifications/unread-count` | | `{ count }` |
| PUT 🔒 | `/api/me/notifications/read-all` | | `204` |
| PUT 🔒 | `/api/notifications/{id}/read` | | `204` |
| DELETE 🔒 | `/api/notifications/{id}` | | `204` |

**Notification**: `{ id, type, message, read, createdAt, actor: ChannelBrief?, videoId?, videoThumbnailUrl?, videoDurationSeconds?, videoShort?, commentId? }`

| `type` | Khi nào | Bấm vào mở |
| --- | --- | --- |
| `new_video` | Kênh đã đăng ký tải video lên | Màn 6 với `videoId` |
| `new_short` | Kênh đã đăng ký đăng Short | Màn 8 với `videoId` |
| `live` | Kênh đã đăng ký phát trực tiếp | Màn 6 |
| `comment_reply` | Có người trả lời bình luận của mình | Màn 6 rồi mở Màn 7 |
| `comment_heart` | Chủ kênh thả tim bình luận | Màn 6 rồi mở Màn 7 |
| `new_subscriber` | Có người đăng ký kênh của mình | Màn 11 với `actor.id` |
