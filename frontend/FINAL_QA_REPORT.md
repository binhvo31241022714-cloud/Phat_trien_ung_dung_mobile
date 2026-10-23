# MediCare Dental — Final UI, Integration & QA

Ngày kiểm tra: **21/10/2026**, múi giờ Việt Nam. Phạm vi: ứng dụng bệnh nhân demo.

## 1. Tổng quan và kết quả

Đã kiểm tra lại mã và chạy độc lập các lệnh, không dùng báo cáo trước làm kết quả
kiểm chứng. Trước khi sửa, analyzer không lỗi và **54 test hiện có đạt**. Các test
mới vẫn tìm ra lỗi route, Back và layout chưa được bộ test cũ bao phủ.

Sau sửa:

| Kiểm tra | Kết quả cuối |
| --- | --- |
| Dart format | Không còn tệp cần định dạng |
| Flutter analyze | **No issues found** |
| Flutter test | **68 test đạt** = 54 test cũ + 14 test QA mới |
| Android integration | **1 kịch bản ứng dụng đạt**, có bước tearDownAll riêng của framework |
| Android build/run | Build, cài và chạy thành công trên emulator-5554 |
| Screenshot thực tế | **13 PNG**, chụp lại sau các sửa cuối |

Không còn lỗi chặn các luồng đã kiểm tra. Đây không phải tuyên bố ứng dụng đã
sẵn sàng production hoặc không thể còn lỗi ngoài phạm vi kiểm thử.

## 2. Cấu trúc và nguồn dữ liệu đã kiểm tra

Đã đọc entrypoint, App/MainShell/routes, Provider, model/mock, theme/widget chung,
các module features, HomeScreen, test và hai báo cáo triển khai trước.

Kiểm kê import graph: **98 tệp Dart trong lib**, **84 tệp có đường import/export từ
main.dart**. Chi tiết máy đọc được: [source_audit.json](qa_artifacts/source_audit.json).

- MainShell sử dụng `screens/home/home_screen.dart`, `BookingScreen`,
  `RecordsHomeScreen`, `MeScreen`; giữ IndexedStack và một NavigationBar.
- Chỉ có hai Provider: UserProvider và PatientDataProvider. BookingController là
  state của một draft đặt lịch, không phải danh sách lịch hẹn thứ hai.
- Không phát hiện class trùng tên trong lib. Các trang danh sách mới đọc Provider
  đang có; không sao chép dữ liệu mock sang UI.
- Ba file danh sách services/doctors/articles trước đây chỉ có comment đã được
  triển khai và nối vào các nút Xem tất cả.
- Còn **8 scaffold chỉ có comment**, đều không được import từ entrypoint: ba widget
  booking_calendar/patient_selector/service_selection_card và năm widget trong
  features/home/widgets. UI tương ứng thực tế đang được triển khai ở các file
  hoạt động khác. Giữ lại chúng, không xóa chỉ vì chưa được dùng.
- Tổng cộng 14 tệp ngoài import graph ứng dụng, gồm scaffold, widget dự phòng và
  file export tương thích; danh sách cụ thể có trong JSON. Một số vẫn được test
  hoặc là API tiện ích. Không xóa hàng loạt.
- Dependency runtime hiện có được giữ nguyên. Bổ sung duy nhất dev dependency
  `integration_test` từ Flutter SDK, cùng dependency chuyển tiếp phục vụ driver.
  Không nâng cấp các thư viện runtime hoặc thêm SDK backend.

## 3. Lỗi tìm thấy và đã sửa

| Mã | Vấn đề đã xác minh | Sửa và tệp chính |
| --- | --- | --- |
| QA-01 | Xem tất cả ở Home chuyển nhầm sang Đặt lịch/Tôi; ba trang danh sách là scaffold | Hoàn thiện service_list_screen.dart, doctor_list_screen.dart, article_list_screen.dart; nối đúng danh sách từ Home |
| QA-02 | Home mở mô tả chung thay vì trang chi tiết thật, bài viết không thể bookmark từ Home | Tái sử dụng chi tiết dịch vụ/bác sĩ/bài viết; bookmark dùng Provider chung; thêm shared/catalog_navigation.dart để giữ thanh điều hướng |
| QA-03 | Chuông và Xem chi tiết lịch sắp tới mở trang chữ tĩnh | Chuông mở Thông báo thật; lịch sắp tới mở đúng chi tiết trong Hồ sơ. Sửa Home, PatientDataProvider và MeScreen |
| QA-04 | Back hệ thống có thể gọi pop ở navigator của tab ẩn, dẫn đến mất route gốc/Bad state: No element | Callback chỉ pop khi tab đang hoạt động và canPop. Sửa HomeScreen, RecordsHomeScreen, MeScreen; có test Back lặp và chuyển tab sau đó |
| QA-05 | Chữ 150% làm card bài viết tràn dọc 50px và tiêu đề người khám tràn ngang trong test 360px | Chiều cao hàng card Home thích ứng text scale; Expanded cho tiêu đề người khám ở booking_screen.dart |
| QA-06 | Welcome tràn dọc 271px ở viewport 360×540 với chữ 150% | welcome_screen.dart cuộn được khi cần, giữ bố cục và Spacer ở kích thước thông thường |
| QA-07 | Chữ phụ #9E9E9E trên nền #F7F7F7 chỉ đạt tương phản khoảng 2.50:1; trạng thái tab chọn chưa đồng nhất | Đổi các TextStyle chữ phụ liên quan sang #666666, khoảng 5.36:1; đồng nhất icon/nhãn tab chọn màu xanh trong main_shell.dart |
| QA-08 | Thông báo lịch hẹn mồ côi vẫn có thể hiện nội dung như lịch thật; Home fallback bác sĩ/dịch vụ có thể lấy nhầm bản ghi đầu hoặc crash khi danh sách trống | Thông báo nêu liên kết không khả dụng; Home dùng thông tin thiếu rõ ràng, không gán sang người/dịch vụ khác |
| QA-09 | Controller đã dispose còn có thể nhận thao tác và notify; gọi xác nhận lặp trước rebuild có thể hiện lỗi dữ liệu gây hiểu nhầm | Guard lifecycle ở booking_controller.dart và guard gửi lặp ở booking_screen.dart; kiểm tra submit hết hạn/đang gửi khi dispose không tạo lịch ma |
| QA-10 | Catalog rỗng chỉ để lại vùng trống, bước dịch vụ không giải thích vì sao không thể tiếp tục | Empty state rõ cho Home/catalog/booking services; nút tiếp tục vẫn bị vô hiệu hóa khi chưa có dịch vụ |

Các thay đổi màu chữ phụ chỉ là sửa tương phản, không thay bố cục hoặc nội dung.
Thay đổi navigator Home giữ nguyên cây UI tổng quan, chỉ sửa đích điều hướng và
bảo toàn Bottom Navigation. Không viết lại MainShell hoặc đổi thứ tự đặt lịch.

## 4. Màn hình và điều hướng đã kiểm tra

| Nhóm | Kiểm tra tự động |
| --- | --- |
| Auth | Welcome, Login rỗng/email sai/mật khẩu ngắn; Register xác nhận mật khẩu không khớp và Register → Login; Forgot Password → thông báo chưa gửi email thật → Login |
| Home | Header, lịch sắp tới, ba hàng card ngang; Xem tất cả → đúng danh sách → chi tiết → Back; chuông → Thông báo; lịch sắp tới → Hồ sơ |
| Booking | Chọn nhiều/bỏ chọn dịch vụ, bác sĩ cụ thể/hệ thống, ngày giờ, các lựa chọn còn thiếu/quá khứ, chi tiết rồi Back, tổng tiền, ghi chú nhiều dòng, gửi một lần, thành công → Hồ sơ/Trang chủ |
| Hồ sơ | Chọn người thân, thống kê, danh sách/chi tiết lịch, xác nhận hủy/giữ lịch, lịch sử/chi tiết lần khám, đơn thuốc/phiếu thanh toán theo dữ liệu, kết quả riêng bằng fixture, nhiều liệu trình, ảnh placeholder, tái khám → Đặt lịch |
| Tôi | Sáu mục và các trang phụ; validation/lưu hồ sơ; thêm/sửa/xóa người thân đúng quy tắc; lọc/đọc thông báo; settings/ngôn ngữ/mật khẩu demo/riêng tư/FAQ; bookmark ba loại nội dung |
| Stack | Chuyển tab giữ draft và trang con; Back nhiều lần không pop tab ẩn; chỉ một NavigationBar; logout xóa phiên và stack, Back không vào MainShell; login lại được |

Các test cũ vẫn được giữ và chạy. Test QA mới phân biệt đúng nút đăng ký với
AppBar cùng tiêu đề, và phân biệt tiêu đề danh sách với category chip; không bỏ
assert để né lỗi. Log trung gian và kết quả cuối được giải thích trong
[qa_artifacts/README.md](qa_artifacts/README.md).

## 5. Đồng bộ dữ liệu

- UserProvider quản lý tài khoản, PatientDataProvider quản lý bệnh nhân và dữ liệu
  nha khoa. Đổi người thân ở Hồ sơ/Đặt lịch không đổi tài khoản.
- Sửa bản thân giữ patientId và bản ghi bệnh án; sửa người thân giữ ID; thêm/xóa
  cập nhật dropdown hai tab. Xóa hồ sơ liên kết bị chặn.
- Booking tạo đúng một lịch trong Provider chung, trạng thái Chờ xác nhận; tổng
  tiền lấy từ các dịch vụ. Chuyển sang Hồ sơ thấy lịch ngay.
- Hủy giữ bản ghi trong danh sách, cập nhật trạng thái và loại khỏi lịch sắp tới
  đang hoạt động. Trang chủ luôn chọn lịch sắp tới hợp lệ theo thời gian.
- Bookmark Home → Chi tiết → Đã lưu và bỏ lưu hai chiều dùng cùng một tập ID.
- Thông báo lấy ngày/giờ/dịch vụ/trạng thái từ lịch liên kết thực tế; liên kết
  không có dữ liệu thì không trình bày nội dung cũ như lịch thật.
- Không thêm nguồn dữ liệu lịch hẹn, người thân hoặc bookmark thứ hai.

## 6. Responsive, bàn phím và accessibility

Đã chạy widget test tại **360/390/430px**. Kiểm tra mới dùng viewport thấp **640px**,
text scale **1.5** cho bốn tab và toàn bộ booking đến thành công; Welcome được
kiểm tra riêng ở **360×540px**, text scale 1.5. Các test form hiện có vẫn kiểm tra
bàn phím, nội dung nhiều dòng và khả năng tiếp cận nút lưu/xác nhận.

Sau sửa, không có RenderFlex overflow trong các trường hợp này. Danh sách cuộn,
chip thông báo cuộn ngang, nội dung chi tiết không bị chặn bởi thanh điều hướng.
Tương phản 5.36:1 chỉ là phép đo cặp màu chữ phụ/nền đã sửa, **không phải chứng
nhận accessibility toàn ứng dụng**. Chưa xác minh TalkBack, mọi text scale, mọi
thiết bị và mọi chuỗi nội dung có thể có.

## 7. Đối chiếu ảnh tham chiếu

Đã xem ảnh Android thực tế của Home, xác nhận booking, tổng quan Hồ sơ và Tôi;
đối chiếu cấu trúc với ảnh được cung cấp trong hội thoại. Giữ nền nhạt, card bo
góc, hàng card Home, bốn bước booking, thống kê Hồ sơ và sáu mục Tôi. Không thêm
banner/gradient hoặc dashboard khác.

Tên, số liệu, giá và ngày giờ trong ảnh QA lấy từ Provider, không ép bằng ví dụ
trong ảnh tham chiếu. Ảnh xác nhận được chụp sau khi cuộn đến ghi chú/tổng tiền;
card người khám và stepper vẫn ở phía trên vùng cuộn. Chưa có golden test hoặc
so sánh pixel tự động, nên không tuyên bố giống tuyệt đối từng pixel.

## 8. Analyzer, test và lệnh tái hiện

Chạy trong frontend:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test
flutter drive --driver=test_driver/final_qa_driver.dart --target=integration_test/final_flow_test.dart -d emulator-5554
flutter run -d emulator-5554 --debug --no-resident
```

Kết quả cuối: **68/68 unit/widget đạt**, analyzer không lỗi, format không đổi.
Kịch bản Android đạt riêng; thông báo +2 của runner gồm một test ứng dụng và
tearDownAll, không cộng nhầm thành hai kịch bản nghiệp vụ.

Bằng chứng: [flutter_test.log](qa_artifacts/flutter_test.log),
[flutter_analyze.log](qa_artifacts/flutter_analyze.log),
[dart_format.log](qa_artifacts/dart_format.log),
[android_integration.log](qa_artifacts/android_integration.log),
[android_run.log](qa_artifacts/android_run.log).

## 9. Android Emulator và ảnh chụp

Thiết bị: **emulator-5554**, sdk gphone16k arm64, Android 17/API 37.
Build assembleDebug và cài APK thành công.

Kịch bản integration chạy thật trên emulator, thao tác UI để:

1. Đăng nhập và xem Home.
2. Mở bài viết từ Home, bookmark.
3. Chọn hai dịch vụ, hệ thống phân công, ngày tương lai và 09:00, nhập ghi chú,
   xác nhận; kiểm tra Provider tăng đúng một lịch Chờ xác nhận.
4. Mở Hồ sơ/chi tiết lịch vừa tạo, mở hộp thoại hủy và chọn Giữ lịch.
5. Back về tổng quan, đổi sang hồ sơ người thân và kiểm tra tài khoản không đổi.
6. Sang Tôi, thêm người thân, sửa tên và kiểm tra ID không đổi; xem Đã lưu/Cài đặt.
7. Đăng xuất và kiểm tra Back không vào lại MainShell.

Đây là **integration test tự động trên emulator**, không phải toàn bộ thao tác
thủ công trên điện thoại vật lý. Hủy lịch thật trong Provider và đồng bộ Home
được xác minh bằng widget/provider test; Android scenario chọn Giữ lịch.

Có 13 ảnh PNG trong [qa_screenshots](qa_screenshots/README.md), gồm bốn tab, các
bước booking, thành công, đổi hồ sơ, người thân, Đã lưu, Cài đặt và Welcome sau
logout. Sau integration test đã cài/chạy lại entrypoint lib/main.dart thông thường
để emulator không giữ bản test tự động.

## 10. Tệp thay đổi chính trong QA

- `lib/screens/home/home_screen.dart`
- `lib/features/shared/catalog_navigation.dart` (mới)
- `lib/features/services/service_list_screen.dart`
- `lib/features/doctors/doctor_list_screen.dart`
- `lib/features/articles/article_list_screen.dart`
- `lib/features/booking/booking_screen.dart`, `booking_controller.dart`, `steps/select_services_step.dart`
- `lib/features/auth/welcome_screen.dart`
- `lib/features/records/records_home_screen.dart`
- `lib/features/me/me_screen.dart`, `notifications_screen.dart`
- `lib/data/providers/patient_data_provider.dart`
- `lib/app/main_shell.dart`
- Các TextStyle chữ phụ trong features: chỉ đổi màu xám nhằm sửa tương phản.
- `test/final_qa_test.dart` (mới, 14 test)
- `integration_test/final_flow_test.dart`, `test_driver/final_qa_driver.dart` (mới)
- `pubspec.yaml`, `pubspec.lock`: integration_test SDK ở dev_dependencies.
- Báo cáo, log, JSON kiểm kê và ảnh trong FINAL_QA_REPORT.md, qa_artifacts, qa_screenshots.

## 11. Những phần chưa thay đổi và giới hạn

- 8 scaffold không tham chiếu vẫn được giữ để tránh xóa API/tổ chức file có thể
  dùng về sau; chúng không tạo màn hình trắng trong các route ứng dụng hiện tại.
- Route CRUD user cũ `/users`, `/users/form` và lớp UserService của source gốc vẫn
  còn. Không có đường dẫn từ UI bệnh nhân tới chúng. Chưa tự xóa public route
  hoặc đổi nghiệp vụ cũ; cần quyết định loại bỏ/bảo vệ trước phát hành thật.
- Demo là một tài khoản bệnh nhân mẫu, không phải hệ thống đa tài khoản có phân
  quyền. Đây là giới hạn đã có, không đổi nghiệp vụ xác thực trong QA.
- Chưa kiểm thử trên điện thoại thật, TalkBack, iOS hoặc mọi kích thước/text scale.
  Không chứng nhận bảo mật, pháp lý, hiệu năng production hoặc độ giống pixel.
- Thông tin điều trị/kết quả riêng/ảnh/thuốc còn thiếu trong mock tiếp tục hiển
  thị thiếu dữ liệu đúng nghĩa; không tự tạo bệnh án để làm UI trông đầy đủ.

## 12. Giới hạn demo bắt buộc

Không có Firebase Auth, kiểm tra giờ trống thật, API đặt lịch thật, thanh toán
online, push thật, đổi mật khẩu thật, sinh trắc học thật hoặc lưu bền vững.
Không gửi email khôi phục thật. Dữ liệu thay đổi mất khi khởi động lại tiến trình.
Các API legacy không được dùng trong luồng bệnh nhân demo đã kiểm tra.

Không sửa backend Dart, không tạo Provider/model trùng chức năng, không thêm
role doctor/admin, không tạo commit.

## 13. Trước khi nối backend thật

Cần chốt hợp đồng API/ID và validation phía server; xác thực/phân quyền hồ sơ và
route legacy; trạng thái/hủy lịch cùng chống tạo trùng phía server; kiểm tra
availability theo bác sĩ; lưu dữ liệu và xử lý lỗi mạng/timeout/retry; chính sách
bảo vệ dữ liệu và ảnh bệnh án; kiểm thử trên thiết bị thật và accessibility.
Đây là các bước tiếp theo, **chưa được triển khai trong Prompt 09**.
