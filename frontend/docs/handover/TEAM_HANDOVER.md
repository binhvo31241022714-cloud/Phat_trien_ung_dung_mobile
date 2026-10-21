# Bàn giao theo thành viên

Tất cả giữ Mock Mode mặc định, UI/card/spacing/colors hiện có, một Bottom
Navigation, navigator con và Back theo tab. Không sửa module ngoài phân công.
Mọi API bên dưới là điểm cần bàn giao, chưa có contract xác nhận.

## Bình — Auth, tài khoản, người thân, dịch vụ, bác sĩ, bookmark

- Files: `lib/features/auth/`, `lib/features/me/{edit_profile,family_list,family_form,saved_items}_screen.dart`,
  `lib/features/services/`, `lib/features/doctors/`, `lib/providers/user_provider.dart`,
  `lib/data/providers/patient_data_provider.dart`, `lib/data/services/user_service.dart`,
  `lib/data/repositories/user_read_repository.dart` và `lib/core/{config,network}/`.
- Models: UserModel, Patient, DentalService, Doctor; bookmark Set String ID cho ba loại.
- UserProvider.account là tài khoản; selectedPatient/recordsPatient là người được
  khám. User legacy API không phải auth, không dùng ID int legacy làm patientId String.
- Điểm tích hợp: session/profile, family CRUD có quyền, catalog và bookmark theo tài khoản.
- Checklist: login/logout xóa stack đúng; không lưu password thô; sửa người thân
  giữ ID; xóa hồ sơ liên kết có chính sách; dropdown booking/records cập nhật;
  đổi bệnh nhân không đổi account; bookmark Home/chi tiết/Đã lưu đồng bộ; lỗi mạng
  không báo thành công. Phối hợp Nhi với UI bookmark bài viết.

## Phương — Đặt lịch, availability, voucher, hủy lịch

- Files: `lib/features/booking/`, `lib/features/records/appointments_screen.dart`,
  `appointment_detail_screen.dart`, `lib/screens/home/home_screen.dart` (chỉ điểm
  hiển thị lịch), `lib/data/providers/patient_data_provider.dart`.
- Models: Appointment/AppointmentStatus, Patient, Doctor, DentalService.
- Điểm tích hợp: availability theo bác sĩ/dịch vụ, voucher/quote, submit, cancel;
  không dùng slots 30 phút demo làm lịch trống thật.
- Checklist: bốn bước giữ draft; nhiều dịch vụ đúng tổng; timezone được chốt;
  chống submit trùng ở server; chỉ thêm lịch sau thành công thật; trạng thái enum
  có mapping; cancel cập nhật Hồ sơ/Home/thông báo; logout/dispose không tạo lịch ma.

Home hiện minh họa giờ kết thúc bằng scheduledAt + 30 phút. Phương và Nhi cần
thống nhất thời lượng/slot từ contract trước khi hiển thị giờ kết thúc thực tế;
Prompt 11 không tự đổi quy tắc thời gian hoặc layout này.

## Ngân — Hồ sơ, lịch sử, đơn thuốc, hóa đơn, liệu trình, tái khám

- Files: `lib/features/records/` (phối hợp Phương cho appointments),
  `lib/data/models/patient_records.dart`, `lib/data/providers/patient_data_provider.dart`.
- Models: Visit, Prescription/PrescriptionItem, Receipt/ReceiptItem,
  TreatmentPlan/TreatmentSession, Followup; các khóa patientId/visitId/appointmentId.
- Điểm tích hợp: records theo bệnh nhân có phân quyền; chi tiết, kết quả/thuốc,
  hóa đơn, tiến độ, ảnh và gợi ý tái khám. Không tự tạo dữ liệu lâm sàng thiếu.
- Checklist: đổi người khám lọc đúng; không lẫn tài khoản và bệnh nhân; liên kết
  thiếu hiển thị thiếu; chỉ đọc nếu chưa có API ghi; không tự gán bác sĩ hoặc
  hóa đơn đầu tiên; ảnh lỗi có fallback; tái khám chuyển booking đúng patient.

## Nhi — Frontend chính, Home, bài viết, thông báo

- Files: `lib/app.dart`, `lib/app/`, `lib/routes/app_routes.dart`, `lib/core/theme/`,
  `lib/screens/home/home_screen.dart`, `lib/features/articles/`,
  `lib/features/shared/article_card.dart`, `lib/features/me/notifications_screen.dart`,
  `lib/data/models/article.dart`; phối hợp trong Provider/models shared.
- Models: Article, PatientNotification; đọc Patient/Appointment/Service/Doctor
  để compose Home, không tiếp quản nghiệp vụ backend của các nhóm đó.
- Điểm tích hợp: fields/content list/detail/featured, images và notification
  list/read-status. Xem CONTENT_MODULE_HANDOVER.md; chưa tạo content endpoint/FCM.
- Checklist: article mở đúng/Back; bookmark với Bình đồng bộ; Home giữ đúng
  sections; thông báo filter/read/empty/link thiếu; không mô tả mock như push thật;
  kích thước 360/390/430; chữ lớn, keyboard, Back/tab/logout; không stretch.

## Quy tắc phối hợp chung

Trước khi chỉnh file dùng chung, kiểm tra git diff và trao đổi người phụ trách.
Không revert cả file để bỏ một thay đổi vì nhiều file đang chứa công việc chưa
commit từ các bước trước. Không tạo commit tự động. Hai file backend còn chờ
review được ghi riêng tại PENDING_BACKEND_REVIEW.md; frontend không hoàn tác chúng.

Nghiệm thu tối thiểu: formatter, flutter analyze, toàn bộ flutter test, Mock Mode
độc lập backend, kiểm tra Android đúng module; ghi rõ test nào giả lập HTTP và
kiểm tra nào gọi server thật. Không suy ra tích hợp thật từ unit test.
