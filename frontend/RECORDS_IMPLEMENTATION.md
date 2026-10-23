# Hồ sơ nha khoa — kết quả triển khai

## Các màn hình

Đã triển khai tổng quan và dropdown chọn hồ sơ, danh sách/chi tiết lịch hẹn,
lịch sử/chi tiết lần khám, kết quả khám, đơn thuốc, phiếu thanh toán,
danh sách/chi tiết liệu trình, ảnh trước/sau và lịch tái khám.

Các màn hình con dùng Navigator bên trong tab Hồ sơ. MainShell tiếp tục sở hữu
thanh điều hướng duy nhất; chuyển tab giữ màn hình đang xem và Back quay về
màn hình con trước đó.

## Các tệp đã sửa hoặc tạo

- `lib/features/records/records_home_screen.dart`
- `lib/features/records/records_widgets.dart` (mới)
- `lib/features/records/appointments_screen.dart`
- `lib/features/records/appointment_detail_screen.dart`
- `lib/features/records/visit_history_screen.dart`
- `lib/features/records/visit_detail_screen.dart`
- `lib/features/records/exam_result_screen.dart`
- `lib/features/records/prescription_screen.dart`
- `lib/features/records/payment_receipt_screen.dart`
- `lib/features/records/treatment_list_screen.dart`
- `lib/features/records/treatment_detail_screen.dart`
- `lib/features/records/treatment_photos_screen.dart`
- `lib/features/records/followup_screen.dart`
- `lib/data/models/patient_records.dart`
- `lib/data/providers/patient_data_provider.dart`
- `lib/data/mock_data.dart`
- `lib/app/main_shell.dart`
- `lib/app/patient_navigation.dart`
- `lib/features/booking/booking_screen.dart`
- `lib/screens/home/home_screen.dart` (chỉ sửa nhãn bác sĩ chờ phân công)
- `test/records_test.dart` (mới)
- `test/booking_test.dart`
- `test/widget_test.dart`
- `RECORDS_IMPLEMENTATION.md` (mới)

## Lọc và đồng bộ dữ liệu

`PatientDataProvider.recordsPatient` sử dụng lựa chọn hồ sơ riêng qua
`focusAppointmentsFor`, không đổi `selectedPatientId` của hồ sơ chung/tab Tôi.
Lịch hẹn, lần khám, liệu trình và tái khám đều lọc theo `patientId` bằng các
hàm `appointmentsFor`, `visitsFor`, `treatmentsFor`, `followupsFor`.
Ba thống kê lần lượt đếm lịch đang chờ/đã xác nhận, lần khám đã ghi nhận và
liệu trình của bệnh nhân đó. Lịch hẹn đã hủy vẫn nằm trong danh sách.

BookingController vẫn lưu lịch vào PatientDataProvider hiện có. Nút Xem hồ sơ
sau đặt thành công mở danh sách lịch hẹn của đúng người khám. Hủy lịch cần
xác nhận, chỉ áp dụng cho lịch demo trong tương lai đang chờ hoặc đã xác nhận;
Provider thay trạng thái, không xóa bản ghi. Các màn hình đang nghe Provider,
bao gồm Trang chủ, tự cập nhật.

Đặt lịch tái khám/đặt lịch từ danh sách trống chuyển sang tab Đặt lịch và truyền
đúng bệnh nhân. Không tự tạo lịch, không tự chọn ngày đề xuất đã qua. Người dùng
vẫn phải chọn dịch vụ, bác sĩ, ngày giờ và xác nhận trong luồng đặt lịch.

## Kiểm tra

- Dart format: các tệp thay đổi đã được định dạng.
- Flutter analyze: không có vấn đề.
- Flutter test: 40 test đạt, gồm 15 test mới cho module Hồ sơ.
- Widget test tại 360/390/430px: dropdown người thân, dữ liệu/thống kê theo bệnh
  nhân, empty state, các màn hình con, Back, placeholder ảnh và một thanh điều hướng.
- Kiểm tra lịch đặt mới, chi tiết lịch, hộp thoại Giữ lịch/Xác nhận hủy, đồng bộ
  Provider và Trang chủ, không hủy lại hoặc hủy lịch hoàn thành/quá khứ.
- Kiểm tra liên kết lần khám–đơn thuốc–phiếu thanh toán; chỉ hiện nút khi có dữ liệu;
  màn kết quả khám có kiểm tra bằng fixture riêng.
- Kiểm tra tiến độ liệu trình, nhiều liệu trình, lịch tái khám quá khứ, chuyển tab
  giữ màn hình và chuyển đúng bệnh nhân sang luồng đặt lịch.
- Android Emulator `emulator-5554` (Android 17/API 37): build/cài/khởi chạy thành công;
  đã đăng nhập demo, mở tổng quan Hồ sơ, danh sách và chi tiết lịch hẹn trực tiếp.

## Dữ liệu demo và giới hạn

Hồ sơ khám, đơn thuốc, hóa đơn và liệu trình vẫn là dữ liệu mock chỉ đọc. Model
được mở rộng bằng các trường tùy chọn; lần khám mẫu được nối với lịch hẹn đã
hoàn thành sẵn có, không tạo lần khám từ lịch hẹn đang chờ.

Dữ liệu mẫu chưa có nội dung điều trị/kết quả riêng và ảnh bệnh nhân, đơn thuốc
mẫu không có thuốc. Giao diện hiện thông tin còn thiếu hoặc placeholder phù hợp;
không sao chép chẩn đoán/thuốc/ảnh từ ví dụ hoặc Internet. Tổng tiền và trạng thái
thanh toán chỉ hiện theo thông tin đã ghi nhận, không suy đoán đã thanh toán.

Chưa tích hợp API, Firebase, cơ sở dữ liệu cục bộ, thanh toán trực tuyến hay upload
ảnh. Thay đổi lịch demo mất khi khởi động lại ứng dụng. Không sửa backend, không
tạo commit và không triển khai module ngoài Hồ sơ cùng các kết nối cần thiết.
