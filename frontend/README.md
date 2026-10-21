# MediCare Dental — Flutter Frontend

Ứng dụng dành cho bệnh nhân. **Mock Mode là mặc định và không cần backend hoặc
Firebase để demo.** Các thư mục nền tảng đã có trong source; không cần chạy lại
`flutter create .` để bắt đầu.

Baseline được kiểm tra bằng Flutter 3.47.2 stable / Dart 3.13.2. Giữ pubspec.lock
khi bàn giao; chưa xác minh mọi phiên bản SDK cũ.

Từ thư mục gốc dự án:

```sh
cd frontend
flutter pub get
flutter devices
flutter run -t lib/main.dart -d emulator-5554 --dart-define=DATA_SOURCE=mock
```

Thay emulator-5554 bằng ID trong `flutter devices`. Không dùng test/*.dart làm
entrypoint ứng dụng. Nếu chưa có emulator chạy, xem hướng dẫn demo bên dưới.

```sh
flutter analyze
flutter test
```

- [Release baseline và kết quả kiểm tra mới nhất](docs/handover/FRONTEND_RELEASE_BASELINE.md)
- [Hướng dẫn chạy/demo và kiểm thử Android](docs/handover/DEMO_RUN_GUIDE.md)
- [Kiến trúc/màn hình/Provider](docs/handover/FRONTEND_OVERVIEW.md)
- [Phân công và bàn giao cho nhóm](docs/handover/TEAM_HANDOVER.md)
- [Kế hoạch commit riêng frontend](docs/handover/FRONTEND_COMMIT_PLAN.md)
- [Phần API nội dung tiếp theo của Nhi](docs/handover/NHI_NEXT_STEPS.md)

API foundation hiện chỉ hỗ trợ user legacy, không phải Auth hay dữ liệu bệnh
nhân thật. Bài viết, Home, thông báo, đặt lịch và hồ sơ vẫn demo. API contract
còn chờ nhóm xác nhận; không tự bật API/Firebase hoặc đưa secret vào dart-define.
Baseline này dành cho bàn giao source/demo, chưa phải phát hành lên cửa hàng.
