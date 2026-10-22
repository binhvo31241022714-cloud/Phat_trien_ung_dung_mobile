# Tab Tôi — kết quả triển khai Prompt 08

## Màn hình và điều hướng

Đã triển khai tổng quan tài khoản với sáu mục; Thông tin cá nhân; Quản lý người
thân và form thêm/sửa; Thông báo; Cài đặt; Ngôn ngữ; Đổi mật khẩu; Quyền riêng tư;
Trợ giúp với bốn FAQ; Đã lưu và các trang chi tiết nội dung tương ứng.

Navigator trong tab Tôi giữ nguyên MainShell và thanh điều hướng duy nhất.
Back quay về màn hình trước; chuyển tab giữ state các màn hình. Không thay đổi
thiết kế Trang chủ, Đặt lịch hay Hồ sơ. Các chỉnh sửa ở các module đó chỉ phục vụ
đồng bộ người thân và điều hướng thông báo.

## Tài khoản và hồ sơ bệnh nhân

UserProvider hiện có được bổ sung account, currentUser, isAuthenticated và các
thao tác phiên demo. Đăng nhập vẫn dùng validation và trải nghiệm demo cũ;
sau validation, email nhập được đưa vào phiên. Không gọi API xác thực.

Bản demo tiếp tục sử dụng một tài khoản bệnh nhân mẫu với ID ổn định. Tên, ngày
sinh và điện thoại khởi tạo từ hồ sơ bản thân trong MockData; email khởi tạo rỗng
và lấy từ đăng nhập khi có phiên. Đây chưa phải hệ thống nhiều tài khoản độc lập.

Tab Tôi đọc tên từ UserProvider, không đọc từ bệnh nhân đang chọn ở Hồ sơ.
Lưu Thông tin cá nhân cập nhật UserProvider và hồ sơ bản thân tương ứng trong
PatientDataProvider, giữ nguyên patientId. Không sửa tên người thân hay dữ liệu
lịch hẹn, lần khám, liệu trình.

Form kiểm tra tên bắt buộc, email nếu nhập, số điện thoại di động Việt Nam nếu
nhập, ngày sinh không ở tương lai. Thay ảnh chỉ thông báo giới hạn demo.

## Người thân

Nguồn duy nhất vẫn là PatientDataProvider. Thêm tạo ID riêng bằng thời gian và
bộ đếm; form chặn nhấn lưu lặp. Sửa giữ nguyên ID. Hồ sơ bản thân chỉ sửa qua
Thông tin cá nhân và không thể bị xóa.

Xóa cần xác nhận và kiểm tra liên kết lịch hẹn, lần khám, liệu trình, tái khám.
Có dữ liệu liên kết thì chặn xóa và nêu lý do; không xóa dây chuyền bệnh án.
Nếu xóa người thân không có dữ liệu, lựa chọn Hồ sơ và Đặt lịch trở về bản thân
an toàn. Dropdown cập nhật từ Provider chung, không cần khởi động lại app.

## Bookmark, thông báo và cài đặt

- Đã lưu đọc chính savedArticles, savedServiceIds, savedDoctorIds hiện có. Mở
  đúng chi tiết, bỏ lưu cập nhật cả hai chiều. Không tạo danh sách lưu riêng.
- Thông báo dùng danh sách hiện có, bổ sung loại và appointmentId tùy chọn.
  Các chip lọc đúng loại; nhấn đánh dấu đã đọc. Thông báo có appointmentId hợp
  lệ mở chi tiết lịch hẹn trong tab Hồ sơ. Dịch vụ/ngày/giờ/trạng thái được lấy
  từ lịch hẹn đang có, không cố định theo ảnh.
- Tùy chọn nhận thông báo và sinh trắc học mô phỏng lưu trong UserProvider.
  Không gọi push notification hoặc Face ID/vân tay của hệ điều hành.
- Chỉ có Tiếng Việt. Đổi mật khẩu chỉ kiểm tra biểu mẫu và báo chưa khả dụng;
  không kiểm tra mật khẩu hiện tại, không lưu mật khẩu vào Provider/storage,
  không gọi API và không thông báo đổi mật khẩu thành công giả.

## Đăng xuất

Nút Đăng xuất có hộp thoại Hủy/Đăng xuất. Xác nhận gọi cơ chế
PatientNavigation.logout hiện có, cập nhật UserProvider sang chưa đăng nhập
trước khi điều hướng, rồi pushNamedAndRemoveUntil về Welcome trên root
Navigator. Back không trở lại MainShell; đăng nhập lại mở MainShell mới.
Dữ liệu bệnh án mock và các thay đổi tiện ích trong bộ nhớ không bị tự xóa.

## Tệp đã sửa hoặc tạo trong Prompt 08

- `lib/features/me/me_screen.dart`
- `lib/features/me/me_widgets.dart` (mới)
- `lib/features/me/edit_profile_screen.dart`
- `lib/features/me/family_list_screen.dart`
- `lib/features/me/family_form_screen.dart`
- `lib/features/me/notifications_screen.dart`
- `lib/features/me/settings_screen.dart`
- `lib/features/me/language_screen.dart`
- `lib/features/me/change_password_screen.dart`
- `lib/features/me/privacy_screen.dart`
- `lib/features/me/help_screen.dart`
- `lib/features/me/saved_items_screen.dart`
- `lib/features/articles/article_detail_screen.dart`
- `lib/providers/user_provider.dart`
- `lib/data/models/user_model.dart`
- `lib/data/models/patient_records.dart`
- `lib/data/providers/patient_data_provider.dart`
- `lib/data/mock_data.dart`
- `lib/core/utils/validators.dart`
- `lib/app/main_shell.dart`
- `lib/app/patient_navigation.dart`
- `lib/features/auth/login_screen.dart`
- `lib/features/booking/booking_screen.dart`
- `lib/features/records/records_home_screen.dart`
- `lib/features/records/appointments_screen.dart`
- `test/me_test.dart` (mới)
- `test/booking_test.dart`, `test/records_test.dart`, `test/widget_test.dart`
- `ME_IMPLEMENTATION.md` (mới)

## Kiểm thử

- Dart format: hoàn tất, kiểm tra lại không còn thay đổi định dạng.
- Flutter analyze: không có vấn đề.
- Flutter test: 54 test đạt, gồm 14 test mới cho tab Tôi; giữ các kiểm tra của
  Đặt lịch và Hồ sơ, cập nhật thao tác điều hướng theo giao diện tài khoản mới.
- Kiểm tra sáu mục, tài khoản độc lập với bệnh nhân, form validation, đồng bộ
  bản thân, bàn phím và layout ở 360/390/430px.
- Kiểm tra thêm/sửa/xóa người thân, chặn xóa hồ sơ liên kết, xác nhận/hủy xóa,
  dropdown hai tab và chuyển về bản thân sau xóa.
- Kiểm tra lọc/đọc thông báo, mở đúng lịch hẹn; bookmark bài viết/dịch vụ/bác sĩ;
  tùy chọn cài đặt, giới hạn ngôn ngữ, xác nhận mật khẩu và ẩn/hiện mật khẩu.
- Kiểm tra đăng xuất có xác nhận, cập nhật session, Back sau logout và login lại.
- Android Emulator `emulator-5554` (Android 17/API 37): build, cài và khởi chạy
  thành công; đã đăng nhập demo, mở tổng quan tab Tôi và Thông tin cá nhân trực tiếp.

## Giới hạn demo

Tất cả thay đổi chỉ trong bộ nhớ, mất khi tiến trình ứng dụng khởi động lại.
Chưa có backend cho đăng nhập, tài khoản, người thân, thông báo, bookmark và
cài đặt. Chưa có upload ảnh, push notification, sinh trắc học thật, đổi mật khẩu
hay bản dịch khác. Chưa có cơ sở dữ liệu cục bộ. Không sửa backend, không tạo
commit và không triển khai Prompt 09.
