# MediCare Dental, ứng dụng nha khoa cho bệnh nhân

```
App Flutter (frontend/)  --HTTP + token-->  Backend Node.js (backend/)  -->  Firebase (Authentication + Firestore)
```

- Firestore project: `yoursmile-49379`. Firestore Rules chặn mọi đọc/ghi trực tiếp từ app, mọi dữ liệu đi qua API backend.
- Chi tiết API, quy ước viết API, script backend: [`backend/README.md`](backend/README.md).
- Danh sách lỗi audit và trạng thái: [`AUDIT_ISSUE_REGISTER.md`](frontend/docs/handover/AUDIT_ISSUE_REGISTER.md). Checklist demo: [`DEMO_READINESS_CHECKLIST.md`](frontend/docs/handover/DEMO_READINESS_CHECKLIST.md).

## Tình trạng ngày 02/11/2026 (trước demo 03/11/2026)

| Kiểm tra | Kết quả | Loại |
|---|---|---|
| `flutter analyze` | Không có lỗi | Tĩnh |
| `flutter test` (mặc định, dữ liệu giả) | 403 đạt, 0 lỗi, 132 bỏ qua | Dữ liệu giả, không gọi mạng |
| `flutter test --dart-define=DATA_SOURCE=api` | 521 đạt, 0 lỗi, 14 bỏ qua | API giả (`MockClient`), không gọi mạng |
| `npm test` (backend, Node 24) | 670 đạt, 0 lỗi | Firestore giả |
| `node scripts/preflight-demo.js` | 0 lỗi, 0 cảnh báo | Đọc Firestore thật |
| `node scripts/e2e-smoke.js` | **14 PASS, 0 FAIL, 0 BỎ QUA** | **Chạy thật** qua API localhost và Firestore, tự dọn sạch dữ liệu đã tạo |

Test "bỏ qua" là test chỉ dành cho chế độ còn lại (mock hoặc api), không phải test bị tắt.

Kết quả e2e ngày 02/11/2026 chạy đủ luồng: đặt lịch, staff xác nhận, nhắc lịch (`appointment_reminder`), hoàn tất kèm kết quả khám và 2 thuốc, bệnh nhân đọc lần khám, đơn thuốc, hóa đơn, tạo liệu trình và đánh dấu buổi 1, đề xuất tái khám, nhắc tái khám (`follow_up_reminder`), đặt lịch từ đề xuất, hủy, tải và xóa ảnh trước sau. Sau đó script xóa 20 bản ghi đã tạo; kiểm tra lại không còn bản ghi nào sót.

# 1. Chức năng

## Đã có

| Nhóm | Chức năng | API chính |
|---|---|---|
| Tài khoản | Đăng ký, đăng nhập, quên mật khẩu, đăng xuất, tự đăng nhập lại, đổi mật khẩu, xác minh email (Firebase Auth) | Không cần |
| Hồ sơ | Xem, sửa hồ sơ; giới tính, thông tin sức khỏe; kiểm tra họ tên, số điện thoại, ngày sinh | `/api/users/me` |
| Người thân | Thêm, sửa, xóa mềm (chặn xóa khi còn lịch sắp tới); người đã xóa vẫn xem được lịch sử khám trên app | `/api/family-members` |
| Ảnh | Ảnh đại diện bản thân, người thân; ảnh trước sau điều trị (tối đa 30 ảnh mỗi liệu trình). Lưu base64 trong Firestore, JPEG/PNG tối đa 700 KB, app tự nén | `/api/users/me/avatar`, `/api/treatments/:id/photos`, `/api/media/:id` |
| Danh mục | Dịch vụ, combo, bác sĩ: danh sách, chi tiết, tìm kiếm không dấu, lọc; combo chỉ hiện bác sĩ làm đủ dịch vụ | `/api/services`, `/api/combos`, `/api/doctors` |
| Đã lưu | Lưu dịch vụ, combo, bác sĩ, bài viết | `/api/favorites` |
| Đặt lịch | Báo giá, voucher, giờ trống theo ngày, đặt cho bản thân hoặc người thân, giữ chỗ trong transaction (không đặt trùng), ghi chú, chống tạo trùng khi gửi lại (`Idempotency-Key`) | `/api/bookings/quote`, `/api/availability`, `/api/appointments` |
| Lịch hẹn | Danh sách, chi tiết, hủy (cách giờ khám ít nhất 2 giờ), lịch sắp tới ở trang chủ | `/api/appointments` |
| Nhân viên (qua `api-test.http`) | Xem lịch chờ, xác nhận, từ chối (bắt buộc lý do), hoàn tất kèm kết quả khám, đơn thuốc, hóa đơn; tạo liệu trình, đánh dấu buổi; đề xuất tái khám; chạy nhắc lịch ngay | `/api/appointments/staff`, `PATCH /api/appointments/:id/status`, `/api/treatments`, `/api/follow-ups` |
| Hồ sơ khám | Lịch sử khám, kết quả khám, đơn thuốc, hóa đơn, liệu trình, buổi điều trị, ảnh trước sau, lịch tái khám; chọn xem theo bản thân hoặc người thân | `/api/patients/:id/...`, `/api/visits`, `/api/invoices`, `/api/treatments` |
| Tái khám | Đặt lịch từ đề xuất tái khám (đề xuất chuyển Đã đặt lịch; lịch bị hủy hoặc từ chối thì quay về Đã đề xuất; hoàn tất thì Đã tái khám) | `followUpId` trong `POST /api/appointments` |
| Thông báo | Thông báo trong app, số chưa đọc, đọc tất cả; bấm thông báo mở đúng màn | `/api/notifications` |
| Nhắc tự động | Nhắc lịch hẹn đã xác nhận trong 24 giờ tới; nhắc tái khám có ngày trong 3 ngày tới. Chạy khi bật backend và mỗi 10 phút; tắt "Nhận thông báo" thì không nhận nhắc | `POST /api/notifications/run-reminders` (staff chạy ngay) |
| Nội dung | Bài viết, trang chủ | `/api/articles`, `/api/home` |

Trạng thái lịch hẹn: `booked` (Chờ xác nhận), `confirmed` (Đã xác nhận), `rejected` (Bị từ chối), `cancelled` (Đã hủy), `completed` (Đã hoàn tất). Chỉ được chuyển `booked` sang `confirmed`, `rejected`, `cancelled` và `confirmed` sang `completed`, `cancelled`; chuyển khác trả 409.

## Chưa có (không hứa trong demo)

| Chưa có | Hiện tại thay bằng |
|---|---|
| Thông báo đẩy (FCM): thông báo bật ra ngoài màn hình khi app đóng | Thông báo chỉ hiện trong mục Thông báo của app, tải lại khi mở app hoặc kéo để tải lại |
| Màn hình nhân viên trong app | Staff thao tác bằng `backend/api-test.http` (khối DEMO D1 đến D8) |
| Giới hạn tần suất gọi API (rate limit) | Chỉ chạy backend trong mạng nội bộ, xem mục 6 |
| Phân trang hồ sơ khám | App tải toàn bộ hồ sơ của người khám đang chọn; đủ nhanh với dữ liệu demo, chưa đo với dữ liệu lớn |
| Nhắc lịch mốc 2 giờ trước giờ khám | Chỉ có mốc 24 giờ |
| Tự làm mới token khi API trả 401 | App báo phiên hết hạn, người dùng đăng xuất và đăng nhập lại |

# 2. Cách chạy

## 2.1. Cài đặt (1 lần, và sau mỗi lần pull có đổi thư viện)

```powershell
git pull
cd frontend
flutter pub get
cd ../backend
npm install
```

- Backend cần **Node.js 24** (test backend từ chối chạy trên phiên bản khác).
- File khóa Firebase: Firebase Console, project **yoursmile**, Project settings, tab Service accounts, Generate new private key. Đổi tên thành `serviceAccountKey.json`, đặt trong `backend/` (ngang `package.json`). **Không push, không gửi cho ai**; lỡ lộ thì báo Bình ngay.
- Tạo `backend/.env` theo `backend/.env.example`, điền `TEST_PASSWORD` (mật khẩu `test123@gmail.com`) và `STAFF_PASSWORD` (mật khẩu `staff@nhakhoa.com`). Mật khẩu hỏi Bình. File này không lên GitHub.

## 2.2. Chạy app: mở 2 terminal

Terminal 1, backend (để chạy suốt):

```powershell
cd backend
npm start        # hoặc npm run dev: tự khởi động lại khi sửa code
```

Thấy `Server chạy tại http://localhost:3000` là được. Tắt bằng `Ctrl + C`.

Terminal 2, app:

```powershell
cd frontend
flutter run
```

- Mặc định app dùng dữ liệu thật (`DATA_SOURCE=api`); máy ảo Android tự gọi `http://10.0.2.2:3000`.
- Máy thật: `flutter run --dart-define=API_BASE_URL=http://<IP máy chạy backend>:3000`, điện thoại và máy tính cùng mạng Wi-Fi.
- Dữ liệu giả để xem giao diện: `flutter run --dart-define=DATA_SOURCE=mock`. Đăng nhập vẫn dùng Firebase thật, không phải chế độ offline.
- Chạy bằng F5 trong VS Code: cấu hình ở `.vscode/launch.json` (không lên GitHub). Nếu còn cổng `8080` hoặc `backend/bin/server.dart` (backend Dart cũ) thì sửa thành `3000` hoặc xóa cấu hình đó.

Không bật backend thì app vẫn mở nhưng báo "Không kết nối được tới máy chủ".

## 2.3. Tài khoản nhân viên (staff)

```powershell
cd backend
node scripts/set-staff.js staff@nhakhoa.com            # gán quyền
node scripts/set-staff.js staff@nhakhoa.com --remove   # gỡ quyền
```

Tài khoản phải **đăng nhập lại** thì mới có quyền mới.

# 3. Kiểm thử

## 3.1. Test tự động (không đụng dữ liệu thật)

```powershell
cd backend
npm test                                   # cần Node 24, dùng Firestore giả

cd ../frontend
flutter analyze
flutter test                               # chế độ dữ liệu giả
flutter test --dart-define=DATA_SOURCE=api # nhánh API, dùng MockClient, không gọi mạng
```

## 3.2. Test API bằng `backend/api-test.http`

1. Cài extension **REST Client** trong VS Code, tạo `backend/.env` như mục 2.1.
2. Bật backend, mở `backend/api-test.http`.
3. Bấm 2 request ở mục **ĐĂNG NHẬP (dùng chung)** trước (staff chỉ cần cho phần nhân viên). Token Firebase hết hạn sau khoảng 1 giờ, hết hạn thì bấm lại.
4. Bấm request theo mục: **DEMO THUYẾT TRÌNH** (D1 đến D8), **MODULE 1** đến **MODULE 4**, các khối A01, A05, A11, A13, A17, ảnh đại diện, giai đoạn 3.
5. Thêm request mới vào đúng mục. Không ghi mật khẩu, không dán token hay id cứng: dùng biến lấy từ response (`# @name ten` rồi `{{ten.response.body.$.id}}`). Sửa `.env` mà REST Client chưa nhận thì đóng mở lại VS Code.

## 3.3. `preflight-demo.js`: kiểm tra trước giờ demo (chỉ đọc)

```powershell
cd backend
node scripts/preflight-demo.js
```

In bảng OK / CẢNH BÁO / LỖI, có LỖI thì mã thoát 1. Không ghi gì vào Firestore. Kiểm tra:

- `backend/.env` có đủ biến bắt buộc, có `serviceAccountKey.json`;
- `staff@nhakhoa.com` có quyền staff;
- mọi bác sĩ đang hoạt động có ca làm việc từ hôm nay tới 7 ngày sau (trừ Chủ nhật);
- mọi dịch vụ có ít nhất 1 bác sĩ làm được;
- mọi combo có ít nhất 1 bác sĩ làm đủ dịch vụ, thời lượng combo khớp tổng dịch vụ (lệch thì CẢNH BÁO);
- voucher nào đang dùng được (còn bật, trong hạn, còn lượt).

**Khi nào chạy:** sáng hôm demo sau khi chạy `seed-schedules.js --apply`; sau khi sửa dữ liệu danh mục, bác sĩ, voucher trên Firestore. Chạy bao nhiêu lần cũng được.

## 3.4. `e2e-smoke.js`: chạy thử thật toàn luồng (có ghi rồi tự xóa)

```powershell
cd backend
npm start                          # terminal 1: backend phải đang chạy ở cổng 3000
node scripts/e2e-smoke.js          # terminal 2
```

- Đăng nhập `test123@gmail.com` và `staff@nhakhoa.com` bằng mật khẩu trong `backend/.env` (không in ra), gọi API thật theo đúng luồng ở trên, in PASS / FAIL / BỎ QUA từng bước.
- Bước nhắc lịch cần một giờ trống trong 24 giờ tới; không có thì bước đó BỎ QUA, không tính FAIL.
- Cuối script **luôn dọn dữ liệu**, kể cả khi có bước FAIL: chỉ xóa đúng các id do script tạo và thuộc test123. Dọn lỗi thì script in danh sách id để xóa tay.
- Không dùng voucher, không đụng dịch vụ, bác sĩ, lịch làm việc.

**Khi nào chạy:** tối trước demo hoặc sáng hôm demo, sau `preflight-demo.js`, để chắc toàn luồng chạy được trên dữ liệu thật. **Không chạy trong lúc đang demo**: script tạm giữ khung giờ và tạo thông báo cho test123 trong vài giây.

## 3.5. Script dữ liệu khác (`backend/scripts/`)

| Script | Việc | Mặc định |
|---|---|---|
| `seed-schedules.js` | Tạo ca làm việc cho mọi bác sĩ đang hoạt động từ hôm nay tới 30 ngày sau, thứ 2 đến thứ 7 | Chạy thử: đọc Firestore, in số ca sẽ tạo, không ghi. `--apply` mới ghi |
| `cleanup-test-data.js <email>` | Xóa dữ liệu nghiệp vụ của một tài khoản test (lịch, hồ sơ, thông báo...) | Chạy thử, `--apply` mới xóa; `--keep-profile` giữ hồ sơ |
| `seed-demo.js <email>` | Tạo dữ liệu demo cho một tài khoản | Chạy thử, `--apply` mới ghi |
| `set-staff.js <email>` | Gán hoặc gỡ quyền staff | Ghi ngay |

`seed-schedules.js` tính ngày và id ca (`${doctorId}_${YYYY-MM-DD}_am` / `_pm`) **theo giờ Việt Nam (UTC+7)**, không phụ thuộc múi giờ của máy chạy, nên chạy lúc sáng sớm vẫn đúng ngày. Không ghi đè, không xóa: id đã có thì bỏ qua, **bác sĩ đã có ca bất kỳ trong ngày thì bỏ qua cả ngày đó**. Chạy lại nhiều lần không tạo trùng.

# 4. Kịch bản demo (khối DEMO trong `backend/api-test.http`)

Mỗi request D lấy id tự động từ request trước, bấm theo thứ tự, không copy gì. D1, D3 lấy lịch mới nhất (`$[0]`): luôn kiểm tra `patientName` đúng người đang demo trước khi bấm tiếp. D4 hoàn tất lịch là **không hoàn tác được**.

| Bước | Làm gì | Khán giả thấy |
|---|---|---|
| Chuẩn bị | Làm đủ checklist mục 5; bấm đăng nhập staff trong `api-test.http` | |
| 1 | Trên app: đăng ký tài khoản mới, điền họ tên, thêm ảnh đại diện | Tài khoản thật trên Firebase |
| 2 | Trên app: đặt lịch **ngày mai buổi sáng** (để còn trong 24 giờ), có ghi chú | Lịch "Chờ xác nhận", thông báo đặt lịch |
| 3 | **D1** xem lịch chờ mới nhất, kiểm tra `patientName`; **D2** xác nhận | App: lịch "Đã xác nhận", có thông báo |
| 4 | **D7** chạy nhắc lịch (làm trước D4, khi lịch còn ở trạng thái đã xác nhận) | App: "Nhắc lịch hẹn", bấm mở chi tiết lịch |
| 5 | **D3** xem lịch đã xác nhận; **D4** hoàn tất kèm chẩn đoán, 2 thuốc (sửa nội dung trước khi bấm) | App: "Đã có kết quả khám", chi tiết lần khám, đơn thuốc, hóa đơn |
| 6 | **D5** tạo liệu trình 3 buổi; **D5b** đánh dấu buổi 1 | App: liệu trình "Đang điều trị" |
| 7 | **D6** đề xuất tái khám 2 tuần sau | App: "Bác sĩ đề xuất tái khám", có nút đặt lịch |
| 8 | (Tùy chọn) **D6b** đề xuất tái khám 2 ngày sau rồi bấm lại **D7** | App: "Nhắc lịch tái khám" |
| 9 | Trên app: thêm ảnh trước sau ở liệu trình; đặt lịch tái khám từ đề xuất | Đề xuất chuyển "Đã đặt lịch", có nút "Xem lịch đã đặt" |
| 10 | (Tùy chọn) **D8** staff xem lịch mới đặt có `followUpId` | |

Response D7: `{ "created": số nhắc lịch hẹn, "followUpReminders": số nhắc tái khám }`. Backend cũng tự chạy nhắc mỗi 10 phút, nên có thể đã nhắc trước khi bấm D7 (khi đó số trả về là 0 nhưng thông báo vẫn có trên app).

# 5. Checklist trước demo

Sáng hôm demo, theo thứ tự:

- [ ] `cd backend`, `node scripts/seed-schedules.js` (xem thử) rồi `node scripts/seed-schedules.js --apply` để có ca làm việc cho các ngày mới.
- [ ] `node scripts/preflight-demo.js`: phải 0 LỖI. Có LỖI thì sửa theo gợi ý trong bảng rồi chạy lại.
- [ ] **Bật backend trước** (`npm start`) và để chạy suốt buổi: nhắc lịch, nhắc tái khám chỉ chạy khi backend đang bật.
- [ ] (Nên làm) `node scripts/e2e-smoke.js` với backend đang bật: phải 0 FAIL. Chạy xong trước giờ demo, không chạy trong lúc demo.
- [ ] Mở `backend/api-test.http`, bấm **đăng nhập staff** ngay trước khi demo (token hết hạn sau khoảng 1 giờ).
- [ ] Bật máy ảo hoặc điện thoại, `flutter run`, đăng nhập thử; máy thật thì kiểm tra `API_BASE_URL` đúng IP.
- [ ] Tài khoản demo chỉ chứa dữ liệu giả lập, không dùng thông tin người bệnh thật.
- [ ] Muốn dọn dữ liệu test của test123: `node scripts/cleanup-test-data.js test123@gmail.com` (xem thử) rồi thêm `--apply --keep-profile`.

# 6. Giới hạn bảo mật khi chạy (AUD-18)

- Backend **chỉ chạy trên máy cá nhân trong mạng nội bộ** (máy ảo, hoặc điện thoại cùng Wi-Fi). Server nghe trên mọi card mạng của máy ở cổng 3000, nên máy khác trong cùng mạng gọi được.
- **Không mở cổng 3000 ra Internet** (không port forwarding trên router, không đưa lên máy chủ công khai, không dùng công cụ chia sẻ cổng ra ngoài).
- Backend **chưa có rate limit** (giới hạn số lần gọi API): một máy gọi liên tục sẽ không bị chặn. Đây là giới hạn đã biết, chưa xử lý trong đợt này.
- Không push `serviceAccountKey.json`, `backend/.env`; không in mật khẩu, token lên màn hình khi thuyết trình.

# 7. Quy ước dữ liệu

- Lịch hẹn, hồ sơ khám lưu `accountId` (UID chủ tài khoản) và `patientId` (UID bản thân hoặc id người thân trong `users/{uid}/family_members`).
- Mã thật: bản thân là UID Firebase; dịch vụ, combo, bác sĩ, bài viết dạng `svc_01`, `combo_01`, `doc_01`, `article_01`. Mã giả `patient-001`, `service-checkup`... chỉ có trong `frontend/lib/data/mock_data.dart` khi `DATA_SOURCE=mock`.
- Thông báo: `{ userId, title, body, type, refId, isRead, createdAt }`.
- Tên trường `camelCase`, tiền là số nguyên VND, mục ẩn dùng `isActive: false`.
- Thời điểm (`createdAt`...) lưu Timestamp; ngày không có giờ lưu chuỗi `"YYYY-MM-DD"`; giờ trong ngày lưu `"HH:mm"`. Giờ phòng khám là giờ Việt Nam (UTC+7).
- App gọi API qua `frontend/lib/core/network/api_client.dart` (xuất lại ở `frontend/lib/data/api_client.dart`), không dùng `cloud_firestore`. **Không sửa Firestore Rules.**

# 8. Git hằng ngày

```powershell
git pull                                   # trước khi làm
git add . ; git commit -m "Moc truoc khi lam ..."   # mốc an toàn trước khi để Claude sửa
```

Làm xong và đã test: `git status`, kiểm tra **không có** `serviceAccountKey.json`, `.env`, `node_modules`, `build`, và `api-test.http` không chứa mật khẩu. Ổn thì `git add .`, `git commit -m "..."`, `git pull`, `git push`, rồi báo nhóm.

- Gặp CONFLICT khi pull: dừng lại, `git status`, chụp màn hình gửi nhóm, không bấm bừa Accept Current/Incoming.
- Màn hình đen có chữ `Merge branch...`: bấm vào màn hình, Esc, gõ `:wq`, Enter.
- Không bao giờ: `git push --force`, push code đang lỗi.

# 9. Tài liệu khác

- [`backend/README.md`](backend/README.md): bảng API đầy đủ, quy tắc đặt lịch, ảnh, nhắc lịch, script.
- [`frontend/docs/handover/`](frontend/docs/handover/): tài liệu bàn giao và audit từ 21/10 đến 01/11/2026. Các file có dòng "Tài liệu lịch sử" ở đầu là ảnh chụp tại thời điểm viết, không phải hướng dẫn hiện hành. Hai file đang cập nhật: `AUDIT_ISSUE_REGISTER.md`, `DEMO_READINESS_CHECKLIST.md`.
- Nhật ký các đợt sửa trước (31/10/2026) và prompt giao việc cho từng thành viên có trong lịch sử git của file này (`git log -p README.md`).
