> Cập nhật tích hợp 31/10/2026: backend hiện tại là Node.js/Express + Firebase Admin; `DATA_SOURCE` mặc định là `api`. Phần baseline/mock/backend Dart bên dưới là lịch sử, không phải bằng chứng nghiệm thu hiện tại. Xem [báo cáo và runbook hiện hành](INTEGRATION_AUDIT_962a981.md).

# Hướng dẫn chạy demo frontend

## Dependencies và thiết bị

Từ root dự án:

```sh
cd frontend
flutter pub get
flutter doctor
flutter emulators
flutter devices
```

Nếu emulator chưa chạy: dùng `flutter emulators --launch <emulator-id>` với ID
được liệt kê, hoặc mở Android Studio Device Manager. Android SDK/adb phải được
cấu hình trong môi trường; không hardcode đường dẫn SDK cá nhân vào repository.

## Mock Mode — chế độ mặc định, dùng để demo

```sh
flutter run -t lib/main.dart -d <device-id> --dart-define=DATA_SOURCE=mock
```

Ví dụ thiết bị kiểm thử là emulator-5554; thay ID theo `flutter devices`.
Không cần backend, Firebase hoặc API key. Không chạy test/*.dart bằng nút Run
ứng dụng. Trong VS Code có cấu hình MediCare Dental (Mock Android); chọn profile
Flutter thay vì backend/Full stack. `frontend/lib/main.dart` là entrypoint.

## API Mode — chỉ nền tảng legacy đã hỗ trợ

```sh
flutter run -t lib/main.dart -d <device-id> --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=<base-url-duoc-backend-ban-giao>
```

Thay placeholders trước khi chạy. API_BASE_URL là host HTTP(S), không chứa token,
userinfo, query hoặc fragment; API_URL là alias tương thích cũ. Với backend local
đã được bàn giao cổng 8080, Android emulator dùng host 10.0.2.2, web/desktop dùng
localhost; máy thật dùng host LAN có thể truy cập. Không suy ra mọi backend dùng
cổng 8080. Dart-define được biên dịch vào app; không đặt secret trong đó.

Hiện chỉ repository user legacy đổi theo DATA_SOURCE. Bốn tab, Article và
Notification vẫn dùng PatientDataProvider/mock; auth vẫn demo, không phải kết
nối người dùng thật. MockUserReadRepository rỗng và không gọi mạng; CRUD legacy
bị chặn trong Mock Mode. Không có link tới /users từ UI bệnh nhân. Không chạy API
Mode để demo nội dung, không dùng token giả và không khởi động/sửa backend thay
thành viên khác. Các lệnh API ở đây là hướng dẫn bàn giao, không được chạy trong
Prompt 11.

## Kiểm thử

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test
flutter test test/content_handover_test.dart
```

Android (khi emulator-5554 có thật; thay ID nếu cần):

```sh
flutter drive --driver=test_driver/handover_driver.dart --target=integration_test/content_handover_test.dart -d emulator-5554 --dart-define=DATA_SOURCE=mock
flutter drive --driver=test_driver/handover_driver.dart --target=integration_test/final_flow_test.dart -d emulator-5554 --dart-define=DATA_SOURCE=mock
```

Test HTTP giả lập không chứng minh API thật; xem kết quả và giới hạn ghi riêng
ở QA_RESULTS.md. Screenshot/log lần này ở qa_artifacts/handover/.

## Luồng demo

1. Welcome → Login bằng email hợp lệ và password đạt validation demo; không xác
   thực thật. Register/Forgot hiển thị hành vi demo, không gửi email thật.
2. Home: lời chào, lịch sắp tới, services/doctors/articles; Xem tất cả → detail → Back.
3. Mở article từ Home, lưu → tab Tôi/Đã lưu → bỏ lưu → kiểm tra lại article.
4. Chuông Home → Thông báo, đổi bốn filters; chạm thông báo để đọc. Nếu có lịch
   liên kết mở Hồ sơ/chi tiết; offer/system không có đích thì chỉ đánh dấu đọc.
5. Booking: chọn người khám, nhiều dịch vụ, bác sĩ/hệ thống, ngày tương lai và
   khung giờ, note, kiểm tra tổng rồi xác nhận. Hồ sơ/Home thấy lịch cùng Provider.
6. Hủy lịch demo đủ điều kiện → Home không còn hiển thị lịch bị hủy.
7. Hồ sơ: đổi bệnh nhân, history/detail, thuốc/hóa đơn, liệu trình/ảnh, followup.
8. Tôi: sửa profile, thêm/sửa người thân, notifications/settings/help/saved.
   Đổi bệnh nhân ở Hồ sơ không đổi tài khoản đăng nhập.
9. Logout → Welcome; Back không vào lại MainShell. Restart app mất thay đổi RAM.

## Giới hạn

Không persistence, backend patient API, Auth thật, push/FCM, lịch trống thật,
voucher thật, thanh toán online, đổi mật khẩu, email khôi phục hay sinh trắc học
thật. Hình điều trị có placeholder; mock bài viết chỉ có summary. Ngày mock cố
định năm 2026/2027 có thể trở thành quá khứ; chọn ngày tương lai khi demo, không
sửa mock để che lỗi thời gian. Một tài khoản demo không đại diện đa tài khoản có
phân quyền. Chưa kiểm thử mọi thiết bị vật lý/iOS/TalkBack.

## Tái hiện baseline Prompt 12

Baseline dùng Flutter 3.47.2 stable / Dart 3.13.2, pubspec.lock hiện tại. SDK
constraint trong pubspec không phải chứng nhận tương thích mọi Flutter cũ;
ưu tiên cùng SDK khi bàn giao, không nâng dependency để chạy lại baseline.
Dependencies hiện đã resolve; chỉ cần pub get nếu clone mới hoặc cache thiếu.

Lệnh Mock cụ thể khi emulator-5554 đang hoạt động:

```sh
flutter run -t lib/main.dart -d emulator-5554 --dart-define=DATA_SOURCE=mock
```

Hai scenario baseline chặn mọi HTTP qua Dart HttpClient của app isolate, không
cần dừng backend; lần đầu không truyền DATA_SOURCE để xác minh default thực tế:

```sh
flutter drive --driver=test_driver/release_baseline_driver.dart --target=integration_test/release_baseline_test.dart -d emulator-5554
flutter drive --driver=test_driver/release_baseline_driver.dart --target=integration_test/release_baseline_test.dart -d emulator-5554 --dart-define=DATA_SOURCE=mock --dart-define=CONTENT_SCENARIO=true
```

Driver nhận screenshot của các scenario có sẵn, không lưu PNG trùng lặp; ảnh
Prompt 11 vẫn ở qa_artifacts/handover/screenshots/. Test API Mode cũ trong
integration_test/api_foundation_test.dart không thuộc baseline Mock; không chạy
trong tác vụ không kết nối API thật. Kết quả mới ở FRONTEND_RELEASE_BASELINE.md.
