# UI refinement — YourSmile Dental

## A. Design system

- Primary `#7050A3`, pastel `#A78BCB`, background `#F7F4FC`, text `#2F283D`; màu semantic error/success giữ ý nghĩa.
- Typography: page 20, title 18, section 16, body/button 14, secondary 12; không khóa text scale.
- Spacing 8/12/16/24; radius control 16/card 18; touch target chính tối thiểu 48.
- AppTokens, PageBackground, AuthBrand, GlassSelectionCard; theme cho input/button/card/chip/dialog/bottom sheet.
- Bỏ blur khỏi AppCard và bottom navigation; blur nhẹ 4 chỉ ở option liên quan của trang chi tiết.

### Audit trước khi sửa

Theme nằm tại `lib/core/theme/app_theme.dart`, `app_text_styles.dart`, `core/constants/app_colors.dart`.
Reusable widgets: PrimaryButton, SecondaryButton, AppTextField, AppCard, SectionHeader,
PatientPageHeader, LoadingView, ErrorState, EmptyState; MePage/MeCard/MeMenuTile và
RecordsPage/RecordCard; navigation dùng MainShell với nested navigator, CatalogNavigation,
MeRoutes và RecordsRoutes. Dialog/bottom sheet dùng Material theme và choosePhoto.

Phát hiện: Me và Catalog ghi đè theme bằng nút đen/gray; màu xanh/gray lặp lại;
AppCard blur mọi card; padding AppBar cứng 56/80; service carousel và stepper cố định
chiều cao; footer doctor/total dễ overflow ở scale 1.5. Thay đổi chỉ ở presentation.

## B. Screens đã chỉnh hoặc được đồng bộ qua theme/component

- Home: giữ section và dữ liệu, service/doctor/article mỗi nhóm tự tính chiều cao.
- Appointments/Lịch hẹn, Records overview và trang chi tiết hồ sơ dùng RecordsPage.
- Service List/Detail, Doctor List/Detail, Article List/Detail.
- Booking: chọn dịch vụ, bác sĩ, ngày giờ, xác nhận, ghi chú, voucher, summary/success.
- Tôi và tất cả route hiện có: thông tin cá nhân, danh sách/form người thân, thông báo,
  cài đặt, ngôn ngữ, đổi mật khẩu, quyền riêng tư, trợ giúp, đã lưu; trang chi tiết mở từ Đã lưu.
- Welcome, Login, Register, Forgot password; branding hiển thị YourSmile Dental.
- Dialog và sheet kế thừa theme; photo source sheet có scroll.

## C. File đã thay đổi trong lượt UI

Các file state/auth còn xuất hiện trong git diff thuộc công việc trước lượt này và
được giữ nguyên. Bảng sau liệt kê các file presentation của lượt UI.

| Path | Thay đổi |
|---|---|
| `frontend/lib/app.dart` | Tên hiển thị YourSmile Dental. |
| `frontend/lib/app/main_shell.dart` | Style bottom navigation đồng bộ, bỏ blur và thêm SafeArea; giữ callback/tab. |
| `frontend/lib/core/constants/app_colors.dart` | Palette tím pastel, màu nền, chữ, border và disabled. |
| `frontend/lib/core/theme/app_text_styles.dart` | Hierarchy 20/18/16/14/12, giữ system text scaling. |
| `frontend/lib/core/theme/app_theme.dart` | Theme button/input/card/AppBar/dialog/sheet/chip/states. |
| `frontend/lib/core/theme/app_tokens.dart` | Token spacing, radius, chiều cao tối thiểu và shadow dùng chung. |
| `frontend/lib/core/widgets/app_card.dart` | Card nhẹ, border/shadow chung; bỏ blur đại trà. |
| `frontend/lib/core/widgets/empty_view.dart` | Icon gọn hơn, nội dung có thể cuộn khi thiếu chiều cao. |
| `frontend/lib/core/widgets/error_state.dart` | Icon gọn hơn, nội dung có thể cuộn khi thiếu chiều cao. |
| `frontend/lib/core/widgets/glass_selection_card.dart` | Blur 4px có giới hạn vùng, Material cho ink của option chi tiết. |
| `frontend/lib/core/widgets/horizontal_card_carousel.dart` | Chiều cao theo card cao nhất; hỗ trợ điều hướng ở chế độ nội dung tự giãn. |
| `frontend/lib/core/widgets/network_image_or_icon.dart` | Alignment ảnh tùy chọn, giữ BoxFit.cover. |
| `frontend/lib/core/widgets/page_background.dart` | Gradient nền tái sử dụng. |
| `frontend/lib/core/widgets/primary_button.dart` | Giữ nguyên kích thước khi loading; nhãn/icon có thể wrap. |
| `frontend/lib/core/widgets/secondary_button.dart` | Cho nhãn cạnh icon co giãn. |
| `frontend/lib/features/articles/article_detail_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/auth/auth_brand.dart` | Gradient/branding/logo tím, input/button theo theme và form có thể cuộn. |
| `frontend/lib/features/auth/forgot_password_screen.dart` | Gradient/branding/logo tím, input/button theo theme và form có thể cuộn. |
| `frontend/lib/features/auth/login_screen.dart` | Gradient/branding/logo tím, input/button theo theme và form có thể cuộn. |
| `frontend/lib/features/auth/register_screen.dart` | Gradient/branding/logo tím, input/button theo theme và form có thể cuộn. |
| `frontend/lib/features/auth/welcome_screen.dart` | Gradient/branding/logo tím, input/button theo theme và form có thể cuộn. |
| `frontend/lib/features/booking/booking_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/booking/booking_success_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/booking/steps/confirm_booking_step.dart` | Input theo theme, chữ dễ đọc, tổng tiền dùng Wrap. |
| `frontend/lib/features/booking/steps/select_datetime_step.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/booking/steps/select_doctor_step.dart` | Card bác sĩ theo nội dung, footer nhiều dòng ở text scale lớn. |
| `frontend/lib/features/booking/steps/select_services_step.dart` | Metadata/giá dùng Wrap; giữ callback chọn dịch vụ. |
| `frontend/lib/features/booking/widgets/booking_price_summary.dart` | CTA tối thiểu 48 và màu chữ đồng bộ. |
| `frontend/lib/features/booking/widgets/booking_stepper.dart` | Bỏ chiều cao cố định, nhãn bước tự giãn. |
| `frontend/lib/features/doctors/doctor_detail_screen.dart` | Hierarchy gọn, màu chung, option liên quan có light glassmorphism. |
| `frontend/lib/features/me/api_notifications_view.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/me/email_verification_card.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/me/family_list_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/me/health_info_section.dart` | Selected chip/switch tím, giữ toàn bộ validation và state. |
| `frontend/lib/features/me/help_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/me/language_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/me/me_screen.dart` | Bỏ theme riêng, các menu/callback giữ nguyên; detail không dùng offset AppBar cứng. |
| `frontend/lib/features/me/me_widgets.dart` | MePage/MeCard/menu/avatar theo theme và SafeArea. |
| `frontend/lib/features/me/notifications_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/me/saved_items_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/me/settings_screen.dart` | Switch tím; bỏ đoạn chỉ giải thích nguồn lưu dữ liệu. |
| `frontend/lib/features/records/appointment_api_status.dart` | Ẩn riêng nhãn nguồn dữ liệu, giữ hàm reload API. |
| `frontend/lib/features/records/appointment_detail_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/records/appointments_screen.dart` | Tên người khám trên cùng bên trái; chỉ hiện avatar khi có ảnh thật. |
| `frontend/lib/features/records/exam_result_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/records/followup_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/records/payment_receipt_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/records/prescription_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/records/records_home_screen.dart` | Card từng nhóm tự giãn, typography/spacing, CTA responsive và tương phản trên nền tím. |
| `frontend/lib/features/records/records_widgets.dart` | Layout SafeArea, padding dùng token, AppBar và card nhẹ. |
| `frontend/lib/features/records/treatment_photos_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/records/visit_detail_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/records/visit_history_screen.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/services/service_detail_screen.dart` | Hierarchy gọn, màu chung, option liên quan có light glassmorphism. |
| `frontend/lib/features/shared/catalog_navigation.dart` | Giữ nguyên push/navigation, bỏ gray theme riêng và dùng nền chung. |
| `frontend/lib/features/shared/person_avatar.dart` | Thay màu hard-code bằng token theme; giữ nguyên dữ liệu và hành vi. |
| `frontend/lib/features/shared/photo_source_sheet.dart` | Sheet có thể cuộn ở màn hình thấp/text scale lớn, không đổi action. |
| `frontend/lib/screens/home/home_screen.dart` | Card từng nhóm tự giãn, typography/spacing, CTA responsive và tương phản trên nền tím. |

Test thêm/cập nhật:

- `frontend/test/ui_responsive_test.dart`: 9 cấu hình width/text scale; Home/tabs,
  auth + keyboard, detail/list/appointments, toàn bộ trang con Me và các bước Booking.
- `frontend/test/ui_components_test.dart`: kích thước loading button và photo sheet cuộn.
- `frontend/test/me_test.dart`, `frontend/test/profile_fields_test.dart`: finder theo
  AppCard đang dùng; không thay assertion dữ liệu hoặc validation.

## D. Responsive fixes

- Carousel lấy chiều cao từ nội dung cao nhất trong cùng group, không dùng công thức
  cộng pixel theo text scale; ảnh giữ kích thước và BoxFit.cover.
- Doctor name/specialty một dòng ellipsis; article title hai dòng, Spacer giữ footer ở đáy.
- Footer bác sĩ chọn lịch tách dòng, tổng tiền và metadata dịch vụ dùng Wrap.
- Stepper bỏ height 58; SafeArea thay padding bù AppBar cố định; navigation có safe inset.
- Login/Register dùng PrimaryButton giữ kích thước khi loading; form cuộn khi keyboard mở.
- Kiểm tra field/CTA hồ sơ, form người thân, password, voucher và note với inset 280.
- Không dùng ClipRect/OverflowBox/giảm text scaling để che overflow. ClipRRect chỉ dùng
  bo ảnh hoặc giới hạn vùng glass theo thiết kế.

## E. Logic verification

Lượt UI không thay đổi endpoint, request/response model, auth, provider, controller,
repository, validation, callback chọn dịch vụ/bác sĩ, booking hoặc navigation flow.
Đối chiếu SHA-256 với đầu lượt UI: không có thay đổi trong các file provider,
controller, data service/model và backend. Các fix auth từ lượt trước được giữ nguyên.
Không thêm package, dữ liệu mock trong production, cấu hình Firebase hay identifier.

## F. Validation

- `flutter analyze`: No issues found.
- UI/form suite: 62 passed, 1 skipped theo điều kiện có sẵn.
- Auth/API/booking regression suite: 80 passed, 1 skipped theo điều kiện có sẵn.
- `git diff --check`: sạch.
- Widget layout: width 320/360/411, text scale 1.0/1.3/1.5; inset keyboard 280.
- Test sử dụng API fixtures, không thay dữ liệu API thật trong production.
- Build/run Android emulator thành công; đã xem Home và Tôi với dữ liệu API hiện có.

Lệnh kiểm tra:

```sh
flutter analyze
flutter test test/ui_responsive_test.dart test/ui_components_test.dart test/me_test.dart test/profile_fields_test.dart
flutter test --dart-define=DATA_SOURCE=api test/account_switch_test.dart test/session_response_test.dart test/private_session_test.dart test/booking_api_sync_test.dart test/booking_idempotency_api_test.dart test/booking_pricing_race_test.dart test/auth_test.dart test/api_foundation_test.dart test/session_bootstrap_test.dart
flutter run -d emulator-5554 --no-resident
```

## G. Chưa kiểm tra được

Chưa thao tác thủ công toàn bộ flow trên device thật hoặc iOS; chưa tạo tài khoản,
đặt lịch, áp voucher hay upload ảnh thật qua backend trong lượt UI. Các flow này được
kiểm tra bằng automated fixtures. Ma trận width/scale đầy đủ là widget test, không phải
9 lần đổi cấu hình emulator; chưa benchmark GPU/performance blur trên thiết bị yếu.
