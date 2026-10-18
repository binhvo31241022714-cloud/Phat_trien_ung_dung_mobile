# Frontend (Flutter)

## Lần đầu: sinh thư mục nền tảng

Thư mục này mới có phần code Dart (`lib/`). Các thư mục `android/`, `ios/`,
`web/`, `windows/` do Flutter sinh ra, chạy lệnh sau một lần (không ghi đè `lib/`):

```bash
cd frontend
flutter create . --project-name frontend
flutter pub get
```

## Chạy

Chạy backend trước (xem `../backend/README.md`), sau đó:

```bash
flutter run                      # chọn thiết bị
flutter run -d chrome            # chạy trên web
flutter run --dart-define=API_URL=http://10.0.2.2:8080   # Android emulator
```

## Cấu trúc

```
frontend/
├── assets/images/               # Ảnh, icon
├── lib/
│   ├── main.dart                # Khởi động app, đăng ký Provider
│   ├── app.dart                 # MaterialApp, theme, route
│   ├── core/
│   │   ├── constants/           # URL API, màu sắc
│   │   ├── network/api_client.dart  # Gọi HTTP
│   │   ├── theme/               # Theme chung
│   │   └── utils/               # Hàm kiểm tra dữ liệu nhập
│   ├── data/
│   │   ├── models/              # Model parse JSON
│   │   └── services/            # Gọi API theo từng module
│   ├── providers/               # Quản lý state (provider)
│   ├── routes/app_routes.dart   # Khai báo màn hình
│   ├── screens/                 # Các màn hình
│   └── widgets/                 # Widget dùng chung
└── test/
```

Luồng dữ liệu: `screen -> provider -> service -> ApiClient -> backend`.
