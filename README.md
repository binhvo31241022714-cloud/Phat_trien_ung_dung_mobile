Ứng dụng nha khoa cho bệnh nhân

Đồ án Phát triển ứng dụng mobile. App Flutter cho bệnh nhân nha khoa: xem dịch vụ, bác sĩ, đặt lịch, xem hồ sơ khám và quản lý tài khoản.

App Flutter (frontend/)  ──HTTP + token──▶  Node.js + Express (backend/)  ──▶  Firebase (Auth + Firestore)
Thư mục	Nội dung
frontend/	App Flutter
backend/	REST API Node.js + Express. Hướng dẫn viết API: backend/README.md
Thành viên và phân công
Thành viên	Phụ trách
Nhi	Frontend Flutter chính, Backend Module 4 (Nội dung và thông báo)
Bình	Hỗ trợ Frontend xác thực, Backend Module 1 (Tài khoản và dữ liệu cơ bản)
Phương	Firebase và dữ liệu mẫu, Backend Module 2 (Đặt lịch nha khoa)
Ngân	Backend Module 3 (Hồ sơ nha khoa), hoàn thiện UI/UX
📌 Quy tắc làm việc chung
1. Git (quan trọng nhất)
Trước khi bắt đầu làm: luôn git pull.
Làm xong:
powershell
  git add .
  git commit -m "Mô tả việc đã làm"
  git pull
  git push
Push xong nhắn nhóm: "Mình push xong rồi, tới lượt ...."
Mở VS Code bằng File → Open Folder → chọn đúng thư mục Phat_trien_ung_dung_mobile, để terminal luôn đứng đúng chỗ.
❌ KHÔNG BAO GIỜ dùng git push --force.
Bị lỗi, CONFLICT hay màn hình lạ thì dừng lại, chụp màn hình gửi nhóm, đừng tự chạy lệnh lạ.
2. Bảo mật
File serviceAccountKey.json xin Bình gửi riêng, bỏ vào thư mục backend.
❌ KHÔNG push file này, KHÔNG gửi lên nhóm chung. Repo đang để Public.
Trước khi commit chạy git status. Thấy serviceAccountKey.json, node_modules hoặc api-test.http trong danh sách thì dừng lại.
3. Chia file backend

Mỗi người chỉ viết API trong file của module mình, trong backend/src/routes/:

Module	Người	File
1. Tài khoản và dữ liệu cơ bản	Bình	users.js, familyMembers.js, services.js, combos.js, doctors.js, favorites.js
2. Đặt lịch nha khoa	Phương	bookings.js, availability.js, vouchers.js, appointments.js
3. Hồ sơ nha khoa	Ngân	patients.js, visits.js, invoices.js, treatments.js
4. Nội dung và thông báo	Nhi	articles.js, home.js, notifications.js
Ưu tiên viết vào file có sẵn, tại chỗ // TODO.
Cần file route mới: thêm 1 dòng app.use(...) vào backend/src/server.js, đặt trong đúng phần module của mình, rồi báo nhóm.
File phụ (hàm tính toán, kiểm tra...): để trong backend/src/utils/, đặt tên theo module, ví dụ utils/booking.js.
❌ Không sửa file của module người khác, không sửa auth.js, firebase.js. Cần sửa thì hỏi Bình trước.
4. Dữ liệu Firestore
Tên collection và tên trường làm theo file thiết kế dữ liệu của Phương, không tự đặt tên khác.
Tên trường viết kiểu camelCase: fullName, doctorId, createdAt.
Tiền lưu số nguyên VND (300000), ngày giờ lưu kiểu Timestamp.
Cần thêm collection hoặc trường mới thì báo Phương để cập nhật file thiết kế.
API chỉ trả dữ liệu của chính người đăng nhập (hoặc người thân của họ), nhất là hồ sơ khám và lịch hẹn.
5. Frontend Flutter
Thêm thư viện vào pubspec.yaml xong thì push ngay và báo nhóm pull.
Trong Flutter gọi API bằng http://10.0.2.2:3000, không dùng localhost.
Không sửa màn hình của người khác khi chưa hỏi.
6. Trước khi push phải tự test
Backend: npm run dev chạy không lỗi, API test bằng REST Client trả đúng kết quả.
Frontend: flutter run chạy được trên máy ảo.
Code đang lỗi thì không push, để người sau khỏi bị kẹt.
Cài đặt lần đầu
powershell
git clone https://github.com/binhvo31241022714-cloud/Phat_trien_ung_dung_mobile.git
cd Phat_trien_ung_dung_mobile

cd frontend
flutter pub get

cd ../backend
npm install

Sau đó xin Bình file serviceAccountKey.json, bỏ vào thư mục backend, rồi đọc backend/README.md.