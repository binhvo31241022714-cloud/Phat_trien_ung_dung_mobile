# Backend API nha khoa (Node.js + Express + Firebase)

REST API cho app Flutter nha khoa. Dữ liệu lưu trên Firestore, đăng nhập bằng Firebase Authentication.

## Chạy

1. Xin file `serviceAccountKey.json` từ nhóm, đặt vào thư mục `backend/`.
   File này là khóa quản trị Firebase, **không commit lên git** (đã có trong `.gitignore`).
2. Cài thư viện và chạy:

```bash
cd backend
npm install
npm run dev     # tự khởi động lại khi sửa code
# hoặc: npm start
```

Server chạy tại `http://localhost:3000`. Mở trình duyệt vào địa chỉ đó thấy dòng "API nha khoa đang chạy" là được.

## Cấu trúc

```
backend/
├── src/
│   ├── server.js              # Khởi động server, gắn route cho từng module
│   ├── config/firebase.js     # Kết nối Firebase, xuất ra db (Firestore) và auth
│   ├── middleware/auth.js     # Kiểm tra token đăng nhập, gắn req.user
│   └── routes/                # Mỗi file là một nhóm API
├── api-test.http              # Request mẫu để test (extension REST Client)
└── serviceAccountKey.json     # Khóa Firebase (không có trên git)
```

Không sửa `server.js`, `config/firebase.js`, `middleware/auth.js` khi chưa báo nhóm.

## Quy ước viết API

Xem `routes/familyMembers.js` làm mẫu.

- API cần đăng nhập thì thêm middleware `auth`. Khi đó `req.user.uid` là id của user đang gọi.
- Dữ liệu riêng của user lưu trong `users/{uid}/...` để người khác không đọc được.
- Trả về document theo dạng `{ id: doc.id, ...doc.data() }`.
- Lỗi trả về dạng `{ "message": "..." }` với mã:

| Mã  | Khi nào |
|-----|---------|
| 400 | Thiếu dữ liệu hoặc dữ liệu sai |
| 401 | Chưa đăng nhập hoặc token hết hạn (do `auth.js` tự trả) |
| 404 | Không tìm thấy |
| 500 | Lỗi server (do `server.js` tự bắt, không cần `try/catch`) |

## Gửi token khi gọi API

App Flutter lấy ID token từ Firebase Auth rồi gửi kèm header:

```
Authorization: Bearer <idToken>
```

Khi test bằng `api-test.http`: tạo `backend/.env` theo `backend/.env.example` (mật khẩu hỏi Bình), bật server, bấm request ở mục **ĐĂNG NHẬP (dùng chung)** trước để có `{{token}}` (và `{{staffToken}}`), sau đó mới bấm các request khác. File không chứa mật khẩu, mật khẩu đọc bằng `{{$dotenv ...}}`.

## API Module 1 - Tài khoản và dữ liệu cơ bản

| Method | Endpoint                  | Đăng nhập | Mô tả |
|--------|---------------------------|-----------|-------|
| POST   | /api/users/sync           | Có  | Tạo hồ sơ nếu chưa có. Body: `{ fullName, phone }` |
| GET    | /api/users/me             | Có  | Xem hồ sơ của mình |
| PATCH  | /api/users/me             | Có  | Sửa `fullName`, `phone`, `birthday`, `address`, giới tính, thông tin sức khỏe (xem bên dưới) và `notificationsEnabled` (true/false: tắt thì không nhận nhắc lịch, nhắc tái khám; `GET /me` mặc định true) |
| GET    | /api/family-members       | Có  | Danh sách người thân (ẩn người đã xóa) |
| POST   | /api/family-members       | Có  | Thêm người thân. Bắt buộc `fullName`; nhận thêm giới tính và thông tin sức khỏe |
| PATCH  | /api/family-members/:id   | Có  | Sửa người thân (gồm cả giới tính và thông tin sức khỏe) |
| DELETE | /api/family-members/:id   | Có  | Xóa mềm người thân (xem "Xóa người thân" bên dưới) |
| PUT    | /api/users/me/avatar      | Có  | Đặt ảnh đại diện. Body `{ image: base64, mimeType? }` (xem "Ảnh" bên dưới) |
| DELETE | /api/users/me/avatar      | Có  | Gỡ ảnh đại diện |
| PUT    | /api/family-members/:id/avatar | Có | Ảnh đại diện người thân còn hoạt động |
| DELETE | /api/family-members/:id/avatar | Có | Gỡ ảnh đại diện người thân |
| GET    | /api/media/:id            | Có  | Trả ảnh nhị phân. Chỉ chủ tài khoản (`ownerAccountId`) hoặc staff, người khác 403 |
| GET    | /api/services             | Không | Danh sách dịch vụ |
| GET    | /api/services/:id         | Không | Chi tiết dịch vụ |
| GET    | /api/combos               | Không | Danh sách combo |
| GET    | /api/combos/:id           | Không | Chi tiết combo |
| GET    | /api/doctors              | Không | Danh sách bác sĩ |
| GET    | /api/doctors/:id          | Không | Chi tiết bác sĩ |
| GET    | /api/favorites            | Có  | Danh sách nội dung đã lưu |
| POST   | /api/favorites            | Có  | Lưu nội dung. Body: `{ type, itemId }` |
| DELETE | /api/favorites/:id        | Có  | Bỏ lưu một mục |

### Ảnh (không dùng Firebase Storage)

Ảnh lưu trong Firestore dạng base64 ở `media/{id}`: `{ ownerAccountId, patientId, kind ("avatar" | "treatment_photo"), mimeType, data, size, createdAt, createdBy }`.
- Chỉ nhận JPEG hoặc PNG, kiểm tra theo byte đầu của file (không tin `mimeType` gửi lên); `image` có thể là base64 thuần hoặc `data:image/...;base64,...`.
- Ảnh JPEG/PNG sau giải mã tối đa **716.800 bytes (700 KiB)**; vượt giới hạn trả `413`, sai định dạng trả `400`. Giới hạn này độc lập với JSON transport và không thay đổi.
- JSON request body toàn API: **1 MiB = 1.048.576 bytes** (`utils/media.js` → `jsonBody`), gồm `PUT /api/users/me/avatar`, `PUT /api/family-members/:id/avatar`, `POST /api/treatments/:id/photos`. Đo bằng `Buffer.byteLength(JSON.stringify(body), "utf8")`, gồm cả base64 và metadata. JSON vượt giới hạn trả `413` trước route; dưới/trong giới hạn vẫn có thể trả `400` do field validation (ví dụ address tối đa 200 ký tự). Bình/Phương/Ngân đã duyệt phương án B cho demo; không dùng parser dispatcher.
- Hồ sơ lưu `avatarMediaId`; thay ảnh thì ảnh cũ bị xóa trong cùng transaction. Staff chỉ xem, không đổi ảnh đại diện.

### Dữ liệu `users/{uid}` và `users/{uid}/family_members/{id}`

| Trường | Kiểu | Có ở | Ghi chú |
|---|---|---|---|
| `fullName` | chuỗi, 1 đến 100 ký tự | cả hai | Bắt buộc khi thêm người thân; có gửi thì không được rỗng |
| `phone` | chuỗi 9 đến 11 chữ số | cả hai | `""` nếu chưa có. Không nhận `+84`, dấu cách, dấu chấm (app tự chuẩn hóa trước khi gửi) |
| `birthday` | chuỗi `"YYYY-MM-DD"` | cả hai | `""` nếu chưa có. Phải là ngày có thật, không ở tương lai (giờ Việt Nam) |
| `email` | chuỗi | users | Email đăng nhập Firebase, không sửa qua API |
| `address` | chuỗi, tối đa 200 ký tự | users | |
| `relationship` | chuỗi, tối đa 50 ký tự | family_members | Ví dụ "Mẹ", "Con" |
| `gender` | `"male"` \| `"female"` \| `"other"` \| `""` | cả hai | `""` là chưa chọn. Giá trị khác trả 400 |
| `allergies` | chuỗi, tối đa 500 ký tự | cả hai | Dị ứng thuốc, ví dụ `"Penicillin, Lidocaine"` |
| `medicalConditions` | mảng chuỗi | cả hai | Chỉ nhận: `diabetes` (tiểu đường), `heart_disease` (bệnh tim mạch), `hypertension` (huyết áp cao), `bleeding_disorder` (rối loạn đông máu), `asthma` (hen suyễn), `hepatitis` (viêm gan), `other` (khác). Giá trị lạ trả 400 |
| `currentMedications` | chuỗi, tối đa 500 ký tự | cả hai | Thuốc đang dùng |
| `isPregnant` | `true` \| `false` | cả hai | Phải là boolean, chuỗi `"true"` trả 400 |
| `healthNotes` | chuỗi, tối đa 500 ký tự | cả hai | Ghi chú khác |
| `createdAt` | Timestamp | cả hai | |

- Kiểm tra họ tên, số điện thoại, ngày sinh, mối quan hệ, địa chỉ dùng chung ở `src/utils/profile.js` (`readProfile`). Sai kiểu hoặc sai độ dài trả 400 kèm câu báo tiếng Việt. Chuỗi được bỏ khoảng trắng đầu cuối trước khi lưu.
- Kiểm tra giới tính và sức khỏe dùng chung ở `src/utils/health.js` (`readHealth`).
- Khi GET, trường còn thiếu (dữ liệu cũ) được trả giá trị mặc định: `""`, `[]` hoặc `false` (`withHealthDefaults`).
- PATCH chỉ đổi những trường có gửi lên; POST người thân thiếu trường thì lưu mặc định.

### Xóa người thân (xóa mềm)

- `DELETE /api/family-members/:id` không xóa document mà đặt `isArchived: true` và `archivedAt` (Timestamp), để hồ sơ khám, hóa đơn, lịch hẹn cũ vẫn còn.
- Người thân còn lịch hẹn chưa hủy và chưa diễn ra thì trả **409**, phải hủy lịch trước.
- Người thân đã xóa: không hiện trong `GET /api/family-members`, `PATCH`/`DELETE` trả 404, **không đặt lịch mới được** (`POST /api/appointments` trả 400), nhưng chủ tài khoản **vẫn xem được hồ sơ khám cũ** (`utils/records.js` chỉ kiểm tra document còn tồn tại).
- Module khác đọc `family_members` để kiểm tra người khám thì nhớ xét `isArchived` nếu là thao tác tạo mới.

### Ghi chú về isActive

- API danh sách (`GET /api/services`, `/api/combos`, `/api/doctors`) ẩn mục có `isActive: false`. Mục không có trường `isActive` coi như đang bật.
- API chi tiết (`GET /:id`) vẫn trả mục đã tắt, để xem lại được từ danh sách yêu thích hoặc lịch sử.

### Ghi chú về favorites

- Không lưu được mục có `isActive: false` (trả 400).

- `type` là một trong: `service`, `combo`, `doctor`, `article`. `itemId` là id document trong collection tương ứng (`services`, `combos`, `doctors`, `articles`).
- Id của mục đã lưu là `${type}_${itemId}`, ví dụ `service_svc_01`. Lưu cùng một món nhiều lần vẫn chỉ có 1 mục.
- Muốn bỏ lưu thì gọi `DELETE /api/favorites/service_svc_01`.

## Module 3 - Hồ sơ nha khoa

| Method | Endpoint | Đăng nhập | Mô tả |
|---|---|---|---|
| GET | `/api/patients/:id/visits` | Có | Lịch sử khám của bản thân hoặc người thân |
| GET | `/api/visits/:id` | Có | Kết quả khám và chẩn đoán |
| GET | `/api/visits/:id/prescriptions` | Có | Đơn thuốc của lần khám |
| GET | `/api/patients/:id/invoices` | Có | Danh sách hóa đơn |
| GET | `/api/invoices/:id` | Có | Chi tiết hóa đơn |
| GET | `/api/patients/:id/treatments` | Có | Danh sách liệu trình |
| GET | `/api/treatments/:id` | Có | Chi tiết và tiến độ liệu trình |
| GET | `/api/treatments/:id/sessions` | Có | Các buổi điều trị |
| POST | `/api/treatments/:id/sessions/link-visit` | Có | Gắn một lần khám đã hoàn thành vào buổi do người dùng chọn. Body: `{ visitId, sessionId }`. Visit phải có `status: "completed"` (A10) |
| POST | `/api/treatments` | Staff | Tạo liệu trình kèm các buổi dự kiến. Body `{ accountId, patientId?, doctorId?, name, diagnosis?, startAt?, endAt?, sessions: [{ scheduledAt?, notes? }] }`. Liệu trình và buổi đều `planned` |
| PATCH | `/api/treatments/:id/sessions/:sessionId` | Staff | Đánh dấu buổi đã làm. Body `{ status: "completed", visitId, notes? }`; visit phải hoàn tất, cùng bệnh nhân, chưa gắn buổi khác. Liệu trình tự chuyển `in_progress`, xong hết buổi thì `completed` |
| GET | `/api/treatments/:id/photos` | Có hoặc Staff | Ảnh cũ (`photos`, `treatment_photos`, mảng `photos` của treatment) và ảnh mới; ảnh mới có `imageUrl` = `/api/media/:mediaId`, mọi ảnh có `canDelete` |
| POST | `/api/treatments/:id/photos` | Có hoặc Staff | Tải ảnh. Body `{ phase: "before" \| "after", sessionId?, image, mimeType?, note? }`. Chủ tài khoản (bản thân hoặc người thân còn hoạt động) hoặc staff; tối đa 30 ảnh mỗi liệu trình (409) |
| DELETE | `/api/treatments/:id/photos/:photoId` | Có hoặc Staff | Xóa ảnh và media; chỉ người tải lên hoặc staff. Ảnh cũ không có `mediaId` trả 409 |
| GET | `/api/patients/:id/follow-ups` | Có | Lịch tái khám |
| GET | `/api/follow-ups/:id` | Có hoặc Staff | Chi tiết đề xuất tái khám (app dùng khi bấm thông báo `follow_up`) |
| POST | `/api/follow-ups` | Staff | Đề xuất tái khám. Body `{ accountId, patientId?, scheduledAt, reason, notes?, doctorId?, visitId?, treatmentId?, serviceId? }`. Lưu `status: "suggested"`, tạo thông báo `follow_up` |

### Hồ sơ khám tạo khi staff hoàn tất lịch

`PATCH /api/appointments/:id/status` với `status: "completed"` có thể gửi thêm
`visit { diagnosis, result, notes }`, `prescriptions [{ medicineName, dosage, frequency, durationDays, instructions }]`,
`invoice { items?: [{ name, quantity, unitPrice }], discount?, paymentMethod?, paid? }`.
Trong cùng transaction backend tạo `visits/visit_{id lịch}` (`status: "completed"`, `scheduledAt` là ngày giờ lịch,
`doctorNote` lấy từ `notes`), `prescriptions/rx_{id lịch}` (chỉ khi có thuốc, thuốc nằm trong `items[]`),
`invoices/inv_{id lịch}` (có cả `visitId` và `appointmentId`) và 1 thông báo `visit_result` có `refId` là visitId.
Không gửi `invoice` thì hóa đơn tự lập từ combo, dịch vụ, voucher của lịch, mặc định `unpaid`.
`paymentMethod` là `cash`, `bank_transfer`, `card` hoặc `e_wallet`. Gọi hoàn tất lại trả `409`, không tạo trùng.

Các API staff kiểm tra `patientId` là chính chủ `accountId` hoặc người thân còn hoạt động của tài khoản đó.
Đề xuất tái khám cũ có `status: "scheduled"` được app hiểu là "Đã đề xuất".

`patientId` không được lấy từ body/query của client. Với API danh sách, `:id` chỉ được phép là
`req.user.uid` hoặc id document trong `users/{req.user.uid}/family_members`. Với API theo
document id, backend đọc document trước rồi kiểm tra `patientId`; tài khoản không có quyền
nhận `403`.

## Module 2 - Đặt lịch nha khoa

| Method | Endpoint | Đăng nhập | Mô tả |
|---|---|---|---|
| POST | `/api/bookings/quote` | Không | Báo giá dịch vụ/combo, trả `subtotal`, `discount`, `totalPrice`, `durationMinutes`; có thể gửi `voucherCode` |
| GET | `/api/availability?date=YYYY-MM-DD&durationMinutes=30` | Không | Giờ trống theo ngày; có thể truyền `doctorId`, `comboId`, `serviceIds` (các mã phân tách bằng dấu phẩy) |
| POST | `/api/vouchers/validate` | Không | Body gồm `code` và `serviceIds` và/hoặc `comboId`; giá được tính lại trên backend |
| POST | `/api/appointments` | Có | Tạo lịch cho bản thân hoặc người thân; `doctorId` có thể bỏ trống để chọn ngẫu nhiên; body có `patientId?`, `serviceIds?`, `comboId?`, `date`, `startTime`, `voucherCode?`, `note?`, `followUpId?`; header tùy chọn `Idempotency-Key` |
| GET | `/api/appointments` | Có | Lịch của tài khoản đang đăng nhập, bao gồm lịch đặt cho người thân |
| GET | `/api/appointments/:id` | Có | Chi tiết lịch; chỉ chủ tài khoản được xem |
| PATCH | `/api/appointments/:id/cancel` | Có | Hủy lịch tương lai và giải phóng các slot đã giữ |
| GET | `/api/appointments/staff?status=booked&date=YYYY-MM-DD&sort=newest` | Staff | Nhân viên xem lịch theo trạng thái (mặc định `booked`), lọc ngày tùy chọn, mỗi lịch có `patientName`. `sort=newest`: mới đặt/mới đổi trạng thái lên trước (mặc định xếp theo ngày giờ khám) |
| PATCH | `/api/appointments/:id/status` | Staff | Nhân viên đổi trạng thái. Body `{ status: "confirmed" \| "rejected" \| "completed", reason? }`, `reason` bắt buộc khi `rejected` (tối đa 500 ký tự). Khi `completed` có thể kèm kết quả khám, đơn thuốc, hóa đơn (xem Module 3) |

### Trạng thái lịch hẹn

| Trạng thái | Nghĩa | App hiển thị |
|---|---|---|
| `booked` | Vừa đặt, chờ phòng khám xác nhận | Chờ xác nhận |
| `confirmed` | Phòng khám đã xác nhận | Đã xác nhận |
| `rejected` | Phòng khám từ chối (có lý do trong `statusReason`) | Bị từ chối |
| `cancelled` | Bệnh nhân hủy | Đã hủy |
| `completed` | Đã khám xong | Đã hoàn tất |

Trạng thái khác: app hiển thị "Không xác định".

Chuyển hợp lệ (kiểm tra bằng `canTransition` trong `utils/booking.js`), còn lại trả **409**, kể cả gọi lại cùng trạng thái:

```
booked    → confirmed | rejected | cancelled
confirmed → completed | cancelled
```

- Bệnh nhân chỉ hủy qua `PATCH /:id/cancel`. Nhân viên dùng `PATCH /:id/status`.
- Khi đổi trạng thái lưu `status`, `statusUpdatedAt` (Timestamp), `statusUpdatedBy` (uid nhân viên), `statusReason` (nếu có).
- `rejected` giải phóng slot và trả 1 lượt voucher giống luồng hủy (hàm dùng chung `readRelease`/`writeRelease` trong `routes/appointments.js`).
- Mỗi lần đổi trạng thái tạo đúng 1 thông báo gửi `accountId`, id cố định `${appointmentId}_${status}`, `type` là `appointment_confirmed` hoặc `appointment_rejected` (`refId` là id lịch); hoàn tất tạo `visit_result` (`refId` là visitId).

### Đặt lịch từ đề xuất tái khám (`followUpId`, A08)

- Follow-up phải có thật, đúng `patientId`, cùng tài khoản (nếu có `accountId`) và còn `suggested` hoặc `scheduled` (dữ liệu cũ); có `serviceId` thì lịch phải gồm dịch vụ đó.
- Cùng transaction giữ chỗ: lịch lưu `followUpId`, follow-up chuyển `booked` kèm `appointmentId`. Đặt lần nữa trả 409.
- Lịch bị hủy hoặc từ chối: follow-up về `suggested`; lịch hoàn tất: follow-up `completed`.
- `followUpId` nằm trong dấu vân tay Idempotency-Key.

### Nhắc lịch tự động (`src/jobs/reminders.js`, A03)

- Server chạy job khi khởi động và mỗi 10 phút (test không nạp `server.js` nên không chạy). Staff chạy ngay bằng `POST /api/notifications/run-reminders`.
- `appointment_reminder`: appointment `confirmed` trong cửa sổ 24 giờ; ID `{appointmentId}_{YYYY-MM-DD}_{HH:mm}`. Giữ transaction/chống trùng AUD-05 và inbox visibility AUD-08; không thêm mốc 1 giờ/2 giờ trong thay đổi này.
- `follow_up_reminder` (AUD-07, khôi phục 02/11/2026): đề xuất tái khám `suggested` (hoặc `scheduled` dữ liệu cũ) có `scheduledAt` trong 3 ngày tới; ID `furemind_{followUpId}_{YYYY-MM-DD}` (ngày giờ Việt Nam), `refId` là id đề xuất. Thiếu `accountId` thì bỏ qua. Khác với thông báo `follow_up` tạo ngay khi staff đề xuất.
- Response `run-reminders`: `{ created, followUpReminders }` (số nhắc lịch hẹn, số nhắc tái khám vừa tạo). Chưa có mốc nhắc 2 giờ trước giờ khám.
- Mỗi nhắc tạo trong transaction đọc lại trạng thái, giờ, `notificationsEnabled` của tài khoản; đã có thì bỏ qua. Hủy hoặc từ chối lịch xóa nhắc đã gửi. `GET /api/notifications` không tạo thông báo.

### Ghi chú lịch hẹn (`note`)

- Chuỗi, bỏ khoảng trắng hai đầu, tối đa 500 ký tự, cho phép rỗng. Không gửi hoặc `null` thì lưu `""`. Sai kiểu hoặc quá dài trả **400**.
- Lưu trong lịch, trả về ở `GET /api/appointments`, `GET /:id` và `GET /staff`.

### Chống tạo trùng (`Idempotency-Key`)

- App sinh một UUID cho mỗi lần xác nhận đặt lịch, gửi qua header `Idempotency-Key`; bấm lại hoặc gửi lại do lỗi mạng dùng đúng key đó, sửa lựa chọn thì đổi key.
- Key hợp lệ: 8 đến 100 ký tự chữ, số, `-`, `_`. Sai trả **400**. Không gửi key thì chạy như cũ.
- Backend lưu `appointment_requests/{uid}_{key}` = `{ accountId, key, appointmentId, fingerprint, createdAt }` trong **cùng transaction** tạo lịch. `fingerprint` là SHA-256 của người khám, ngày, giờ, bác sĩ, dịch vụ, combo, voucher, ghi chú.
- Gửi lại cùng key, cùng nội dung: trả **201** đúng lịch đã tạo (cùng `id`), không tạo thêm lịch, thông báo, lượt voucher. Kiểm tra cả trước transaction (vì slot đang bị chính lịch đó giữ) và đầu transaction (hai lần gửi đồng thời thì lần thua được chạy lại và nhận lịch của lần thắng).
- Cùng key, khác nội dung: **409** "Mã yêu cầu đã dùng cho một lịch khác".
- Tạo lịch thất bại thì không ghi `appointment_requests`; gửi lại cùng key sau khi sửa được lỗi vẫn tạo được.
- App: gửi bị mất kết nối/hết thời gian chờ thì khóa mọi lựa chọn, chỉ cho "Thử lại" (key cũ) hoặc "Chọn lại" (tải lại lịch; đã có lịch cùng người khám, ngày, giờ thì báo thành công và mở lịch đó; chưa có thì mở khóa, lần gửi sau dùng key mới).

### Quyền nhân viên (staff)

- Dùng Firebase custom claims. Một chính sách chung ở `src/utils/staff.js` (`isStaff`, AUD-14): là staff khi `role` là `"staff"` hoặc `"admin"`, hoặc `staff: true` / `admin: true`. Middleware `src/middleware/requireStaff.js` (đặt sau `auth`) trả **403** nếu không phải staff; các route cho phép "chủ tài khoản hoặc staff" cũng dùng `isStaff`.
- Gán: `node scripts/set-staff.js staff@nhakhoa.com`. Gỡ: thêm `--remove`. Người được gán/gỡ phải **đăng nhập lại** để token có quyền mới.

### Lịch làm việc bác sĩ

- `node scripts/seed-schedules.js` chạy thử: **có đọc Firestore** (bác sĩ và ca đã có) để in số ca sẽ tạo, số ca bỏ qua và vài id mẫu, **không ghi gì**. Thêm `--apply` để ghi.
- Tạo ca cho mọi bác sĩ đang hoạt động, từ hôm nay tới 30 ngày sau, thứ 2 đến thứ 7: ca sáng 08:00 đến 12:00, ca chiều 13:30 đến 17:30, slot 30 phút. Id `${doctorId}_${YYYY-MM-DD}_am` / `_pm`.
- "Hôm nay", ngày trong id và giờ ca đều tính **theo giờ Việt Nam (UTC+7)**, không phụ thuộc múi giờ của máy chạy (bản cũ dùng `toISOString()` nên id bị lùi 1 ngày). Chạy lúc 06:00 sáng giờ Việt Nam vẫn bắt đầu từ đúng ngày hôm đó (có test `test/seed-schedules.test.cjs`).
- Không xóa, không ghi đè: id đã có thì bỏ qua; **bác sĩ đã có ca bất kỳ trong ngày (theo giờ Việt Nam) thì bỏ qua cả ngày đó**; ghi bằng `create` nên không bao giờ đè ca có sẵn. Chạy lại nhiều lần không tạo trùng. **Chạy lại sáng hôm demo** để có lịch cho các ngày mới.
- `loadSchedulingData(date)` chỉ đọc ca có `startAt` trong ngày đang hỏi (giờ Việt Nam) và lịch hẹn, slot có `date` bằng ngày đó. Ca lỗi định dạng bị bỏ qua kèm `console.warn`, không làm hỏng việc đặt lịch.

### Quy ước Module 2

- Báo giá luôn đọc `price`, `durationMinutes` từ `services`/`combos`; không tin giá do client gửi. Khi chọn combo kèm các dịch vụ đã nằm trong combo, các dịch vụ đó không bị tính phí/thời lượng lần hai. `totalPrice` là số tiền sau giảm giá, `subtotal` là trước giảm giá, `discount` là số tiền được giảm.
- `doctor_schedules` dùng `doctorId`, `startAt`, `endAt`, `slotMinutes`, `isAvailable`. `startAt`/`endAt` là thời điểm Firestore; hệ thống diễn giải theo múi giờ Việt Nam (`Asia/Ho_Chi_Minh`). Mỗi document là một ca/ngày cụ thể, không tự lặp theo tuần.
- Lịch hẹn lưu `accountId`, `patientId`, `doctorId`, `serviceIds`, `comboId`, `date` (`YYYY-MM-DD`), `startTime`/`endTime` (`HH:mm`), `totalPrice`, `discount`, `voucherCode`, `status: "booked"`, `createdAt` (Timestamp). Lịch cho người thân phải tham chiếu một document trong `users/{accountId}/family_members` chưa bị xóa (`isArchived`); bước kiểm tra người khám chạy trước mọi bước kiểm tra dịch vụ, lịch làm việc, khung giờ.
- Test tự động: chạy bằng `npm test` (xem mục "Chạy test backend"). Firestore giả dùng chung ở `test/module2/support/fakeFirestore.cjs`, có mô phỏng xung đột transaction.
- Việc tạo lịch dùng Firestore Transaction và collection nội bộ `appointment_slots` để giữ từng đoạn thời gian 15 phút; lịch đã hủy sẽ giải phóng slot. Khi dùng voucher, `usedCount` được tăng trong cùng transaction với đặt lịch.
- Notification mới có các trường `userId`, `title`, `body`, `type`, `refId`, `isRead`, `createdAt` theo quy ước ở README gốc.
- Request test nằm ở mục **MODULE 2** trong `backend/api-test.http`; token và id lịch lấy tự động từ response, chỉ cần chỉnh ngày (`@a01Date`, `@a11Date`) vào ngày đã có lịch làm việc.

## Script (`backend/scripts/`)

| Script | Việc | Ghi Firestore? |
|---|---|---|
| `preflight-demo.js` | Kiểm tra trước demo: `.env`, khóa Firebase, quyền staff, ca bác sĩ 7 ngày tới, dịch vụ và combo có bác sĩ làm được, thời lượng combo, voucher dùng được. In bảng OK / CẢNH BÁO / LỖI, có LỖI thì mã thoát 1 | **Không**, chỉ đọc |
| `e2e-smoke.js` | Chạy thật toàn luồng qua API `localhost:3000` bằng test123 và staff, in PASS / FAIL / BỎ QUA từng bước, cuối script tự xóa đúng các id đã tạo | Có, rồi tự dọn |
| `seed-schedules.js [--apply]` | Tạo ca làm việc bác sĩ (xem mục "Lịch làm việc bác sĩ") | Chỉ khi `--apply` |
| `cleanup-test-data.js <email> [--apply] [--keep-profile]` | Xóa dữ liệu nghiệp vụ của một tài khoản test | Chỉ khi `--apply` |
| `seed-demo.js <email> [--apply]` | Tạo dữ liệu demo cho một tài khoản (không xóa dữ liệu có sẵn, dùng `writeCompletion` để tạo hai hồ sơ khám) | Chỉ khi `--apply` |
| `set-staff.js <email> [--remove]` | Gán hoặc gỡ quyền staff | Ghi ngay (custom claims) |

```bash
cd backend
node scripts/preflight-demo.js
node scripts/e2e-smoke.js            # backend phải đang chạy (npm start)
```

- `preflight-demo.js`: chạy sáng hôm demo sau `seed-schedules.js --apply`, và sau mỗi lần sửa danh mục, bác sĩ, voucher.
- `e2e-smoke.js`: chạy tối trước hoặc sáng hôm demo, **không chạy trong lúc demo**. Mật khẩu đọc từ `backend/.env` (`TEST_PASSWORD`, `STAFF_PASSWORD`), không in ra. Không dùng voucher, không gửi `Idempotency-Key`. Bước nhắc lịch cần giờ trống trong 24 giờ tới, không có thì BỎ QUA. Dọn dẹp chạy cả khi có bước FAIL, chỉ xóa document do script tạo và thuộc test123; dọn lỗi thì in danh sách id để xóa tay. Lần chạy ngày 02/11/2026: 14 PASS, 0 FAIL, 0 BỎ QUA, xóa 20 bản ghi, không còn sót.
- Cleanup chỉ xử lý dữ liệu nghiệp vụ của email, không xóa `services`, `combos`, `doctors`, `articles`, `vouchers` hoặc `doctor_schedules`; `--keep-profile` giữ hồ sơ và người thân. Chỉ thêm `--apply` sau khi xác nhận đúng project và tài khoản.

## Chạy test backend

- Cần **Node.js 24** (`node --version` phải là `v24.x`). Phiên bản khác: trình chạy test dừng ngay với lỗi `AUD-12: fake test launcher requires Node 24.x.`
- Lệnh:

```bash
cd backend
npm test
```

- `npm test` chạy `test/support/run-fake-tests.cjs`: tự tìm mọi file `*.test.js` / `*.test.cjs` trong `test/` (trừ thư mục `support`), nạp trước `test/support/fake-isolation.cjs` để **chặn** Firebase Admin thật, `serviceAccountKey.json`, `.env`, `server.js` và mạng ngoài localhost. Test chỉ dùng Firestore giả, không cần khóa Firebase. Kết quả ngày 02/11/2026: 670 đạt, 0 lỗi.
- Thêm file test mới thì cập nhật danh sách trong `test/discovery.test.cjs`.

Frontend dùng `flutter analyze`, `flutter test` và `flutter test --dart-define=DATA_SOURCE=api` (xem README gốc).
