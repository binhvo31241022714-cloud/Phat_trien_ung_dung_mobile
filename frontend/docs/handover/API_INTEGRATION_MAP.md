# Bản đồ tích hợp API — đề nghị từ frontend, chưa phải contract backend

## Trạng thái xác minh

Prompt 11 không gọi hoặc thay đổi backend. Thông tin sau là bằng chứng lịch sử
Prompt 10 trong `qa_artifacts/prompt10/http_read_probe.json`:

| Endpoint đã có | Xác minh trước đây | Giới hạn |
|---|---|---|
| GET /api/health | Host và Android trả 200, data.status=up | Không xác minh Firebase/database |
| GET /api/users | Host và Android trả 200, data=[] | User legacy trong RAM, không phải bệnh nhân/auth |
| GET /api/users/:id | Đã kiểm tra 400 ID sai, 404 ID không có; đọc ID có trong test cô lập | Không suy ra user thật tồn tại |
| POST /api/users; PUT/DELETE /api/users/:id | CRUD đạt trong server test bộ nhớ riêng | Không ghi vào server 8080; không dùng trong luồng bệnh nhân |

Không có contract chính thức đã được bàn giao cho nội dung, Auth, lịch hẹn hoặc hồ
sơ. Các probe cũ cho services/doctors/articles/patients/appointments trả 404 chỉ
phản ánh thời điểm Prompt 10; không tuyên bố trạng thái server hiện tại. Không
đặt URL dự kiến cho module mới trong tài liệu này.

## Các điểm bàn giao

Các đường dẫn Screen trong bảng nằm dưới `lib/`. API cần tích hợp là chức năng
mong đợi; mọi dòng ngoài user legacy/health đều **chưa có contract**, không phải
endpoint đã triển khai hoặc đã tích hợp.

| Module | Screen | Provider/Service | Model | Mock source | API cần tích hợp | Người phụ trách |
|---|---|---|---|---|---|---|
| Auth/tài khoản | features/auth/*, features/me/edit_profile_screen.dart | UserProvider; đồng bộ primaryPatient qua PatientDataProvider | UserModel, Patient | UserProvider._account, MockData.patients | Login/register/reset/current profile, session/token/permissions | Bình |
| Người thân | features/me/family_*; selector booking/records | PatientDataProvider | Patient | MockData.patients, RAM mutations | Danh sách/thêm/sửa/xóa hồ sơ có quyền truy cập | Bình |
| Dịch vụ | features/services/*, Home, booking | PatientDataProvider | DentalService | MockData.services | Danh sách/chi tiết, giá, thời lượng, popular | Bình |
| Bác sĩ | features/doctors/*, Home, booking | PatientDataProvider | Doctor | MockData.doctors | Danh sách/chi tiết, chuyên khoa, ảnh | Bình |
| Bookmark | features/me/saved_items_screen.dart; các chi tiết/list | PatientDataProvider | Tập ID article/service/doctor | RAM sets | Đọc/thêm/bỏ lưu theo user và loại đối tượng | Bình, phối hợp Nhi cho article UI |
| Đặt/hủy lịch | features/booking/*, records/appointment* | BookingController, PatientDataProvider | Appointment, AppointmentStatus | MockData.appointments, RAM mutations | Availability, quote/voucher, submit idempotency, list/detail/cancel | Phương |
| Hồ sơ khám | features/records/visit*, exam_result*, prescription*, payment_receipt* | PatientDataProvider | Visit, Prescription, Receipt | MockData.visits/prescriptions/receipts | Theo patient có phân quyền, chi tiết/kết quả/thuốc/hóa đơn | Ngân |
| Liệu trình/tái khám | features/records/treatment*, followup* | PatientDataProvider | TreatmentPlan, Followup | MockData.treatmentPlans/followups | Tiến độ/buổi, ảnh trước-sau, gợi ý tái khám | Ngân |
| Bài viết | features/articles/*, shared/article_card.dart | PatientDataProvider; chưa content repository | Article | MockData.articles | List/detail, paging, thứ tự/featured, nội dung/ảnh | Nhi |
| Nội dung Home | screens/home/home_screen.dart | PatientDataProvider | Patient, Appointment, DentalService, Doctor, Article | Các tập mock tương ứng | Nhi phối hợp đọc catalog Bình, lịch Phương, nội dung bài viết; chưa yêu cầu endpoint tổng hợp riêng | Nhi |
| Thông báo | features/me/notifications_screen.dart; chuông Home | PatientDataProvider, UserProvider.receiveNotifications | PatientNotification | MockData.notifications | List/filter/paging, mark-read, đích liên kết có quyền truy cập | Nhi |
| User legacy | screens/user/* | UserProvider → UserService → UserReadRepository → ApiClient | UserModel | MockUserReadRepository rỗng | Đã có API legacy, không nối với tài khoản bệnh nhân | Bình xem xét phạm vi/bảo vệ route |

## Quy tắc khi có contract

- Chốt method/path, envelope, phân trang, field null/missing, kiểu ID, format ngày
  và timezone, tiền VND, enum trạng thái, lỗi và quyền truy cập trước khi viết DTO.
- Không lấy schema Dart frontend làm schema bắt buộc của Firestore/backend.
- Thêm mapping tại data/repositories hoặc DTO khi cần; giữ public API Provider để
  không đổi thiết kế màn hình. Không tạo PatientDataProvider thứ hai.
- Không fallback sang mock khi API lỗi; phải có loading/error/retry/empty rõ ràng.
- Tách mock fixtures khỏi dữ liệu người dùng. Không sinh token giả; auth thật do Bình.
- Content API và read-status phải được kiểm tra với backend bàn giao trước khi
  bật; hiện tại chỉ mock. Trường mong đợi chi tiết tại CONTENT_MODULE_HANDOVER.md.
