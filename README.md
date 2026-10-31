# 🦷 MediCare Dental, ứng dụng nha khoa cho bệnh nhân

```
App Flutter (frontend/)  ──HTTP + token──▶  Backend Node.js (backend/)  ──▶  Firebase (Authentication + Firestore)
```

Hướng dẫn chi tiết cách viết API: [`backend/README.md`](backend/README.md)

---

# 1. Tình hình hiện tại

| Module | Người | Ngày | Trạng thái |
|---|---|---|---|
| Firebase + dữ liệu mẫu | Phương | 21 đến 23/10 | ✅ Xong |
| Màn hình Flutter (dữ liệu mẫu) | Nhi | 21 đến 23/10 | ✅ Xong |
| **Module 1**: Tài khoản và dữ liệu cơ bản | Bình | 24/10 | ✅ **Xong** |
| **Module 2**: Đặt lịch nha khoa | Phương (Bình sửa theo audit) | 25/10 đến 31/10 | ✅ **Xong phần chính**, còn A08 |
| **Module 3**: Hồ sơ nha khoa | Ngân | 27 đến 28/10 | ⏳ Chưa làm |
| **Module 4**: Nội dung và thông báo | Nhi | 29 đến 31/10 | ⏳ Chưa làm |
| Hoàn thiện UI/UX, kiểm thử, slide | Ngân + cả nhóm | 01 đến 02/11 | ⏳ |

## ✅ Module 1 đã xong những gì

| Chức năng | Trên app | API | Trạng thái |
|---|---|---|---|
| Đăng ký, đăng nhập, quên mật khẩu, đăng xuất, tự đăng nhập khi mở lại app (Firebase thật, báo lỗi tiếng Việt) | ✅ | Không cần | Xong |
| Đổi mật khẩu (xác thực lại bằng mật khẩu hiện tại) | ✅ | Không cần | Xong |
| Xác minh email: gửi thư khi đăng ký, nhắc ở tab "Tôi", gửi lại (chờ 60 giây), không chặn dùng app | ✅ | Không cần | Xong |
| Hồ sơ cá nhân: xem, sửa; giới tính, thông tin sức khỏe (dị ứng, bệnh nền, thuốc đang dùng, mang thai, ghi chú), nhãn "⚠ Có lưu ý sức khỏe" | ✅ | `/api/users/me` | Xong |
| Kiểm tra dữ liệu hồ sơ (A17): họ tên, số điện thoại 9 đến 11 số, ngày sinh có thật và không ở tương lai; **ngày sinh không bắt buộc**; số điện thoại tự chuẩn hóa (`+84`, dấu cách, dấu chấm) | ✅ | `/api/users/me`, `/api/family-members` | Xong |
| Người thân: xem, thêm, sửa, cùng giới tính và thông tin sức khỏe | ✅ | `/api/family-members` | Xong |
| Xóa người thân là **xóa mềm** (A05): giữ hồ sơ cũ, không đặt lịch mới được; **chặn xóa** khi còn lịch sắp tới (409) | ✅ | `DELETE /api/family-members/:id` | Xong |
| Thêm/sửa/xóa người thân tự đồng bộ sang Đặt lịch và Hồ sơ (A04) | ✅ | Không cần | Xong |
| Dịch vụ, combo, bác sĩ: trang chủ, danh sách, chi tiết; tìm kiếm không dấu, lọc, sắp xếp theo giá; lọc bác sĩ theo chuyên khoa | ✅ | `/api/services`, `/api/combos`, `/api/doctors` | Xong |
| "Bác sĩ thực hiện" ở chi tiết dịch vụ; combo **chỉ hiện bác sĩ làm đủ mọi dịch vụ** của combo | ✅ | `/api/doctors` (`serviceIds`) | Xong |
| Nút "Đặt lịch với bác sĩ này / dịch vụ này / combo này" mở Đặt lịch chọn sẵn | ✅ | Không cần | Xong |
| Đã lưu: lưu/bỏ lưu dịch vụ, combo, bác sĩ, bài viết; màn hình "Đã lưu" có tab lọc | ✅ | `/api/favorites` | Xong |
| Cài đặt "Ngôn ngữ", "Nhận thông báo" **lưu trên máy** (A18, có ghi rõ trên màn hình); màn hình Quyền riêng tư | ✅ | Không cần | Xong |
| `DATA_SOURCE` mặc định `api` (dữ liệu thật); `--dart-define=DATA_SOURCE=mock` để xem dữ liệu giả | ✅ | | Xong |
| File gọi API dùng chung, tự gắn token: `frontend/lib/data/api_client.dart` | ✅ | | Xong |

## ✅ Module 2 đã xong những gì

| Chức năng | Trên app | API | Trạng thái |
|---|---|---|---|
| Báo giá dịch vụ/combo (giá đọc từ Firestore, không tin giá client gửi) | ✅ | `POST /api/bookings/quote` | Xong |
| Voucher: kiểm tra hạn, lượt, đơn tối thiểu; trừ lượt trong cùng transaction đặt lịch | ✅ | `POST /api/vouchers/validate` | Xong |
| Giờ trống theo ngày, chỉ đọc lịch của đúng ngày đó; ca lỗi bị bỏ qua, không làm hỏng cả ngày (A20) | ✅ | `GET /api/availability` | Xong |
| Lịch làm việc bác sĩ tạo bằng script `backend/scripts/seed-schedules.js` (thứ 2 đến thứ 7, 08:00 đến 12:00 và 13:30 đến 17:30) | | Script | Xong |
| Đặt lịch cho bản thân/người thân, chọn hoặc để trống bác sĩ; **giữ slot 15 phút trong transaction** nên hai người không đặt trùng | ✅ | `POST /api/appointments` | Xong |
| Ghi chú cho phòng khám, tối đa 500 ký tự (A13) | ✅ | `note` | Xong |
| Chống tạo trùng bằng `Idempotency-Key` (A11): mất mạng thì khóa lựa chọn, chỉ cho **Thử lại** (gửi lại không tạo trùng) hoặc **Chọn lại** (kiểm tra lịch đã tạo chưa) | ✅ | header `Idempotency-Key` | Xong |
| Danh sách, chi tiết, hủy lịch; ô "Lịch hẹn sắp tới" ở trang chủ | ✅ | `GET /api/appointments`, `GET /:id`, `PATCH /:id/cancel` | Xong |
| Trạng thái thống nhất 5 giá trị, trạng thái lạ hiện "Không xác định" (A14) | ✅ | | Xong |
| Nhân viên xác nhận / từ chối (bắt buộc lý do) / hoàn tất lịch, mỗi lần đổi tạo 1 thông báo cho bệnh nhân (A01) | Thông báo ✅ | `PATCH /:id/status`, `GET /api/appointments/staff` | Xong |
| Chi tiết lịch luôn tải lại từ máy chủ; danh sách kéo để tải lại, tự tải lại khi vào tab Hồ sơ (A07) | ✅ | | Xong |
| Test backend (A12): 87 test, trong đó 33 test Module 2 (đặt lịch, trùng giờ, đặt đồng thời, voucher, hủy, từ chối, chống tạo trùng) chạy trên Firestore giả | | | Xong |

**Trạng thái lịch hẹn:** `booked` (Chờ xác nhận), `confirmed` (Đã xác nhận), `rejected` (Bị từ chối), `cancelled` (Đã hủy), `completed` (Đã hoàn tất).

| Từ | Được chuyển sang |
|---|---|
| `booked` | `confirmed`, `rejected`, `cancelled` |
| `confirmed` | `completed`, `cancelled` |

Chuyển khác trả 409. Bệnh nhân chỉ hủy được (`booked`/`confirmed` → `cancelled`); xác nhận, từ chối, hoàn tất là việc của nhân viên.

**Quy tắc đặt lịch:** đặt là **giữ chỗ ngay**, lịch đang chờ xác nhận đã khóa khung giờ đó. Bị từ chối hoặc bị hủy thì khung giờ được trả lại và voucher (nếu có) được trả lượt.

**Chạy test backend:**
```powershell
cd backend
node --test test/module2/*.test.cjs test/module3/*.cjs test/module4/*.cjs
```

## 👩‍⚕️ Cách dùng tài khoản nhân viên (staff)

1. Tạo user trên Firebase Console → **Authentication** → **Add user**.
2. Gán quyền:
   ```powershell
   cd backend
   node scripts/set-staff.js <email>            # gán quyền staff
   node scripts/set-staff.js <email> --remove   # gỡ quyền
   ```
3. Tài khoản đó **đăng nhập lại** thì mới có quyền.
4. Xác nhận, từ chối, hoàn tất lịch bằng các request **A01** trong `backend/api-test.http` (đăng nhập staff ở mục ĐĂNG NHẬP; mật khẩu staff đặt ở `STAFF_PASSWORD` trong `backend/.env`, xem mục 3.4).

## 📋 Việc cần làm trước hôm demo

| Việc | Cách làm |
|---|---|
| Bổ sung lịch làm việc bác sĩ (script tạo tới 30 ngày sau ngày chạy) | `cd backend` → `node scripts/seed-schedules.js` (xem thử) → `node scripts/seed-schedules.js --apply`. Không ghi đè, không xóa lịch cũ |
| Dọn lịch test, người thân test của tài khoản demo | Hủy lịch test trên app; xóa người thân tên "test" |
| Sửa dữ liệu mẫu cho hợp lý | Ví dụ ngày sinh người thân, tên, số điện thoại |

## ⏳ Chưa xong và cách giải quyết

| Mã | Vấn đề | Ai | Cách giải quyết | Ưu tiên |
|---|---|---|---|---|
| A08 | Lịch tái khám chưa liên kết với lịch đặt | Ngân + Phương, Nhi | Ngân và Phương chốt `followUpId` và trạng thái tái khám, Phương thêm vào đặt lịch, Nhi hiển thị. Không kịp thì demo vẫn chạy (đặt như lịch thường) | Cao |
| A02, A03 | Thông báo xác nhận và nhắc lịch | Nhi | Đã có thông báo `appointment_confirmed` / `rejected` / `completed`. Nhi làm tiếp nhắc lịch dựa trên lịch `confirmed` | Trung bình |
| A15 | App tính giờ lịch hẹn theo múi giờ thiết bị, chỉ đúng khi thiết bị để giờ Việt Nam | | Để sau demo | Thấp |
| | 52 test Flutter lỗi sẵn khi chạy `flutter test --dart-define=DATA_SOURCE=api` (test thiếu provider giả, không ảnh hưởng app) | | Bổ sung provider giả vào các test đó | Thấp |
| | Hồ sơ cũ của người thân đã xóa không xem được trên app (chỉ xem qua API) | | Đã chọn để vậy | |
| A06, A09, A10, A16, A19, A21... | Các mục audit còn lại của Module 3, 4 | Ngân (Module 3), Nhi (Module 4) | Xem chi tiết và người phụ trách từng mục trong báo cáo audit | |
| | Dữ liệu giả trong `frontend/lib/data/mock_data.dart` (`patient-001`, "Nguyễn Hải Nam"...) | | Chỉ dùng khi `DATA_SOURCE=mock`, không ảnh hưởng dữ liệu thật | |

## 🔑 Mã thật dùng thay mã giả

| Là gì | Mã thật | Mã giả trong app |
|---|---|---|
| Bản thân người dùng | **UID Firebase** của người đăng nhập | `patient-001` |
| Người thân | id trong `users/{uid}/family_members` | `patient-002` |
| Dịch vụ / Combo / Bác sĩ / Bài viết | `svc_01` / `combo_01` / `doc_01` / `article_01` | `service-checkup`, `article-brushing`... |

## 📌 Quy ước chung cho Module 2, 3, 4
- **Lịch hẹn, hồ sơ khám** lưu `accountId` (UID người đặt/chủ tài khoản) và `patientId` (UID bản thân hoặc id người thân).
- **Thông báo** (`notifications`): Phương tạo khi đặt/hủy lịch, Nhi đọc ra. Cấu trúc thống nhất:
  `{ userId, title, body, type ("appointment_booked" | "appointment_cancelled" | "follow_up" | ...), refId, isRead: false, createdAt }`
- Tên trường kiểu `camelCase`, tiền là số nguyên VND, mục ẩn dùng `isActive: false`.
- Ngày giờ:
  - Thời điểm xảy ra (`createdAt`, `publishedAt`...) lưu **Timestamp**.
  - Ngày không có giờ (`birthday`, `date` của lịch hẹn...) lưu chuỗi **`"YYYY-MM-DD"`**.
  - Giờ trong ngày (`startTime`, `endTime` của lịch hẹn) lưu chuỗi **`"HH:mm"`**.
- **Firestore Rules** đang là `allow read, write: if false` cho toàn bộ database: không đọc/ghi Firestore trực tiếp từ Flutter (không dùng `cloud_firestore`), mọi dữ liệu đi qua API backend (`lib/data/api_client.dart`). **Không sửa Rules.**

---
## ✅ Module 3 đã hoàn thành: Hồ sơ nha khoa

Module 3 phụ trách hồ sơ nha khoa chỉ đọc và các chức năng liên kết lịch hẹn, lần khám, đơn thuốc, hóa đơn và liệu trình điều trị.

### Backend đã hoàn thành

Đã triển khai các API hồ sơ nha khoa trong `backend/src/routes/`:

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/api/patients/:id/visits` | Lịch sử các lần khám của bản thân hoặc người thân |
| GET | `/api/visits/:id` | Chi tiết lần khám, kết quả và chẩn đoán |
| GET | `/api/visits/:id/prescriptions` | Đơn thuốc của lần khám |
| GET | `/api/patients/:id/invoices` | Danh sách hóa đơn |
| GET | `/api/invoices/:id` | Chi tiết hóa đơn |
| GET | `/api/patients/:id/treatments` | Danh sách liệu trình điều trị |
| GET | `/api/treatments/:id` | Chi tiết và tiến độ liệu trình |
| GET | `/api/treatments/:id/sessions` | Danh sách các buổi điều trị |
| GET | `/api/treatments/:id/photos` | Ảnh trước và sau điều trị |
| GET | `/api/patients/:id/follow-ups` | Lịch tái khám |
| POST | `/api/treatments/:id/sessions/link-visit` | Gắn một lần khám vào buổi điều trị do người dùng chọn |

🐕🐕🐕 Đã thêm các chức năng nho nhỏ: 
  + Link lịch đã khám với liệu trình khám, cho khách hàng tự organize liệu trình của mình.
  + Lịch tái khám khi bấm đặt lịch sẽ hiện đúng dịch vụ cần tái khám chứ không cần khách tự chọn dịch vụ để đặt lại từ đầu.
  + Liệu trình có thể xem được kết quả của buổi khám và đơn thuốc được bác sĩ kê.


# 2. Prompt cho Claude trong VS Code

Mỗi người copy **nguyên khung của mình**, mở Claude trong VS Code, bấm **New chat** rồi dán vào. Trước khi để Claude sửa: `git pull` và commit một mốc an toàn (mục 3).

## 👩‍💻 Phương: Module 2, Đặt lịch nha khoa

```
Bối cảnh: app Flutter nha khoa "MediCare Dental" cho bệnh nhân, nhóm 4 người, làm thẳng trên nhánh main. Frontend Flutter trong frontend/, backend Node.js + Express + firebase-admin v14 trong backend/, dữ liệu ở Firestore project yoursmile-49379.

Đọc trước: README.md ở thư mục gốc (mục quy ước và mã thật), backend/README.md (khuôn viết API). Module 1 đã xong, dùng làm mẫu: backend/src/routes/users.js, familyMembers.js, favorites.js; frontend lib/data/api_client.dart (biến api tự gắn token), lib/data/services/catalog_service.dart, lib/providers/catalog_provider.dart, lib/providers/profile_provider.dart.

Tôi là Phương, làm Module 2: Đặt lịch nha khoa. Làm theo 2 giai đoạn, xong giai đoạn 1 thì DỪNG để tôi test.

GIAI ĐOẠN 1: Backend, viết vào các file khung có sẵn trong backend/src/routes/: bookings.js, availability.js, vouchers.js, appointments.js
- POST /api/bookings/quote: nhận danh sách serviceIds và/hoặc comboId, trả tổng tiền và tổng thời gian khám (cộng price, durationMinutes). Có voucherCode thì tính luôn giảm giá.
- GET /api/availability?date=YYYY-MM-DD&doctorId=...&durationMinutes=...: trả các khung giờ còn trống, dựa trên doctor_schedules và các lịch hẹn đã có. Không truyền doctorId thì gộp tất cả bác sĩ. Nhận thêm comboId (tùy chọn): có comboId thì chỉ xét bác sĩ làm được đủ TẤT CẢ dịch vụ của combo (serviceIds của bác sĩ chứa toàn bộ serviceIds của combo, giống CatalogProvider.doctorsFor ở frontend); doctorId truyền vào không đủ điều kiện thì trả 400.
- POST /api/vouchers/validate: kiểm tra mã còn hạn, còn lượt, đủ điều kiện, trả số tiền giảm.
- POST /api/appointments: tạo lịch hẹn. Cho phép đặt cho bản thân (patientId = UID) hoặc người thân (patientId phải là id trong users/{uid}/family_members của chính người đặt). Cho phép chọn bác sĩ hoặc để trống (chọn ngẫu nhiên bác sĩ còn trống). Đặt combo: bác sĩ được chọn (kể cả chọn ngẫu nhiên) phải làm được đủ TẤT CẢ dịch vụ của combo, giống quy tắc CatalogProvider.doctorsFor; chọn bác sĩ không đủ điều kiện thì trả 400. BẮT BUỘC dùng Firestore Transaction với cơ chế giữ slot để hai người không đặt trùng một bác sĩ một khung giờ. Lưu accountId, patientId, doctorId, serviceIds, comboId, date (chuỗi "YYYY-MM-DD"), startTime, endTime (chuỗi "HH:mm"), totalPrice, discount, voucherCode, status "booked", createdAt (Timestamp). Tạo thêm 1 thông báo vào notifications theo cấu trúc trong README gốc.
- GET /api/appointments (lịch của tài khoản đang đăng nhập, gồm cả lịch của người thân), GET /api/appointments/:id (chỉ chủ tài khoản xem được, người khác trả 403).
- PATCH /api/appointments/:id/cancel: chỉ chủ tài khoản, chỉ hủy được lịch chưa diễn ra, giải phóng slot, tạo thông báo hủy.
Trước khi viết: tạo script tạm CHỈ ĐỌC 1 document mẫu của doctor_schedules, vouchers, services, combos, doctors để biết đúng tên trường, chạy xong thì xóa script. Nếu dữ liệu mẫu thiếu trường cần thiết thì báo tôi, đừng tự sửa Firestore. Không sửa server.js, auth.js, firebase.js và file của module khác. Thêm request test (cả trường hợp đúng và lỗi: trùng giờ, voucher sai, xem lịch người khác) vào cuối backend/api-test.http.

GIAI ĐOẠN 2: Frontend, nối các màn hình đặt lịch với API:
- Ô "Người khám" lấy từ ProfileProvider (bản thân + người thân thật), bỏ "Nguyễn Hải Nam" giả.
- Chọn dịch vụ, combo, bác sĩ lấy từ CatalogProvider (dữ liệu thật).
- Màn hình đặt lịch nhận giá trị chọn sẵn (tùy chọn) doctorId, serviceIds, comboId (mã thật), và có 1 hàm dùng chung để mở đặt lịch, ví dụ openBooking(doctorId: ..., serviceIds: ..., comboId: ...), để Bình gắn nút "Đặt lịch với bác sĩ này" ở chi tiết bác sĩ, dịch vụ, combo.
- Đặt lịch combo: chỉ cho chọn bác sĩ (kể cả chọn ngẫu nhiên) trong số bác sĩ làm được đủ tất cả dịch vụ của combo, giống quy tắc CatalogProvider.doctorsFor đang dùng (lib/providers/catalog_provider.dart).
- Chọn ngày giờ gọi /api/availability, xem giá gọi /api/bookings/quote, nhập voucher gọi /api/vouchers/validate, xác nhận gọi POST /api/appointments.
- Danh sách và chi tiết lịch hẹn, nút hủy, ô "Lịch hẹn sắp tới" ở trang chủ dùng API thật.
- Chú ý: màn hình hồ sơ khám, hóa đơn của Ngân còn dùng mã giả patient-001, patient-002. Không xóa dữ liệu giả mà các màn hình đó đang cần, chỉ tách phần của đặt lịch ra.
- Mỗi màn hình có trạng thái đang tải, lỗi kèm nút thử lại, danh sách trống.

Frontend: không dùng cloud_firestore trực tiếp (Firestore Rules chặn mọi đọc/ghi), chỉ gọi API qua biến api trong lib/data/api_client.dart.

Yêu cầu chung: đọc code liên quan và cho tôi xem kế hoạch trước khi sửa. Không chạy lệnh git. Sau khi sửa frontend chạy flutter test và flutter analyze, sửa các test bị ảnh hưởng. Cuối mỗi giai đoạn gửi tôi bảng các bước tự test (backend thì test bằng api-test.http, frontend thì trên máy ảo). Giải thích bằng tiếng Việt dễ hiểu.
```

## 👩‍💻 Ngân: Module 3, Hồ sơ nha khoa

```
Bối cảnh: app Flutter nha khoa "MediCare Dental" cho bệnh nhân, nhóm 4 người, làm thẳng trên nhánh main. Frontend Flutter trong frontend/, backend Node.js + Express + firebase-admin v14 trong backend/, dữ liệu ở Firestore project yoursmile-49379.

Đọc trước: README.md ở thư mục gốc (mục quy ước và mã thật), backend/README.md (khuôn viết API). Module 1 đã xong, dùng làm mẫu: backend/src/routes/users.js, familyMembers.js, favorites.js; frontend lib/data/api_client.dart (biến api tự gắn token), lib/data/services/catalog_service.dart, lib/providers/catalog_provider.dart, lib/providers/profile_provider.dart. Module 2 (đặt lịch) của Phương có thể đã xong, xem backend/src/routes/appointments.js.

Tôi là Ngân, làm Module 3: Hồ sơ nha khoa (chỉ đọc dữ liệu). Làm theo 2 giai đoạn, xong giai đoạn 1 thì DỪNG để tôi test.

GIAI ĐOẠN 1: Backend, viết vào các file khung có sẵn trong backend/src/routes/: patients.js, visits.js, invoices.js, treatments.js
- GET /api/patients/:id/visits: lịch sử các lần khám
- GET /api/visits/:id: kết quả khám, chẩn đoán
- GET /api/visits/:id/prescriptions: đơn thuốc của lần khám
- GET /api/patients/:id/invoices: danh sách hóa đơn
- GET /api/invoices/:id: chi tiết hóa đơn
- GET /api/patients/:id/treatments: danh sách liệu trình
- GET /api/treatments/:id: chi tiết và tiến độ liệu trình
- GET /api/treatments/:id/sessions: các buổi điều trị
- GET /api/treatments/:id/photos: ảnh trước, sau
- GET /api/patients/:id/follow-ups: lịch tái khám
BẢO MẬT BẮT BUỘC: đây là dữ liệu y tế nhạy cảm. Mọi API đều cần đăng nhập. Chỉ trả dữ liệu khi patientId là UID của người đăng nhập hoặc là id một người thân trong users/{uid}/family_members của chính người đó. Với API theo id (visits/:id, invoices/:id, treatments/:id...) phải đọc document rồi kiểm tra patientId của nó, không đúng thì trả 403. Viết 1 hàm kiểm tra quyền dùng chung, đặt ở backend/src/utils/records.js.
Trước khi viết: tạo script tạm CHỈ ĐỌC vài document mẫu của visits, prescriptions, invoices, treatments, treatment_sessions, follow_ups (và chỗ lưu ảnh trước sau nếu có) để biết đúng tên trường và giá trị patientId đang dùng, chạy xong thì xóa script. Nếu patientId trong dữ liệu mẫu không phải UID tài khoản test thì báo tôi để nhờ Phương sửa dữ liệu, đừng tự sửa Firestore. Không sửa server.js, auth.js, firebase.js và file của module khác. Thêm request test (cả trường hợp đúng, xem hồ sơ người thân, và xem hồ sơ của tài khoản khác phải bị 403) vào cuối backend/api-test.http.

GIAI ĐOẠN 2: Frontend, nối các màn hình hồ sơ khám, kết quả khám, đơn thuốc, hóa đơn, liệu trình, buổi điều trị, ảnh trước sau, lịch tái khám với API. Thay mã giả patient-001, patient-002 bằng mã thật: bản thân là UID, người thân lấy từ ProfileProvider. Cho chọn xem hồ sơ của bản thân hoặc từng người thân. Ảnh trước sau: imageUrl trống thì hiện icon mặc định. Mỗi màn hình có trạng thái đang tải, lỗi kèm nút thử lại, danh sách trống. Nếu còn chỗ nào của module khác đang phụ thuộc mã giả thì báo tôi trước khi xóa.

Frontend: không dùng cloud_firestore trực tiếp (Firestore Rules chặn mọi đọc/ghi), chỉ gọi API qua biến api trong lib/data/api_client.dart.

Yêu cầu chung: đọc code liên quan và cho tôi xem kế hoạch trước khi sửa. Không chạy lệnh git. Sau khi sửa frontend chạy flutter test và flutter analyze, sửa các test bị ảnh hưởng. Cuối mỗi giai đoạn gửi tôi bảng các bước tự test. Giải thích bằng tiếng Việt dễ hiểu.
```

## 👩‍💻 Nhi: Module 4, Nội dung và thông báo

```
Bối cảnh: app Flutter nha khoa "MediCare Dental" cho bệnh nhân, nhóm 4 người, làm thẳng trên nhánh main. Frontend Flutter trong frontend/ (giao diện do tôi dựng), backend Node.js + Express + firebase-admin v14 trong backend/, dữ liệu ở Firestore project yoursmile-49379.

Đọc trước: README.md ở thư mục gốc (mục quy ước, mã thật, cấu trúc notifications), backend/README.md (khuôn viết API). Module 1 đã xong, dùng làm mẫu: backend/src/routes/services.js, favorites.js; frontend lib/data/api_client.dart (biến api tự gắn token), lib/data/services/catalog_service.dart, lib/providers/catalog_provider.dart. Module 2 (đặt lịch, Phương) đã tạo thông báo vào notifications và lịch hẹn ở appointments, xem backend/src/routes/appointments.js.

Tôi là Nhi, làm Module 4: Nội dung và thông báo. Làm theo 2 giai đoạn, xong giai đoạn 1 thì DỪNG để tôi test.

GIAI ĐOẠN 1: Backend, viết vào các file khung có sẵn trong backend/src/routes/: articles.js, home.js, notifications.js
- GET /api/articles (chỉ bài isPublished true, mới nhất trước, có thể lọc theo category), GET /api/articles/:id. Không cần đăng nhập.
- GET /api/home: cần đăng nhập, trả { featuredServices, featuredDoctors, latestArticles, upcomingAppointment }. featuredServices ưu tiên mục có isFeatured true, không có thì lấy vài mục đầu. upcomingAppointment là lịch hẹn gần nhất chưa diễn ra, chưa hủy của tài khoản đang đăng nhập, không có thì null.
- GET /api/notifications (của người đăng nhập, mới nhất trước), GET /api/notifications/unread-count, PATCH /api/notifications/:id/read (chỉ chủ thông báo, người khác trả 403), PATCH /api/notifications/read-all.
Trước khi viết: tạo script tạm CHỈ ĐỌC vài document mẫu của articles, notifications, appointments để biết đúng tên trường, chạy xong thì xóa script. Nếu Firestore báo cần tạo index thì gửi tôi link. Không sửa server.js, auth.js, firebase.js và file của module khác. Thêm request test vào cuối backend/api-test.http.

GIAI ĐOẠN 2: Frontend
- Danh sách và chi tiết bài viết dùng API thật.
- Lưu bài viết: nối với /api/favorites type "article" giống dịch vụ, bác sĩ (xem favorite_button.dart). Bỏ mã giả article-brushing. Màn hình "Đã lưu" đã có tab lọc, thêm hoặc nối tab "Bài viết" cho đúng.
- Trang chủ: cân nhắc dùng /api/home cho gọn, giữ nguyên giao diện.
- Màn hình thông báo dùng API, chấm đỏ số chưa đọc ở biểu tượng chuông, bấm vào thông báo thì đánh dấu đã đọc, có nút đọc tất cả.
- Sửa hoặc xóa frontend/integration_test/api_foundation_test.dart (đang gọi API của backend Dart cũ không còn tồn tại).
- Mỗi màn hình có trạng thái đang tải, lỗi kèm nút thử lại, danh sách trống.

Frontend: không dùng cloud_firestore trực tiếp (Firestore Rules chặn mọi đọc/ghi), chỉ gọi API qua biến api trong lib/data/api_client.dart.

Yêu cầu chung: đọc code liên quan và cho tôi xem kế hoạch trước khi sửa. Không chạy lệnh git. Sau khi sửa frontend chạy flutter test và flutter analyze, sửa các test bị ảnh hưởng. Cuối mỗi giai đoạn gửi tôi bảng các bước tự test. Giải thích bằng tiếng Việt dễ hiểu.
```

---

# 3. Ghi chú

## 3.1. Việc cần làm 1 lần sau khi pull bản mới
```powershell
git pull
cd frontend
flutter pub get
cd ../backend
npm install
```
Mỗi lần pull về mà có người thêm thư viện mới (file `frontend/pubspec.yaml` thay đổi) thì chạy lại `flutter pub get` trong `frontend`, rồi chạy lại app từ đầu (không dùng `r` tải lại nhanh). Tương tự, `backend/package.json` thay đổi thì chạy lại `npm install` trong `backend`.

**Tạo file khóa Firebase** (mỗi người tự tạo 1 lần): Firebase Console → project **yoursmile** → ⚙️ **Project settings** → tab **Service accounts** → **Generate new private key** → đổi tên file thành **`serviceAccountKey.json`** → bỏ vào thư mục **`backend`** (ngang hàng `package.json`).
⚠️ Không push, không gửi file này cho ai. Lỡ làm lộ thì báo Bình ngay.

## 3.2. Chạy app: luôn mở 2 terminal

Bấm dấu **`+`** ở khung Terminal của VS Code để mở thêm terminal.

**Terminal 1: backend (chạy rồi để đó, không gõ gì thêm)**
```powershell
cd backend
npm run dev
```
Thấy `Server chạy tại http://localhost:3000` là được. Sửa code backend rồi lưu thì server tự chạy lại. Tắt bằng `Ctrl + C`.

**Terminal 2: app và các lệnh khác (Git...)**
1. Bật máy ảo: bấm **No Device** ở góc dưới bên phải VS Code → chọn máy ảo Android, đợi tới màn hình chính.
2. Chạy:
   ```powershell
   cd frontend
   flutter run
   ```
   Có nhiều thiết bị thì gõ số đứng trước dòng có chữ `emulator`. Đang chạy: `r` tải lại nhanh, `R` khởi động lại, `q` thoát.

   `flutter run` không cần thêm cờ nào: app mặc định dùng **dữ liệu thật** từ backend (`DATA_SOURCE=api`, máy ảo Android tự gọi `http://10.0.2.2:3000`). Muốn xem **dữ liệu giả** để demo khi không có backend thì chạy `flutter run --dart-define=DATA_SOURCE=mock`.

**Cách khác thay cho `flutter run`:** bấm **Run → Start Debugging (F5)** trên VS Code. Backend **vẫn phải chạy ở Terminal 1**.
- Nếu VS Code hỏi chọn cấu hình, chọn cấu hình API, ví dụ **`MediCare Dental - API (Android Emulator)`** (dữ liệu thật). Cấu hình có `DATA_SOURCE=mock`, ví dụ **`MediCare Dental - Mock (Demo)`**, dùng dữ liệu giả, không cần backend. Cấu hình không truyền `DATA_SOURCE` thì mặc định là dữ liệu thật.
- Danh sách cấu hình F5 nằm ở `.vscode/launch.json`. Thư mục `.vscode` **không lên GitHub**, nên máy mỗi người có thể khác nhau. Mở file đó ra kiểm tra: nếu còn cấu hình có **`8080`** (backend Dart cũ) thì sửa thành **`3000`**; nếu còn cấu hình chạy **`backend/bin/server.dart`** (file không còn tồn tại) thì xóa đi. Không chắc thì cứ dùng `flutter run` ở Terminal 2.

Không chạy Terminal 1 thì app vẫn mở nhưng báo *"Không kết nối được tới máy chủ"*.

## 3.3. Git hằng ngày

**Trước khi bắt đầu làm**
```powershell
git pull
```

**Trước khi để Claude sửa code** (tạo mốc an toàn, lỡ hỏng thì quay lại được)
```powershell
git add .
git commit -m "Moc truoc khi lam ..."
```

**Làm xong và đã test chạy được**
```powershell
git status
```
Kiểm tra **không có** `serviceAccountKey.json`, `.env`, `node_modules`, `build`, và `api-test.http` không chứa mật khẩu. Ổn thì:
```powershell
git add .
git commit -m "Mo ta viec da lam"
git pull
git push
```
Rồi nhắn nhóm *"Mình push xong rồi"*.

**Gặp CONFLICT khi pull:** dừng lại, gõ `git status`, chụp màn hình gửi nhóm, **đừng bấm bừa** Accept Current/Incoming.

**Hiện màn hình đen có chữ `Merge branch...`:** bấm vào màn hình → **Esc** → gõ `:wq` → **Enter**.

**❌ Không bao giờ:** `git push --force`, tạo nhánh riêng, push code đang lỗi, để Claude chạy lệnh git.

## 3.4. Test API (không cần mở app)
Cả nhóm dùng chung **một file `backend/api-test.http`** (có trên GitHub, **không chứa mật khẩu**). Mật khẩu nằm trong `backend/.env` trên máy mỗi người (không lên GitHub).

1. Cài extension **REST Client** trong VS Code.
2. Tạo `backend/.env` theo mẫu `backend/.env.example`, điền mật khẩu (**hỏi Bình**):
   ```powershell
   Copy-Item backend/.env.example backend/.env
   ```
   ```
   TEST_PASSWORD=...   # mật khẩu test123@gmail.com
   STAFF_PASSWORD=...  # mật khẩu staff@nhakhoa.com
   ```
3. Mở `backend/api-test.http`, bật backend, bấm 2 request ở mục **ĐĂNG NHẬP (dùng chung)** trước (staff chỉ cần khi test phần nhân viên), sau đó bấm request của module mình. Sửa `.env` xong mà REST Client chưa nhận thì đóng mở lại VS Code.
4. Thêm request của module mình vào đúng mục **MODULE 1/2/3/4**. **Không ghi mật khẩu**, không dán token, id lịch, id người thân cứng: dùng biến lấy từ response (`# @name ...` rồi `{{ten.response.body.$.id}}`). Mật khẩu mới thì thêm vào `.env` và `.env.example` (để trống), đọc bằng `{{$dotenv TEN_BIEN}}`.

---

Kẹt chỗ nào thì chụp màn hình gửi nhóm. 💪
