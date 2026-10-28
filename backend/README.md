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

Khi test bằng `api-test.http`: bật server, bấm request **1. Đăng nhập** trước để có `{{token}}`, sau đó mới bấm các request khác.

## API Module 1 - Tài khoản và dữ liệu cơ bản

| Method | Endpoint                  | Đăng nhập | Mô tả |
|--------|---------------------------|-----------|-------|
| POST   | /api/users/sync           | Có  | Tạo hồ sơ nếu chưa có. Body: `{ fullName, phone }` |
| GET    | /api/users/me             | Có  | Xem hồ sơ của mình |
| PATCH  | /api/users/me             | Có  | Sửa `fullName`, `phone`, `birthday`, `address`, giới tính và thông tin sức khỏe (xem bên dưới) |
| GET    | /api/family-members       | Có  | Danh sách người thân |
| POST   | /api/family-members       | Có  | Thêm người thân. Bắt buộc `fullName`; nhận thêm giới tính và thông tin sức khỏe |
| PATCH  | /api/family-members/:id   | Có  | Sửa người thân (gồm cả giới tính và thông tin sức khỏe) |
| DELETE | /api/family-members/:id   | Có  | Xóa người thân |
| GET    | /api/services             | Không | Danh sách dịch vụ |
| GET    | /api/services/:id         | Không | Chi tiết dịch vụ |
| GET    | /api/combos               | Không | Danh sách combo |
| GET    | /api/combos/:id           | Không | Chi tiết combo |
| GET    | /api/doctors              | Không | Danh sách bác sĩ |
| GET    | /api/doctors/:id          | Không | Chi tiết bác sĩ |
| GET    | /api/favorites            | Có  | Danh sách nội dung đã lưu |
| POST   | /api/favorites            | Có  | Lưu nội dung. Body: `{ type, itemId }` |
| DELETE | /api/favorites/:id        | Có  | Bỏ lưu một mục |

### Dữ liệu `users/{uid}` và `users/{uid}/family_members/{id}`

| Trường | Kiểu | Có ở | Ghi chú |
|---|---|---|---|
| `fullName` | chuỗi | cả hai | |
| `phone` | chuỗi | cả hai | |
| `birthday` | chuỗi `"YYYY-MM-DD"` | cả hai | `""` nếu chưa có |
| `email` | chuỗi | users | Email đăng nhập Firebase, không sửa qua API |
| `address` | chuỗi | users | |
| `relationship` | chuỗi | family_members | Ví dụ "Mẹ", "Con" |
| `gender` | `"male"` \| `"female"` \| `"other"` \| `""` | cả hai | `""` là chưa chọn. Giá trị khác trả 400 |
| `allergies` | chuỗi, tối đa 500 ký tự | cả hai | Dị ứng thuốc, ví dụ `"Penicillin, Lidocaine"` |
| `medicalConditions` | mảng chuỗi | cả hai | Chỉ nhận: `diabetes` (tiểu đường), `heart_disease` (bệnh tim mạch), `hypertension` (huyết áp cao), `bleeding_disorder` (rối loạn đông máu), `asthma` (hen suyễn), `hepatitis` (viêm gan), `other` (khác). Giá trị lạ trả 400 |
| `currentMedications` | chuỗi, tối đa 500 ký tự | cả hai | Thuốc đang dùng |
| `isPregnant` | `true` \| `false` | cả hai | Phải là boolean, chuỗi `"true"` trả 400 |
| `healthNotes` | chuỗi, tối đa 500 ký tự | cả hai | Ghi chú khác |
| `createdAt` | Timestamp | cả hai | |

- Kiểm tra giới tính và sức khỏe dùng chung ở `src/utils/health.js` (`readHealth`).
- Khi GET, trường còn thiếu (dữ liệu cũ) được trả giá trị mặc định: `""`, `[]` hoặc `false` (`withHealthDefaults`).
- PATCH chỉ đổi những trường có gửi lên; POST người thân thiếu trường thì lưu mặc định.

### Ghi chú về isActive

- API danh sách (`GET /api/services`, `/api/combos`, `/api/doctors`) ẩn mục có `isActive: false`. Mục không có trường `isActive` coi như đang bật.
- API chi tiết (`GET /:id`) vẫn trả mục đã tắt, để xem lại được từ danh sách yêu thích hoặc lịch sử.

### Ghi chú về favorites

- Không lưu được mục có `isActive: false` (trả 400).

- `type` là một trong: `service`, `combo`, `doctor`, `article`. `itemId` là id document trong collection tương ứng (`services`, `combos`, `doctors`, `articles`).
- Id của mục đã lưu là `${type}_${itemId}`, ví dụ `service_svc_01`. Lưu cùng một món nhiều lần vẫn chỉ có 1 mục.
- Muốn bỏ lưu thì gọi `DELETE /api/favorites/service_svc_01`.

## Module khác

Module 2 (đặt lịch), Module 3 (hồ sơ nha khoa), Module 4 (nội dung và thông báo): người phụ trách bổ sung bảng API của mình vào đây khi viết xong.

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
| POST | `/api/treatments/:id/sessions/link-visit` | Có | Gắn một lần khám đã hoàn thành vào buổi do người dùng chọn. Body: `{ visitId, sessionId }` |
| GET | `/api/treatments/:id/photos` | Có | Ảnh trước và sau; trả mảng rỗng nếu chưa có ảnh |
| GET | `/api/patients/:id/follow-ups` | Có | Lịch tái khám |

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
| POST | `/api/appointments` | Có | Tạo lịch cho bản thân hoặc người thân; `doctorId` có thể bỏ trống để chọn ngẫu nhiên; body có `patientId?`, `serviceIds?`, `comboId?`, `date`, `startTime`, `voucherCode?` |
| GET | `/api/appointments` | Có | Lịch của tài khoản đang đăng nhập, bao gồm lịch đặt cho người thân |
| GET | `/api/appointments/:id` | Có | Chi tiết lịch; chỉ chủ tài khoản được xem |
| PATCH | `/api/appointments/:id/cancel` | Có | Hủy lịch tương lai và giải phóng các slot đã giữ |

### Quy ước Module 2

- Báo giá luôn đọc `price`, `durationMinutes` từ `services`/`combos`; không tin giá do client gửi. Khi chọn combo kèm các dịch vụ đã nằm trong combo, các dịch vụ đó không bị tính phí/thời lượng lần hai. `totalPrice` là số tiền sau giảm giá, `subtotal` là trước giảm giá, `discount` là số tiền được giảm.
- `doctor_schedules` dùng `doctorId`, `startAt`, `endAt`, `slotMinutes`, `isAvailable`. `startAt`/`endAt` là thời điểm Firestore; hệ thống diễn giải theo múi giờ Việt Nam (`Asia/Ho_Chi_Minh`). Mỗi document là một ca/ngày cụ thể, không tự lặp theo tuần.
- Lịch hẹn lưu `accountId`, `patientId`, `doctorId`, `serviceIds`, `comboId`, `date` (`YYYY-MM-DD`), `startTime`/`endTime` (`HH:mm`), `totalPrice`, `discount`, `voucherCode`, `status: "booked"`, `createdAt` (Timestamp). Lịch cho người thân phải tham chiếu một document trong `users/{accountId}/family_members`.
- Việc tạo lịch dùng Firestore Transaction và collection nội bộ `appointment_slots` để giữ từng đoạn thời gian 15 phút; lịch đã hủy sẽ giải phóng slot. Khi dùng voucher, `usedCount` được tăng trong cùng transaction với đặt lịch.
- Notification mới có các trường `userId`, `title`, `body`, `type`, `refId`, `isRead`, `createdAt` theo quy ước ở README gốc.
- Request test nằm tại `backend/api-test.http`; trước khi chạy, thay token Firebase, ngày/giờ và mã bác sĩ theo dữ liệu thật trong Firestore.
