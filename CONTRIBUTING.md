# Luật làm việc nhóm VTube

Áp dụng cho cả 4 người, cả code Flutter lẫn backend. Mục tiêu: không ai ghi đè code của ai, lịch sử Git đọc là hiểu, và lúc nào nhánh `develop` cũng chạy được.

## 1. Nhánh (branch)

```
main        ← chỉ chứa bản nộp / demo. Không ai push thẳng.
 └── develop   ← nhánh tích hợp. Chỉ nhận code qua Pull Request.
      ├── feature/n2-m06-video-player
      ├── feature/n3-m10-bo-loc
      └── fix/n4-m13-xoa-lich-su
```

**Tên nhánh**: `<loại>/<người>-<màn>-<mô-tả-ngắn>`

| Phần | Giá trị |
| --- | --- |
| loại | `feature` (tính năng mới), `fix` (sửa lỗi), `ui` (chỉnh giao diện), `refactor`, `docs`, `chore` (cấu hình, thư viện) |
| người | `n1`, `n2`, `n3`, `n4`, hoặc `lead` cho trưởng nhóm |
| màn | `m01` ... `m16`, hoặc `shared` / `backend` khi sửa phần dùng chung |
| mô tả | chữ thường, không dấu, nối bằng `-`, 2–4 từ |

Ví dụ: `feature/n1-m03-dang-ky`, `fix/n2-m08-shorts-tran-bo-nho`, `chore/lead-shared-them-package`.

**Quy tắc**:
- Mỗi nhánh làm **một việc** (một màn hoặc một phần của màn). Đừng làm 2 màn trên cùng một nhánh.
- Nhánh luôn tách từ `develop` mới nhất.
- Merge xong thì xóa nhánh.

## 2. Quy trình mỗi ngày

```bash
# 1. Bắt đầu việc mới: lấy develop mới nhất rồi tách nhánh
git checkout develop
git pull origin develop
git checkout -b feature/n2-m05-trang-chu

# 2. Làm việc, commit nhỏ, thường xuyên (xem mục 3)
git status                      # LUÔN xem trước khi add
git add mobile/lib/features/watch/home_screen.dart
git commit -m "feat(m05): hiển thị feed video từ API"

# 3. Cuối ngày (hoặc trước khi tạo PR): cập nhật develop vào nhánh mình
git fetch origin
git rebase origin/develop       # gặp xung đột -> xem mục 7
git push -u origin feature/n2-m05-trang-chu
```

- Push nhánh của mình **ít nhất 1 lần mỗi ngày làm việc**, kể cả khi chưa xong, để không mất code.
- Không dùng `git add .` khi chưa xem `git status`. Không commit file trong `build/`, `.dart_tool/`, `vtube.db`, `uploads/`, `.idea/`.

## 3. Commit message

Theo chuẩn [Conventional Commits](https://www.conventionalcommits.org/), phần mô tả viết tiếng Việt:

```
<type>(<scope>): <mô tả ngắn, bắt đầu bằng động từ, tối đa 72 ký tự>

<thân - tùy chọn: giải thích VÌ SAO, không phải làm GÌ>
```

| type | Khi nào |
| --- | --- |
| `feat` | Thêm tính năng: màn mới, nút mới, gọi API mới |
| `fix` | Sửa lỗi |
| `ui` | Chỉnh giao diện cho giống thiết kế, không đổi logic |
| `refactor` | Sắp xếp lại code, không đổi hành vi |
| `docs` | Sửa tài liệu |
| `chore` | Cấu hình, thêm thư viện, file build |
| `test` | Thêm / sửa test |

`scope`: mã màn (`m01`...`m16`), hoặc `shared`, `router`, `theme`, `backend`, `api`, `db`, `deps`.

Ví dụ **đúng**:

```
feat(m06): phát video bằng chewie và lưu tiến độ mỗi 10 giây
fix(m10): bộ lọc thời lượng không reset khi đổi từ khóa
ui(m04): bo góc 12px cho thẻ playlist theo thiết kế
feat(backend): thêm API GET /api/channels/{id}/about
chore(deps): thêm package shimmer 3.0.0
```

Ví dụ **sai**: `update`, `fix bug`, `sửa`, `abc`, `final`, `final 2`, `WIP`.

Mỗi commit là **một thay đổi hoàn chỉnh và app vẫn build được**. Làm xong một ý thì commit ngay, đừng gom cả ngày vào 1 commit.

## 4. Pull Request (PR)

1. Push nhánh, mở PR vào **`develop`** (không phải `main`).
2. Tiêu đề PR viết theo format commit, ví dụ `feat(m06): màn Xem video`.
3. Điền đủ mẫu PR (tự hiện ra): màn nào, làm gì, **ảnh chụp màn hình**, đã tự kiểm tra chưa.
4. Gán người review:

   | Người làm | Review chéo |
   | --- | --- |
   | Người 1 | Người 2 |
   | Người 2 | Người 1 |
   | Người 3 | Người 4 |
   | Người 4 | Người 3 |

   PR sửa thư mục dùng chung thì thêm **trưởng nhóm**.
5. Cần **1 approve** mới được merge. Người review trả lời trong **24 giờ**.
6. Merge bằng **Squash and merge**. Xóa nhánh sau khi merge.

**Kích thước PR**: không quá ~400 dòng thay đổi. Màn lớn (như màn 6) thì chia nhiều PR: khung giao diện → trình phát → like/đăng ký → video gợi ý.

**Người review kiểm tra**:
- [ ] App chạy được sau khi pull nhánh về
- [ ] Giống thiết kế Stitch, có đủ trạng thái đang tải / trống / lỗi
- [ ] Không sửa file của người khác hay file dùng chung mà không báo
- [ ] Không hard-code màu (dùng `AppColors`), không hard-code đường dẫn (dùng `AppRoutes`), không gọi `Dio` trực tiếp (dùng service)
- [ ] `flutter analyze` không còn lỗi

## 5. Ai được sửa file nào

| Thư mục | Chủ sở hữu | Người khác muốn sửa |
| --- | --- | --- |
| `mobile/lib/features/auth/` | Người 1 | Hỏi Người 1 trước |
| `mobile/lib/features/watch/` | Người 2 | Hỏi Người 2 trước |
| `mobile/lib/features/explore/` | Người 3 | Hỏi Người 3 trước |
| `mobile/lib/features/library/` | Người 4 | Hỏi Người 4 trước |
| `mobile/lib/app/`, `core/`, `data/`, `shared/`, `pubspec.yaml` | **Dùng chung** | Theo mục 6 |
| `backend/`, `docs/API.md`, `docs/DATABASE.md` | **Dùng chung** | Theo mục 6 |

Widget chỉ dùng trong màn của mình thì đặt trong thư mục của mình, ví dụ `features/watch/widgets/like_button.dart`. Không đặt vào `shared/`.

## 6. Sửa phần dùng chung

Phần dùng chung ảnh hưởng cả 4 người, nên:

1. **Báo trong nhóm chat trước**: "Mình cần thêm X vào `VideoCardLarge` vì Y".
2. Làm trên **nhánh riêng** (`chore/n3-shared-...` hoặc `feature/n2-backend-...`). Không trộn với code màn hình.
3. PR nhỏ, gắn nhãn `shared`, cần trưởng nhóm approve.
4. Merge xong, nhắn nhóm: "Đã merge, mọi người rebase develop nhé".

Các trường hợp thường gặp:

| Muốn | Làm |
| --- | --- |
| Thêm package vào `pubspec.yaml` | Hỏi nhóm (có thể người khác đã có package tương tự). PR riêng `chore(deps): ...`. |
| Thêm route mới | Thêm vào `app/routes.dart` + `app/router.dart` trong PR riêng. |
| Cần API mới hoặc thêm trường vào API | Tạo Issue nhãn `api`, ghi rõ endpoint, request, response. Người làm backend thêm và **cập nhật `docs/API.md` trong cùng PR**. |
| Sửa model (`data/models`) | Chỉ **thêm** trường, không đổi tên hay xóa trường người khác đang dùng. |
| Sửa widget dùng chung | Chỉ thêm tham số **tùy chọn** (có giá trị mặc định) để không làm hỏng màn của người khác. |

## 7. Xử lý xung đột (conflict)

```bash
git fetch origin
git rebase origin/develop
# Git báo CONFLICT ở file nào -> mở file, tìm <<<<<<< ======= >>>>>>>
# Giữ đúng phần cần giữ, xóa các dấu, rồi:
git add <file>
git rebase --continue
# Rối quá thì quay lại như trước khi rebase:
git rebase --abort
```

- Xung đột ở file **của người khác** hoặc **dùng chung**: **gọi người đó** cùng xử lý. Không tự chọn "giữ bản của mình".
- Sau rebase, push bằng `git push --force-with-lease` (**chỉ trên nhánh của mình**).

## 8. Điều cấm

- ❌ Push thẳng lên `main` hoặc `develop`.
- ❌ `git push --force` lên `main` / `develop`, hoặc lên nhánh của người khác.
- ❌ Commit file build, file DB (`vtube.db`), thư mục `uploads/`, file IDE, mật khẩu hoặc key.
- ❌ Merge PR của chính mình khi chưa có ai approve.
- ❌ Sửa code người khác "cho nhanh" mà không nói.
- ❌ Đổi tên hoặc xóa thứ trong phần dùng chung mà người khác đang dùng.

## 9. Mốc phát hành

Trưởng nhóm merge `develop` → `main` và gắn tag ở mỗi mốc:

| Tag | Khi |
| --- | --- |
| `v0.1` | Khung chạy được: backend + app có bottom nav, đăng nhập |
| `v0.5` | Mỗi người xong 2 màn |
| `v0.9` | Đủ 16 màn, test chéo xong |
| `v1.0` | Bản nộp |

```bash
git checkout main && git pull
git merge --no-ff develop -m "release: v0.5"
git tag v0.5 && git push origin main --tags
```

## 10. Thiết lập repo lần đầu (trưởng nhóm)

1. Tạo repo trên GitHub, push code này lên nhánh `main`, tạo nhánh `develop` từ `main`.
2. Settings → General → Pull Requests: chỉ bật **Allow squash merging**, bật **Automatically delete head branches**.
3. Settings → Branches → Add rule cho `main` và `develop`:
   - Require a pull request before merging, 1 approval.
   - Require review from Code Owners (cho thư mục dùng chung).
   - Không cho force push.
4. Thêm 3 thành viên vào Collaborators.
5. Sửa `.github/CODEOWNERS`, thay `@truong-nhom` và `@nguoi-1` ... `@nguoi-4` bằng username GitHub thật.
6. Tạo nhãn (Issues → Labels): `shared`, `api`, `bug`, `m01` ... `m16`.
