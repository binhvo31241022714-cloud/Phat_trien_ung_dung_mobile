> Kết quả tiếp theo ngày 31/10/2026: đã xử lý 41 test lỗi; xem [bảng phân loại và kết quả hiện hành](API_MODE_41_TEST_REVIEW.md). Số 301/41 ở dưới là snapshot trước đợt tiếp theo, không phải trạng thái mới nhất.

# Báo cáo tích hợp sau audit 962a981 — 31/10/2026

Mốc 962a981 do người dùng cung cấp; không dùng Git để kiểm tra hoặc thao tác trong nhiệm vụ này. Đọc và sửa workspace hiện tại. Không đọc secret, không ghi Firebase thật, không sửa dependency, Rules, IAM hoặc code backend Module 1–3.

## 1. Tóm tắt và phạm vi

Đã xử lý 5 test API-mode ban đầu, cùng các nhóm A06, A16, A19 và A15 ở frontend. A21 được xử lý bảo thủ ở UI: dữ liệu API thiếu status không còn bị khẳng định hoàn tất; hợp đồng status lâm sàng vẫn chờ Ngân xác nhận. A22 có runbook hiện hành và đánh dấu tài liệu cũ là lịch sử.

Ba mục cần duyệt thay đổi liên module: A05 (API lấy người thân archived), A08 (liên kết follow-up trong booking), A10 (nguồn sự thật để hoàn tất session). Ba mục chỉ lập thiết kế/fixture/phạm vi: A03, A09, A23. Không triển khai worker hoặc FCM.

Rủi ro cần review: trường ngày Records nay nullable; `Receipt.appointmentId` nullable và thêm `visitId` độc lập; lịch API được biểu diễn bằng UTC instant và chỉ đổi sang giờ phòng khám ở bước hiển thị. Không đổi JSON API hoặc schema Firestore. Ngân review Records; Phương review tích hợp thời gian booking; Bình review helper test Profile.

## 2. Tái hiện 5 lỗi ban đầu

Lệnh chính xác (chạy tại `frontend/`):

```sh
flutter test --dart-define=DATA_SOURCE=api test/appointment_refresh_api_test.dart test/appointment_status_test.dart test/booking_idempotency_api_test.dart test/booking_shortcut_test.dart test/family_archive_test.dart test/profile_fields_test.dart test/validators_test.dart
```

Kết quả trước sửa: **34 PASS, 5 FAIL, 0 SKIP**.

| Test | Thông báo/stack chính | Root cause và cách sửa |
|---|---|---|
| family_archive: delete dialog says old records are kept; 409 shows the server message | ProviderNotFoundException: Provider<ContentProvider>, `_HomeOverview.build`, `home_screen.dart:61`, `Provider.of`, `pumpMe` | Helper test không cung cấp Module 4 mà MainShell API sử dụng. Thêm ContentProvider dùng MockClient, không thay code ứng dụng. |
| profile_fields: add family: +84 phone is normalized, birthday is optional | Cùng stack ProviderNotFoundException | Cùng nguyên nhân/helper. |
| profile_fields: edit family: +84 phone is normalized, no birthday needed | Cùng stack ProviderNotFoundException | Cùng nguyên nhân/helper. |
| profile_fields: profile: +84 phone is normalized, birthday is optional | Cùng stack ProviderNotFoundException | Cùng nguyên nhân/helper. |
| profile_fields: notification switch says it is a local option only (A18) | Cùng lỗi provider; sau bổ sung provider xuất hiện kỳ vọng sai `find.textContaining('chưa gửi thông báo đẩy')` trên màn API | Cung cấp fake dependency và tách kỳ vọng mock/API. Settings vẫn bắt buộc ghi rõ tùy chọn local; màn API chưa đăng nhập phải yêu cầu đăng nhập. |

Phân loại: lỗi setup/mock dependency và một kỳ vọng UI phụ thuộc mode; không phải bằng chứng lỗi API contract hoặc môi trường Firebase. Không xóa hoặc bổ sung skip cho các test này.

## 3. Bảng 24 hạng mục

PASS dưới đây là phạm vi unit/widget/fake đã chứng minh; không có nghĩa Firebase E2E PASS.

| ID | Trước | Sau | File sửa/chứng cứ | Đánh giá |
|---|---|---|---|---|
| A01 | Đã có staff transition | Giữ nguyên | backend/test/module2/staff-status.test.cjs | PASS regression |
| A02 | Có generator confirmed | Giữ nguyên transaction + ID cố định | staff-status.test.cjs; retry transition bị 409, không tạo thêm notice | PASS regression |
| A03 | Chưa có reminder | Chỉ thiết kế bên dưới | Không sửa worker | BLOCKED quyết định triển khai |
| A04 | Đã có sync CRUD | Giữ nguyên; sửa setup test | family_archive_test.dart, me_test.dart | PASS regression |
| A05 | Soft delete, app không truy cập hồ sơ archived | Không đổi API; đề xuất mở rộng có kiểm soát | API family hiện lọc archived, Records cần patient selector | BLOCKED duyệt Bình/Ngân |
| A06 | Gộp visitId vào appointmentId | Hai ID nullable độc lập, lookup theo visit và patient; không cần cache lịch | patient_records.dart, visit_detail_screen.dart, payment_receipt_screen.dart; records_audit_test.dart, records_audit_ui_test.dart | PASS |
| A07 | Đã refresh detail | Giữ nguyên; notification dùng detail được phân quyền | appointment_refresh_api_test.dart (kỳ vọng đổi từ list call sang detail call) | PASS regression |
| A08 | Không lưu followUpId | Đề xuất contract, chưa sửa luồng ghi | Theo dõi FollowupScreen → BookingRequest → BookingService → appointments.js | BLOCKED duyệt Phương/Ngân |
| A09 | Thiếu bộ nghiệm thu xác nhận | Fixture local đề xuất, chưa nạp Firebase | test/fixtures/clinical_acceptance.json | PARTIAL |
| A10 | Link-visit tự completed | Giữ nguyên nghiệp vụ theo giới hạn giao việc; rủi ro còn tồn tại | treatments.js transaction; đề xuất bên dưới | BLOCKED duyệt Ngân/Phương |
| A11 | Đã có idempotency | Giữ nguyên | idempotency-note.test.cjs, booking_idempotency_api_test.dart | PASS regression |
| A12 | Đã có test booking giả | Chạy lại 87 test backend | booking-flow/scheduling/staff-status/idempotency-note suites | PASS fake; Firebase chưa nghiệm thu |
| A13 | Đã lưu note | Giữ nguyên | idempotency-note.test.cjs (max 500), test booking Flutter | PASS regression |
| A14 | Unknown đã có nhãn | Giữ nguyên | appointment_status_test.dart | PASS regression |
| A15 | Date/time ghép theo thiết bị | UTC instant từ date/time UTC+7; hiển thị giờ phòng khám; date picker dùng ngày phòng khám | clinic_time.dart, appointment.dart, home_appointment.dart, BookingController và UI; records_audit_test.dart | PASS unit; thiết bị thật chưa chạy |
| A16 | Records fallback epoch | Nullable ngày visit/prescription/invoice/followup; ngày lỗi hiển thị Chưa cập nhật, null sort cuối | patient_records.dart, formatters.dart, PatientDataProvider, followup_screen.dart, records_widgets.dart; records_audit tests | PASS |
| A17 | Đã validate Profile | Giữ nguyên; test setup sửa | profile_fields_test.dart, validators_test.dart | PASS frontend regression; chưa Firebase |
| A18 | Đã ghi tùy chọn local | Giữ nguyên, test đúng từng mode | profile_fields_test.dart | PASS |
| A19 | Mark-read lỗi chặn mở | Mark-read độc lập, tải detail khi cache rỗng, chặn stale session/401/403/404 | api_notifications_view.dart, ContentProvider session guard; appointment_refresh_api_test.dart | PASS |
| A20 | Đã query ca theo ngày | Giữ nguyên | scheduling.test.cjs | PASS regression |
| A21 | Visit luôn completed, liệu trình suy từ số buổi, result luôn minh họa | API thiếu status hiện chưa cập nhật; nhãn minh họa chỉ mock, progress chỉ là số buổi | visit_history_screen.dart, treatment_detail_screen.dart, exam_result_screen.dart; records_audit_ui_test.dart | PARTIAL: thiếu contract status; chưa map enum mới |
| A22 | Handover còn backend Dart/baseline cũ | Runbook này là hiện hành, tài liệu Nhi cũ gắn thông báo lịch sử | 8 tài liệu handover và báo cáo này | PASS phạm vi tài liệu Nhi; tài liệu thành viên khác chỉ đề xuất |
| A23 | Chưa FCM | Đánh giá phạm vi, không cài | Mục thiết kế dưới đây | PARTIAL theo phạm vi |
| A24 | Đã có CTA | Không sửa CTA/carousel | booking_shortcut_test.dart xác minh doctor/service/combo giữ ID | PASS CTA; carousel ngoài phạm vi |

## 4. Runbook hiện hành

Backend: Node.js/Express + firebase-admin, xác thực Firebase token, mọi dữ liệu Flutter qua API; không truy cập Firestore trực tiếp. `DATA_SOURCE` runtime mặc định `api`; test runner mặc định mock trừ khi truyền dart-define. Test API ở đây vẫn dùng HTTP giả.

Khởi động backend do người vận hành thực hiện tại `backend/` bằng `npm start`, sau khi tự chuẩn bị thông tin xác thực hợp lệ. Không in secret hoặc token vào chat/log. Backend local dự kiến cổng 3000 theo cấu hình dự án và yêu cầu người dùng; xác nhận cấu hình tại máy demo trước chạy.

```sh
# frontend, Android Emulator
flutter run --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:3000
# frontend, xem dữ liệu mẫu
flutter run --dart-define=DATA_SOURCE=mock
# backend, kiểm thử trong bộ nhớ
node --test test/module2/*.test.cjs test/module3/*.cjs test/module4/*.cjs
```

`localhost:3000` dùng cho client chạy trên máy host; emulator Android dùng `10.0.2.2:3000`. Không dùng lệnh seed hoặc request ghi trên Firebase thật trong đợt sửa này.

## 5. Các quyết định cần duyệt

### A05 — Bình/Ngân: danh sách người thân archived chỉ đọc

GET `/api/family-members?includeArchived=true` trả thêm `isArchived`, mặc định giữ response hiện tại. Chỉ chủ tài khoản được lấy. Records selector chia đang hoạt động/đã lưu trữ; booking chỉ dùng danh sách active. Không phục hồi hoặc xóa lịch sử. Cần Bình duyệt query/response, Ngân xác nhận quyền đọc hồ sơ archived và Nhi thêm selector. Test: account khác 403; archived đọc được visits/invoices; POST booking archived vẫn 400; CRUD không phục hồi ngầm. Contract hiện tại không đủ để liệt kê mọi người thân archived (không thể dựa cache lịch hẹn để tìm đủ người).

### A08 — Phương/Ngân: followUpId

Đề xuất POST `/api/appointments` thêm `followUpId?: string`, response trả cùng ID. Không có trường này giữ nguyên hành vi. Transaction đọc `follow_ups/{id}`, kiểm tra quyền sở hữu/account, cùng patientId, serviceId đúng danh mục, dữ liệu active; không tin accountId client. followUpId tham gia fingerprint idempotency; cùng key cùng nội dung trả cùng lịch, khác followUpId trả 409.

Cần chốt quan hệ một follow-up có nhiều lần đặt lại hay chỉ một lịch active. Đề xuất cho nhiều lịch lịch sử nhưng tối đa một lịch active, giữ liên kết trên appointment, không xóa liên kết khi hủy. Chưa thêm field hoặc write/index thực tế. Files cần duyệt: patient_navigation.dart BookingRequest, booking_controller.dart, booking_service.dart, backend appointments.js + follow-up validation và transaction. Test: follow-up người khác/patient khác/service khác, retry đồng thời, hủy/đặt lại, key khác nhưng follow-up đã có lịch active.

### A10/A21 — Ngân/Phương: nguồn trạng thái lâm sàng

Backend hiện không khai báo enum visit/treatment ở routes; routes trả document, model Visit chưa có status. Đề xuất chốt appointment.status=completed là điều kiện tối thiểu để link làm completed, hoặc link chỉ gắn quan hệ và để staff hoàn tất session qua luồng riêng. Đây là thay đổi nghiệp vụ, chưa triển khai.

Nếu chọn kiểm tra appointment: transaction phải đọc appointment của visit, xác nhận accountId/patientId trùng và status completed trước khi ghi; giữ kiểm tra double-link, retry transaction và quyền hiện có. Test pending/confirmed/rejected/cancelled/missing appointment đều không ghi completed; completed đúng patient được link; cạnh tranh giữ nguyên atomicity. Không cho bệnh nhân quyền cập nhật trạng thái.

A21 cần Ngân xác nhận enum chính thức visit/treatment (completed, pending, in-progress, unknown/missing có được hỗ trợ không). Hiện UI không gán những giá trị này bằng suy đoán. Chưa có bằng chứng để nghiệm thu đầy đủ trạng thái completed/pending/in-progress.

### A03 — Thiết kế reminder, chưa triển khai

Đề xuất nhắc trước 24 giờ qua hộp thư trong app, chỉ lịch confirmed và tương lai. Một tiến trình scheduler nội bộ gọi worker backend hoặc scheduled Cloud Function; chọn sau khi biết nơi hosting, không chạy scheduler trên Flutter. Chu kỳ đề xuất 5 phút, dùng khoảng đến hạn và checkpoint bền vững để xử lý downtime; bỏ lịch đã bắt đầu.

Mỗi nhắc có khóa ổn định `appointmentId + scheduledInstant + reminderKind`; transaction đọc lại appointment confirmed, ngày giờ/version chưa đổi rồi tạo notification nếu khóa chưa tồn tại. Chạy lại không trùng. Hủy/đổi giờ phải vô hiệu hóa nhắc cũ hoặc đánh dấu không còn hợp lệ; thao tác này ảnh hưởng booking nên cần Phương duyệt. Nếu gửi push về sau, cần outbox và kiểm tra lại trước gửi; không hứa có thể thu hồi một push đã gửi trước lúc hủy. Test fake clock: đúng ngưỡng, retry, hai worker, hủy đồng thời, đổi giờ, downtime, timezone. Chi phí phụ thuộc số lượt quét/read/write, tần suất và nền tảng; chưa có báo giá hoặc cấu hình production được xác nhận.

### A09 — Fixture và quyền truy cập

Fixture chỉ ở `frontend/test/fixtures/clinical_acceptance.json`, chưa được ghi lên Firebase. Có account → archived relative → completed appointment → visit → prescription/invoice, treatment/session và follow-up cùng patient. Visit và appointment cố ý dùng hai ID khác nhau. Nhãn/thuốc đều là dữ liệu kiểm thử, không dùng lâm sàng. Đây là bản đề xuất để Ngân duyệt, không phải bộ seed production.

Cần thêm service/doctor catalog hợp lệ hoặc map ID vào catalog emulator trước demo; ngày phải chọn lại theo kịch bản. Nghiệm thu trên emulator trước: owner xem được từng GET, account khác 403, chưa auth 401; archived vẫn đọc được nhưng không đặt mới, hóa đơn mở đúng visit; thử ngày thiếu/sai; follow-up chưa liên kết phải ghi rõ. Chưa nghiệm thu Firebase thật hoặc luồng nhập hồ sơ.

### A23 — Phạm vi FCM

Chưa triển khai. Cần quyền OS, đăng ký/thu hồi device token theo account, xử lý foreground/background/terminated, deep-link sau login, xoá token khi logout, gửi từ backend có quyền và test Android/iOS thật. Cần duyệt dependency, Firebase config, môi trường gửi và chi phí vận hành riêng. Hộp thư API hiện không đồng nghĩa push.

### A24 — CTA và carousel

CTA bác sĩ/dịch vụ/combo giữ ID từ catalog API, được regression bằng booking_shortcut_test.dart. Không thay carousel; cần spec auto-play, số card, điều khiển, responsive/accessibility nếu muốn nghiệm thu thêm.

## 6. Danh sách file và quyền sở hữu

Các đường dẫn dưới đây tính từ `frontend/`:

| File | Mục đích | Review |
|---|---|---|
| lib/core/utils/clinic_time.dart | UTC+7 wall time và instant | Nhi/Phương |
| lib/core/utils/formatters.dart | Hiển thị ngày nullable | Nhi/Ngân |
| lib/data/models/patient_records.dart | Receipt IDs, nullable dates, lookup | Nhi/Ngân |
| lib/data/models/appointment.dart, home_appointment.dart | Parse clinic slot thành instant, display getters | Nhi/Phương |
| lib/data/providers/patient_data_provider.dart | Sort ngày null cuối | Nhi/Ngân |
| lib/features/booking/booking_controller.dart, steps/select_datetime_step.dart, booking_success_screen.dart | Ghép slot, ngày phòng khám và hiển thị | Nhi/Phương |
| lib/screens/home/home_screen.dart | Hiển thị giờ/ngày phòng khám | Nhi |
| lib/features/me/api_notifications_view.dart | Mở detail độc lập mark-read và session guard | Nhi |
| lib/features/me/notifications_screen.dart | Hiển thị lịch theo giờ phòng khám | Nhi |
| lib/providers/content_provider.dart | Expose session guard đọc-only | Nhi |
| lib/features/records/payment_receipt_screen.dart, visit_detail_screen.dart | Lookup receipt/visit/patient đúng ID | Nhi/Ngân |
| lib/features/records/records_widgets.dart, followup_screen.dart | Ngày null có trạng thái UI rõ | Nhi/Ngân |
| lib/features/records/visit_history_screen.dart, treatment_detail_screen.dart, exam_result_screen.dart | Không khẳng định trạng thái API thiếu; giữ demo label cho mock | Nhi/Ngân |
| test/me_test.dart, support/empty_content_provider.dart | Cung cấp fake ContentProvider cho test shell | Nhi/Bình |
| test/profile_fields_test.dart | Kỳ vọng thông báo đúng mode | Nhi/Bình |
| test/home_appointment_test.dart | Kỳ vọng instant UTC+7 độc lập timezone | Nhi/Phương |
| test/appointment_refresh_api_test.dart | Detail navigation, read failures, session switch và 401/403/404 | Nhi/Phương |
| test/records_audit_test.dart, records_audit_ui_test.dart | Regression Receipt, ngày, timezone và status thiếu | Nhi/Ngân |
| test/fixtures/clinical_acceptance.json | Fixture local đề xuất | Ngân, chưa nghiệm thu |
| docs/handover/INTEGRATION_AUDIT_962a981.md | Báo cáo hiện hành và quyết định cần duyệt | Nhi/nhóm |
| docs/handover/{TEAM_HANDOVER,FRONTEND_RELEASE_BASELINE,DEMO_RUN_GUIDE,FRONTEND_OVERVIEW,NHI_NEXT_STEPS,CONTENT_MODULE_HANDOVER,API_INTEGRATION_MAP,QA_RESULTS}.md | Chú thích superseded, trỏ runbook mới | Nhi |

Tài liệu FRONTEND_COMMIT_PLAN.md/PENDING_BACKEND_REVIEW.md và manifest/hash lịch sử không được viết lại; đề xuất nhóm lưu trữ chúng khi chốt bàn giao. README nghiệp vụ của thành viên khác không sửa trong đợt này.

## 7. Kết quả kiểm thử

Tất cả HTTP/backend kiểm thử là giả lập; không có Firebase E2E hoặc thiết bị thật trong đợt này.

| Lệnh / phạm vi | PASS | FAIL | SKIP | Kết luận |
|---|---:|---:|---:|---|
| Backend `node --test test/module2/*.test.cjs test/module3/*.cjs test/module4/*.cjs` | 87 | 0 | 0 | Fake Firestore, không Firebase thật |
| Flutter nhóm API liên quan (lệnh bên dưới) | 132 | 0 | 3 | 3 skip là test mock theo điều kiện mode có từ trước; không thêm skip |
| `flutter test` (runner mặc định mock) | 224 | 0 | 131 | Các suite API-only có skip sẵn; không phải toàn bộ API được chạy trong mode này |
| `flutter test --dart-define=DATA_SOURCE=api` toàn bộ | 301 | 41 | 13 | FAIL, không đủ điều kiện kết luận tích hợp toàn hệ thống PASS |
| `flutter analyze` | — | 0 | — | No issues found |
| `TZ=UTC flutter test test/records_audit_test.dart` | 6 | 0 | 0 | UTC |
| `TZ=Asia/Ho_Chi_Minh flutter test test/records_audit_test.dart` | 6 | 0 | 0 | UTC+7 |
| `TZ=Asia/Tokyo flutter test test/records_audit_test.dart` | 6 | 0 | 0 | UTC+9 |

Chạy tại `frontend/`, nhóm API regression đã đạt:

```sh
flutter test --dart-define=DATA_SOURCE=api test/appointment_refresh_api_test.dart test/appointment_status_test.dart test/booking_idempotency_api_test.dart test/booking_shortcut_test.dart test/family_archive_test.dart test/profile_fields_test.dart test/validators_test.dart test/records_audit_test.dart test/records_audit_ui_test.dart test/module4_test.dart test/home_appointment_test.dart test/followup_booking_service_test.dart test/booking_api_sync_test.dart test/appointment_cancel_api_test.dart
```

Không sửa JavaScript nên không có bước kiểm tra cú pháp JS riêng; cả 87 test backend đã nạp các route liên quan. Không chạy emulator/device, không gửi request tới Firebase thật. Không chạy seed script. Fixture là dữ liệu đề xuất trên đĩa.

### Lỗi còn lại của toàn bộ API mode

Xem [danh sách từng test lỗi](../../qa_artifacts/audit_962a981/remaining_api_failures.txt) và [log đầy đủ](../../qa_artifacts/audit_962a981/full_api.log). Có 41 test lỗi ở các suite booking_test, records_test, widget_test, final_qa_test, content_handover_test, scroll_behavior_test và me_test. Log có lỗi thiếu provider trong helper dựng shell và các kỳ vọng dùng dữ liệu/màn mock trong API mode; chưa phân tích hết root cause riêng của 41 test, không khẳng định tất cả đều có sẵn hoặc đều là lỗi test. Không bỏ/skip chúng để làm xanh toàn bộ.

Các artifact khác: [baseline 34/5](../../qa_artifacts/audit_962a981/baseline_api.log), [backend](../../qa_artifacts/audit_962a981/backend.log), [nhóm API regression](../../qa_artifacts/audit_962a981/target_api.log), [toàn bộ mock](../../qa_artifacts/audit_962a981/full_mock.log), [analyze](../../qa_artifacts/audit_962a981/analyze.log), timezone_utc/tokyo/vietnam.log cùng thư mục.

## 8. Kết luận nghiệm thu

Đã sửa đúng nhóm 5 test ban đầu, không còn lỗi trong nhóm API regression được chỉ định và mở rộng. Bốn mục A06/A16/A19/A15 có regression chứng minh. A21 chỉ hoàn thành phần hiển thị bảo thủ, chưa có contract để nghiệm thu enum lâm sàng. Những thay đổi Models/UI liên module cần Ngân/Phương review dù không đổi API.

Chưa đủ điều kiện nghiệm thu toàn bộ API mode: bộ test toàn ứng dụng còn 41 lỗi, A05/A08/A10 chưa được duyệt, chưa kiểm tra runtime trên thiết bị và Firebase thật. Có thể dùng nhóm luồng đã kiểm thử làm cơ sở chuẩn bị demo có giới hạn: refresh/cancel appointment, idempotent booking, family sync, receipt lookup, notifications và Home; mọi kết quả đó hiện là HTTP/Firestore giả. Cần chạy kịch bản trên môi trường nghiệm thu riêng trước khi tuyên bố demo API thật sẵn sàng.

Những mục chờ duyệt cụ thể đã có đề xuất ở mục 5; chưa thực hiện bất kỳ thay đổi contract/schema/quyền/luồng ghi của Module 1–3 nào.
