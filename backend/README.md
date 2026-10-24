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
| PATCH  | /api/users/me             | Có  | Sửa `fullName`, `phone`, `birthday`, `gender`, `address` |
| GET    | /api/family-members       | Có  | Danh sách người thân |
| POST   | /api/family-members       | Có  | Thêm người thân. Bắt buộc `fullName` |
| PATCH  | /api/family-members/:id   | Có  | Sửa người thân |
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
