# Ảnh chụp QA trên Android Emulator

Được tạo bởi `integration_test/final_flow_test.dart` và driver lưu ảnh PNG thực tế,
không phải mockup hoặc ảnh golden. Các giá trị là dữ liệu demo trong lần chạy.

| Ảnh | Nội dung |
| --- | --- |
| 01_home.png | Trang chủ sau đăng nhập |
| 02_booking_services.png | Chọn dịch vụ |
| 03_booking_doctor.png | Chọn bác sĩ / hệ thống phân công |
| 04_booking_datetime.png | Ngày giờ đã chọn |
| 05_booking_confirm.png | Xác nhận, đã cuộn đến ghi chú và tổng tiền |
| 06_booking_success.png | Đặt lịch thành công |
| 07_records_overview.png | Tổng quan Hồ sơ sau đặt lịch |
| 08_records_relative.png | Hồ sơ người thân |
| 09_account.png | Tổng quan Tôi |
| 10_family.png | Danh sách sau thêm người thân |
| 11_saved.png | Bài viết đã lưu từ Trang chủ |
| 12_settings.png | Cài đặt |
| 13_logged_out.png | Welcome sau đăng xuất |

Chạy lại từ thư mục frontend:

```sh
flutter drive --driver=test_driver/final_qa_driver.dart --target=integration_test/final_flow_test.dart -d emulator-5554
```
