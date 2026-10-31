> Cập nhật tích hợp 31/10/2026: backend hiện tại là Node.js/Express + Firebase Admin; `DATA_SOURCE` mặc định là `api`. Phần baseline/mock/backend Dart bên dưới là lịch sử, không phải bằng chứng nghiệm thu hiện tại. Xem [báo cáo và runbook hiện hành](INTEGRATION_AUDIT_962a981.md).

# MediCare Dental — Tổng quan frontend

## Phạm vi và trạng thái

Ứng dụng Flutter dành cho bệnh nhân. Mock Mode là mặc định; các thay đổi chỉ tồn
tại trong RAM của phiên ứng dụng. Không có Firebase/Auth/push/thanh toán thật.
Prompt 11 chỉ sửa frontend và tài liệu. Không sửa/hoàn tác backend.

## Kiến trúc

`lib/main.dart` → MultiProvider (UserProvider, PatientDataProvider) → `App` →
MaterialApp → AppRoutes → MainShell. Package runtime: Flutter, provider, http.

- `app/main_shell.dart`: IndexedStack, bốn tab, một NavigationBar; giữ draft và
  navigator của tab khi chuyển tab.
- `screens/home/home_screen.dart`: Home đang hoạt động; navigator riêng cho
  catalog/chi tiết. `features/home/patient_home_screen.dart` là export tương thích;
  năm tệp trong `features/home/widgets/` chỉ là scaffold comment, không phải UI thật.
- `features/booking/booking_controller.dart`: draft bốn bước; không phải Provider
  dữ liệu lịch hẹn thứ hai.
- `features/records/records_home_screen.dart`, `features/me/me_screen.dart`:
  navigator con; theme cục bộ; callback Back chỉ pop khi tab đang hoạt động/canPop.
- `core/theme/app_scroll_behavior.dart`: MaterialScrollBehavior chỉ bỏ lớp
  stretch/glow; gắn tại App, không đổi physics hoặc tắt cuộn.

## Màn hình và điều hướng

| Nhóm | Màn hình/file trong lib |
|---|---|
| Auth demo | features/auth/{welcome,login,register,forgot_password}_screen.dart |
| Home | screens/home/home_screen.dart: lời chào, lịch gần nhất, dịch vụ nổi bật, bác sĩ, bài viết |
| Catalog | features/{services,doctors,articles}/*_list_screen.dart và *_detail_screen.dart |
| Đặt lịch | features/booking/booking_screen.dart, steps/*, booking_success_screen.dart |
| Hồ sơ | features/records/: overview, appointments/detail, visit_history/detail, exam_result, prescription, payment_receipt, treatment_list/detail/photos, followup |
| Tôi | features/me/: overview, edit_profile, family_list/form, notifications, settings, language, change_password, privacy, help, saved_items |
| Legacy | screens/user/user_list_screen.dart, user_form_screen.dart; không có lối vào từ UI bệnh nhân |

AppRoutes: `/welcome`, `/login`, `/register`, `/forgot-password`, `/main`,
`/patient/detail`; `/` về Welcome. `/users` và `/users/form` là route legacy,
không phải đăng nhập/hồ sơ bệnh nhân. Không thêm lối vào các route này khi bàn giao.

Home dùng CatalogNavigation.open cho danh sách/chi tiết. RecordsRoutes và
MeRoutes khai báo trong records_widgets.dart/me_widgets.dart. PatientNavigation
chuyển tab/logout. Chuông Home → requestNotifications → tab Tôi/Thông báo.
Thông báo có lịch liên kết hợp lệ → focusAppointmentsFor → tab Hồ sơ/chi tiết.

## Provider và model

| Lớp | Trách nhiệm |
|---|---|
| UserProvider | Tài khoản demo, phiên đăng nhập, cài đặt; state CRUD user legacy tách khỏi account |
| PatientDataProvider | Bệnh nhân/người thân được chọn, catalog, lịch/hồ sơ, thông báo, tập ID bookmark và yêu cầu điều hướng giữa tab |
| BookingController | Dịch vụ, bác sĩ, ngày/giờ, note, tổng tiền và trạng thái submit của một draft |

Models tại `data/models/`: Article; DentalService; Doctor; Patient; Appointment/
AppointmentStatus; UserModel; Visit, Prescription/Item, Receipt/Item, TreatmentPlan/
Session, Followup, PatientNotification/NotificationCategory trong patient_records.dart.
Patient IDs/catalog IDs là String; UserModel legacy dùng int. Không gán hai loại ID
cho nhau. Tiền hiện dùng int VND; lịch khám mock là giờ local; chưa có contract UTC.

`data/mock_data.dart` là nguồn dữ liệu demo gốc. Provider sao chép các tập mutable;
catalog/hồ sơ đọc từ mock. UI không tự fetch API nội dung. Không tạo Provider trùng.
Bookmark article dùng Set ID, cùng nguồn cho Home/chi tiết/Đã lưu; không lưu bền vững.

## Nền tảng API hiện tại

AppConfig: DATA_SOURCE=mock/api, API_BASE_URL (API_URL là alias cũ); Android native
mặc định 10.0.2.2:8080, web/desktop localhost:8080. Máy thật phải chỉ định host phù hợp.
ApiClient dùng http, GET/POST/PUT/DELETE, timeout, lỗi có kind/status, đọc envelope
Shelf hoặc JSON thuần. Không có PATCH vì backend trước đó chưa hỗ trợ; tokenProvider
là điểm tiêm tùy chọn, chưa được nối auth và không tự sinh token.

UserReadRepository có Mock/API implementation, chỉ cho user legacy. API Mode
không thay PatientDataProvider hoặc demo auth bằng backend, không có repository
article/notification giả. Xem API_INTEGRATION_MAP.md trước khi tích hợp.

Cách chạy và giới hạn chi tiết: DEMO_RUN_GUIDE.md. Kết quả kiểm thử lần bàn giao:
QA_RESULTS.md. Danh sách công việc theo người: TEAM_HANDOVER.md.

## Baseline bàn giao Prompt 12

Kết quả Prompt 11 ở QA_RESULTS.md là lịch sử. Xem
[FRONTEND_RELEASE_BASELINE.md](FRONTEND_RELEASE_BASELINE.md) cho lần kiểm tra cuối,
[FRONTEND_COMMIT_PLAN.md](FRONTEND_COMMIT_PLAN.md) cho phạm vi commit riêng và
[NHI_NEXT_STEPS.md](NHI_NEXT_STEPS.md) cho việc nhận API nội dung tiếp theo.
