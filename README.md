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
| **Module 2**: Đặt lịch nha khoa | Phương | 25 đến 26/10 | ⏳ Chưa làm |
| **Module 3**: Hồ sơ nha khoa | Ngân | 27 đến 28/10 | ⏳ Chưa làm |
| **Module 4**: Nội dung và thông báo | Nhi | 29 đến 31/10 | ⏳ Chưa làm |
| Hoàn thiện UI/UX, kiểm thử, slide | Ngân + cả nhóm | 01 đến 02/11 | ⏳ |

## ✅ Module 1 đã xong những gì

| Chức năng | Trên app | API |
|---|---|---|
| Đăng ký, đăng nhập, quên mật khẩu, đăng xuất (Firebase thật, báo lỗi tiếng Việt) | ✅ | Không cần |
| Tự đăng nhập khi mở lại app | ✅ | Không cần |
| Hồ sơ cá nhân: xem, sửa. Trang chủ và tab "Tôi" hiện tên thật | ✅ | `/api/users/me` |
| Người thân: xem, thêm, sửa, xóa | ✅ | `/api/family-members` |
| Giới tính và thông tin sức khỏe (dị ứng thuốc, bệnh nền, thuốc đang dùng, mang thai, ghi chú) cho bản thân và người thân; nhãn "⚠ Có lưu ý sức khỏe" | ✅ | `/api/users/me`, `/api/family-members` |
| Dịch vụ, combo, bác sĩ: trang chủ, danh sách, chi tiết | ✅ | `/api/services`, `/api/combos`, `/api/doctors` |
| Lưu yêu thích, màn hình "Đã lưu" có tab lọc | ✅ | `/api/favorites` |
| Tìm kiếm không phân biệt dấu, lọc Dịch vụ/Combo, sắp xếp theo giá; tìm và lọc bác sĩ theo chuyên khoa | ✅ | `/api/services`, `/api/combos`, `/api/doctors` |
| "Bác sĩ thực hiện" ở chi tiết dịch vụ, bấm dịch vụ ở chi tiết bác sĩ để mở | ✅ | `/api/doctors` (`serviceIds`) |
| Xác minh email: gửi thư khi đăng ký, nhắc ở tab "Tôi", gửi lại (chờ 60 giây), không chặn dùng app | ✅ | Không cần |
| Đổi mật khẩu thật (xác thực lại bằng mật khẩu hiện tại) | ✅ | Không cần |
| Cài đặt "Ngôn ngữ" và "Nhận thông báo" lưu trên máy, mở lại app vẫn còn | ✅ | Không cần |
| File gọi API dùng chung cho cả nhóm, tự gắn token | ✅ `frontend/lib/data/api_client.dart` | |

## ⚠️ Những chỗ còn dữ liệu giả (cố tình để lại) và ai xử lý

Module 1 **không thay** các chỗ này vì màn hình của module khác đang dùng chúng. Thay sớm sẽ làm văng app.

| Chỗ còn giả | Ai xử lý | Cách xử lý |
|---|---|---|
| Ô **"Người khám"** trong đặt lịch có **"Nguyễn Hải Nam"** (mã giả `patient-002`) | **Phương** | Lấy từ `GET /api/users/me` (bản thân) + `GET /api/family-members` (người thân) |
| **Chọn dịch vụ, combo, bác sĩ** trong đặt lịch (mã giả `service-checkup`...) | **Phương** | Lấy từ `/api/services`, `/api/combos`, `/api/doctors` |
| **Hồ sơ khám, đơn thuốc, hóa đơn, liệu trình** dùng mã giả `patient-001`, `patient-002` | **Ngân** | Dùng mã thật (bảng dưới) |
| **Bài viết đã lưu** (mã giả `article-brushing`, Firestore là `article_01`) | **Nhi** | Nối `/api/favorites` với type `"article"` (API đã hỗ trợ) |
| File `frontend/integration_test/api_foundation_test.dart` lỗi (gọi API backend Dart cũ) | **Nhi** | Sửa hoặc xóa |
| Ảnh dịch vụ, bác sĩ chỉ hiện icon (`imageUrl`, `avatarUrl` trống) | **Phương** | Dán link ảnh vào Firestore |
| "Dịch vụ nổi bật" đang lấy 6 dịch vụ đầu tiên | **Nhi** (`/api/home`) | Có thể nhờ Phương thêm trường `isFeatured` |
| Màn hình **Thông báo** khi tắt "Nhận thông báo" còn câu *"...trong phiên demo..."* | **Nhi** | Sửa câu cho đúng khi nối thông báo thật |

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

# 2. Prompt cho Claude trong VS Code

Mỗi người copy **nguyên khung của mình**, mở Claude trong VS Code, bấm **New chat** rồi dán vào. Trước khi để Claude sửa: `git pull` và commit một mốc an toàn (mục 3).

## 👩‍💻 Phương: Module 2, Đặt lịch nha khoa

```
Bối cảnh: app Flutter nha khoa "MediCare Dental" cho bệnh nhân, nhóm 4 người, làm thẳng trên nhánh main. Frontend Flutter trong frontend/, backend Node.js + Express + firebase-admin v14 trong backend/, dữ liệu ở Firestore project yoursmile-49379.

Đọc trước: README.md ở thư mục gốc (mục quy ước và mã thật), backend/README.md (khuôn viết API). Module 1 đã xong, dùng làm mẫu: backend/src/routes/users.js, familyMembers.js, favorites.js; frontend lib/data/api_client.dart (biến api tự gắn token), lib/data/services/catalog_service.dart, lib/providers/catalog_provider.dart, lib/providers/profile_provider.dart.

Tôi là Phương, làm Module 2: Đặt lịch nha khoa. Làm theo 2 giai đoạn, xong giai đoạn 1 thì DỪNG để tôi test.

GIAI ĐOẠN 1: Backend, viết vào các file khung có sẵn trong backend/src/routes/: bookings.js, availability.js, vouchers.js, appointments.js
- POST /api/bookings/quote: nhận danh sách serviceIds và/hoặc comboId, trả tổng tiền và tổng thời gian khám (cộng price, durationMinutes). Có voucherCode thì tính luôn giảm giá.
- GET /api/availability?date=YYYY-MM-DD&doctorId=...&durationMinutes=...: trả các khung giờ còn trống, dựa trên doctor_schedules và các lịch hẹn đã có. Không truyền doctorId thì gộp tất cả bác sĩ.
- POST /api/vouchers/validate: kiểm tra mã còn hạn, còn lượt, đủ điều kiện, trả số tiền giảm.
- POST /api/appointments: tạo lịch hẹn. Cho phép đặt cho bản thân (patientId = UID) hoặc người thân (patientId phải là id trong users/{uid}/family_members của chính người đặt). Cho phép chọn bác sĩ hoặc để trống (chọn ngẫu nhiên bác sĩ còn trống). BẮT BUỘC dùng Firestore Transaction với cơ chế giữ slot để hai người không đặt trùng một bác sĩ một khung giờ. Lưu accountId, patientId, doctorId, serviceIds, comboId, date (chuỗi "YYYY-MM-DD"), startTime, endTime (chuỗi "HH:mm"), totalPrice, discount, voucherCode, status "booked", createdAt (Timestamp). Tạo thêm 1 thông báo vào notifications theo cấu trúc trong README gốc.
- GET /api/appointments (lịch của tài khoản đang đăng nhập, gồm cả lịch của người thân), GET /api/appointments/:id (chỉ chủ tài khoản xem được, người khác trả 403).
- PATCH /api/appointments/:id/cancel: chỉ chủ tài khoản, chỉ hủy được lịch chưa diễn ra, giải phóng slot, tạo thông báo hủy.
Trước khi viết: tạo script tạm CHỈ ĐỌC 1 document mẫu của doctor_schedules, vouchers, services, combos, doctors để biết đúng tên trường, chạy xong thì xóa script. Nếu dữ liệu mẫu thiếu trường cần thiết thì báo tôi, đừng tự sửa Firestore. Không sửa server.js, auth.js, firebase.js và file của module khác. Thêm request test (cả trường hợp đúng và lỗi: trùng giờ, voucher sai, xem lịch người khác) vào cuối backend/api-test.http.

GIAI ĐOẠN 2: Frontend, nối các màn hình đặt lịch với API:
- Ô "Người khám" lấy từ ProfileProvider (bản thân + người thân thật), bỏ "Nguyễn Hải Nam" giả.
- Chọn dịch vụ, combo, bác sĩ lấy từ CatalogProvider (dữ liệu thật).
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

**Cách khác thay cho `flutter run`:** bấm **Run → Start Debugging (F5)** trên VS Code. Backend **vẫn phải chạy ở Terminal 1**.
- Nếu VS Code hỏi chọn cấu hình, chọn **`frontend`**.
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
Kiểm tra **không có** `serviceAccountKey.json`, `api-test.http`, `node_modules`, `build`. Ổn thì:
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
Cài extension **REST Client** trong VS Code. Tạo file `backend/api-test.http` (đã bị chặn khỏi GitHub), lấy **Web API Key** ở `frontend/lib/firebase_options.dart` (đoạn `web`, dòng `apiKey`). Mẫu file và tài khoản test: hỏi Bình.

---

Kẹt chỗ nào thì chụp màn hình gửi nhóm. 💪