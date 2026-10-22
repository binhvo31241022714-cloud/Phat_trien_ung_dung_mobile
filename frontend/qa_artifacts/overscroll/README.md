# Kiểm tra hiệu ứng overscroll — MediCare Dental

## Nguyên nhân và thay đổi

`AppTheme.light` bật Material 3. Source Flutter SDK đang dùng tại
`packages/flutter/lib/src/material/app.dart`, hàm
`MaterialScrollBehavior.buildOverscrollIndicator`, tự bọc scrollable trên Android
bằng `StretchingOverscrollIndicator` khi Material 3 bật.

Kiểm tra source ứng dụng thấy SingleChildScrollView/ListView cho các trang dọc,
ba ListView ngang ở Home và hàng bộ lọc thông báo ngang. Không có NestedScrollView,
physics tùy chỉnh hoặc ScrollBehavior riêng gây xung đột.

Thêm `AppScrollBehavior extends MaterialScrollBehavior`: chỉ override
`buildOverscrollIndicator` để trả nguyên child. Đặt một lần tại MaterialApp trong
`lib/app.dart`. Giữ physics, scrollbar và các hành vi nền tảng kế thừa từ Material.
Không đổi card, màu sắc, padding, kích thước, keyboard dismissal hoặc navigation.
Không thêm NeverScrollableScrollPhysics. Không sửa backend/API/Firebase/mock.

## File thuộc lần sửa này

- Sửa `lib/app.dart`: import và gắn ScrollBehavior chung.
- Thêm `lib/core/theme/app_scroll_behavior.dart`.
- Thêm `test/scroll_behavior_test.dart`: hai test regression.
- Thêm `integration_test/overscroll_test.dart`: kéo quá biên các trang trên Android.
- Thêm `test_driver/overscroll_driver.dart`: lưu ảnh vào thư mục QA riêng.
- README, log và ảnh tại `qa_artifacts/overscroll/`.

Các diff title/initialRoute trong app.dart và thay đổi khác trong repository đã
có từ trước lần sửa này, không phải thay đổi thiết kế của tác vụ overscroll.

## Kiểm chứng

- Flutter analyze: không có lỗi (`analyze.log`).
- Flutter test: 89 test đạt, gồm 87 test cũ và 2 test cuộn mới (`test.log`).
- Test mới tái hiện widget stretch với MaterialScrollBehavior mặc định trên Android;
  sau cấu hình mới, không còn stretch/glow, cuộn ngang/dọc vẫn thay đổi vị trí;
  kiểm tra cấu hình áp dụng qua App thật và bốn tab.
- Android emulator-5554, Android 17/API 37, Mock Mode:
  `android_boundaries.log` kiểm tra 35 điểm màn hình. Với vùng có thể cuộn,
  kéo tới hai biên; với vùng ngắn, kéo quá biên đầu. Kiểm tra cả khi ngón tay đang
  giữ. Không có stretch/glow hoặc exception; danh sách dài vẫn dịch chuyển.
- Phạm vi 35 điểm: Welcome/Login/Register/Forgot Password; Home với ba hàng ngang;
  ba catalog và chi tiết; booking services; tổng quan Hồ sơ, lịch hẹn/chi tiết,
  lịch sử/chi tiết lần khám, kết quả, đơn thuốc, phiếu thanh toán, liệu trình/
  chi tiết/ảnh, tái khám; tổng quan Tôi, hồ sơ cá nhân, người thân/form, thông báo/
  bộ lọc ngang, cài đặt/ngôn ngữ/mật khẩu/riêng tư, trợ giúp, đã lưu.
- Luồng UI Android riêng trong `android_flow.log`: đăng nhập, bookmark, đặt lịch
  đủ bốn bước với ghi chú, mở Hồ sơ, thêm/sửa người thân, settings và logout.
  Mỗi log Android cuối có một scenario ứng dụng và tearDownAll của framework;
  không tính tearDownAll thành scenario nghiệp vụ.
- `android_combined_attempt.log` là lần chạy trung gian đã dừng khi thử ghép hai
  scenario; không dùng làm kết quả cuối. Hai scenario được chạy độc lập bên dưới.

Lệnh tái hiện, chạy trong frontend:

```sh
flutter analyze
flutter test
flutter drive --driver=test_driver/overscroll_driver.dart --target=integration_test/overscroll_test.dart -d emulator-5554 --dart-define=DATA_SOURCE=mock
flutter drive --driver=test_driver/overscroll_driver.dart --target=integration_test/final_flow_test.dart -d emulator-5554 --dart-define=DATA_SOURCE=mock
flutter run -t lib/main.dart -d emulator-5554 --dart-define=DATA_SOURCE=mock --no-resident
```

Ảnh ở `screenshots/`. Đây là kiểm thử tự động trên emulator, không phải kiểm tra
mọi thiết bị vật lý hoặc chứng nhận accessibility. Không tạo commit.
