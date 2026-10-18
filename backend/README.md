# Backend (Dart + shelf)

REST API viết bằng Dart, cùng ngôn ngữ với frontend Flutter.

## Chạy

```bash
cd backend
cp .env.example .env   # tuỳ chọn
dart pub get
dart run bin/server.dart
```

Mặc định chạy tại `http://localhost:8080`.

## Cấu trúc

```
backend/
├── bin/server.dart            # Điểm khởi động server
├── lib/
│   ├── config/env.dart        # Đọc biến môi trường
│   ├── core/                  # ApiResponse, AppException
│   ├── middlewares/           # CORS, xử lý lỗi
│   ├── models/                # Định nghĩa dữ liệu
│   ├── repositories/          # Truy cập dữ liệu (hiện lưu trong bộ nhớ)
│   ├── services/              # Nghiệp vụ, kiểm tra dữ liệu
│   ├── controllers/           # Nhận request, trả response
│   └── routes/app_router.dart # Khai báo route
└── test/                      # Unit test
```

Luồng xử lý: `route -> controller -> service -> repository`.

## API mẫu

| Method | Endpoint          | Mô tả            |
|--------|-------------------|------------------|
| GET    | /api/health       | Kiểm tra server  |
| GET    | /api/users        | Danh sách user   |
| GET    | /api/users/:id    | Chi tiết user    |
| POST   | /api/users        | Tạo user         |
| PUT    | /api/users/:id    | Cập nhật user    |
| DELETE | /api/users/:id    | Xoá user         |

Body POST/PUT: `{ "name": "An", "email": "an@example.com" }`

## Test

```bash
dart test
```
