# Booking → Staff approval → Completed → Records → Follow-up

Ngày: 31/10/2026, Asia/Ho_Chi_Minh. Mục tiêu demo: 03/11/2026. Nguồn: workspace hiện có; không kiểm tra Git hoặc remote.

## A. Executive summary

**PARTIAL / BLOCKED BY CONTRACT — chưa END-TO-END READY.** Đợt 1 đã sửa các lỗi kỹ thuật Flutter không thay đổi API/schema/quyền/trạng thái nghiệp vụ. Phần nghiệp vụ A05/A08/A10/A21, staff UI và completed→visit được lập đề xuất để nhóm duyệt; chưa triển khai. Chưa thử Firebase sandbox/emulator, chưa ghi dữ liệu thật.

Đã hoàn thành trong đợt này:

- Quote/voucher dùng chung revision và snapshot lựa chọn: response cũ không ghi đè giá mới, không ghi lại voucher đã xóa, không cập nhật draft sau đổi session.
- Áp voucher phải qua validate và full quote cùng lựa chọn trước khi hiển thị giá xác nhận; full quote cung cấp cả duration. Chặn nút và direct submit trong lúc voucher đang chờ.
- Đổi dịch vụ/combo xóa voucher đã áp, tải quote mới; kiểm tra lại bác sĩ cho toàn bộ dịch vụ, gồm dịch vụ ngoài combo. Không đổi lựa chọn của request đang chờ retry.
- Session thay đổi xóa draft riêng tư và vô hiệu hóa quote/voucher/availability đang chạy; không để response phiên cũ khôi phục slot.
- Chi tiết lịch hỗ trợ kéo để tải lại và refresh khi app resumed; chặn refresh chồng nhau, gỡ lifecycle observer khi dispose; giữ guard session và cập nhật cả hai store.
- Ghi chú UI giới hạn 500 ký tự theo contract backend đã có.
- Thêm regression có response đến sai thứ tự, lỗi mạng/quote, đổi phiên và refresh trạng thái. Không thêm skip, không xóa test.

Đã có sẵn và giữ nguyên: auth/ownership/transaction/idempotency server; notification transaction và Flutter điều hướng dù mark-as-read thất bại; records nullable date/receipt IDs độc lập; follow-up prefill từ service ID thật. Những phần này được đối chiếu code và chạy lại test, không coi báo cáo cũ là bằng chứng hiện tại.

Không triển khai: tạo visit/invoice/prescription/follow-up, lưu followUpId, thay state machine, mở quyền admin, sửa A10 hoặc archived family API. Không tự tạo staff hay gán quyền.

## B. Bản đồ contract hiện tại

PASS BY CODE chỉ nói code có đường đi tương ứng, không đồng nghĩa Firebase PASS. Toàn bộ hàng dưới đều **NOT VERIFIED ON FIREBASE**.

| Chặng / actor | API, request → response hiện có | Flutter model / điều phối | Firestore; trước→sau | Thành công / thất bại; bằng chứng | Trạng thái |
|---|---|---|---|---|---|
| Patient đăng nhập | Firebase SDK signIn; POST /api/users/sync; GET /api/users/me | FirebaseAuthService, UserProvider, ProfileProvider, UserProfile | users/{uid}; session→authenticated | SDK identity, backend verifyIdToken; 401 khi token sai. auth/session test fake | PASS BY CODE / LOCAL |
| Patient đọc catalog | GET /api/services, /combos, /doctors → arrays | CatalogService/Provider; DentalService, Doctor; BookingController | services, combos, doctors; không ghi | Không chọn isActive=false; lỗi tải hiển thị/retry, không thay giá bằng demo. catalog/parity tests | PASS BY CODE / LOCAL |
| Chọn dịch vụ→bác sĩ | Không ghi API; quote nhận serviceIds/comboId | SelectServicesStep, SelectDoctorStep, serviceIds/comboId/preferredDoctorId | Không ghi | Doctor phải làm toàn bộ dịch vụ; thay lựa chọn reset giờ/giá/voucher; pricing regression | PASS BY CODE / LOCAL |
| Chọn ngày→slot | GET /api/availability?date&doctorId&serviceIds&comboId → {slots,...} | AvailabilityService, AvailabilitySlot; chooseDate/loadAvailability | doctor_schedules, doctors, appointments, appointment_slots; read only | Theo UTC+7, tương lai/trong ca/không conflict; request cũ bị bỏ; scheduling fake | PASS BY CODE / LOCAL |
| Người khám | GET /api/family-members; create gửi patientId | ProfileProvider + BookingScreen selector; FamilyMember/UserProfile | users/{uid}/family_members | Chính chủ hoặc active family; archived/foreign bị từ chối create | PASS BY CODE; A05 PARTIAL |
| Voucher→giá cuối | POST /api/vouchers/validate {code,serviceIds,comboId}; POST /api/bookings/quote {serviceIds,comboId,voucherCode} → giá/discount/duration | BookingService; VoucherValidation/BookingQuote; BookingController | vouchers + catalog; chưa trừ lượt | Validate hợp lệ và quote mới nhất mới enable; lỗi không dùng giá cũ. pricing race tests | PASS BY CODE / LOCAL |
| Patient xác nhận | POST /api/appointments + Idempotency-Key; {patientId,doctorId?,serviceIds,comboId?,date,startTime,voucherCode?,note} →201 appointment | submit; Appointment; AppointmentsProvider + PatientDataProvider | appointments/booked, appointment_requests, appointment_slots, vouchers.usedCount, notifications | Ownership + future + schedule + conflict + voucher transaction; 400/401/404/409/500 không success giả | PASS BY CODE / LOCAL |
| Backend→success/list/detail | GET /api/appointments → account list; GET /:id → appointment | BookingSuccessScreen, AppointmentsProvider; BookingService; detail/list UI | appointments; read only | POST xác nhận mới success; GET cũ không xóa create chưa quan sát; foreign detail403/missing404 | PASS BY CODE / LOCAL |
| Staff xem queue | GET /api/appointments/staff?status=booked&date → list | Chưa có Flutter staff model/service/UI riêng; công cụ HTTP | appointments theo status/date | auth+role staff; patient403; list chứa note | PARTIAL, UI BLOCKED |
| Staff confirm/reject | PATCH /api/appointments/:id/status {status:confirmed/rejected,reason?} → appointment | Patient Appointment model đọc lại sau refresh; notifications view | appointments + notifications; booked→confirmed/rejected; reject release slot/voucher | reason bắt buộc khi reject; transition sai409; notice dedupe ID cố định | PASS BY CODE / LOCAL; công cụ demo PARTIAL |
| Patient nhận thông báo/trạng thái | GET /api/notifications, /unread-count, /home; PATCH notification read; GET appointment detail | ContentService/Provider, ApiNotificationsView, reloadAppointments | notifications.userId + appointments.accountId | Mark-read lỗi không chặn GET/điều hướng; 403/404 không mở cache; session guards. A19 tests | PASS BY CODE / LOCAL, REST polling/refresh |
| Patient hủy | PATCH /api/appointments/:id/cancel → {id,status:cancelled} | cancellationInfo/cancel, detail UI | appointments + slots/voucher/notification transaction; booked/confirmed→cancelled nếu tương lai | Chính chủ; không completed/past; cancel double tap dedupe ở provider | PASS BY CODE / LOCAL |
| Staff hoàn tất | PATCH /api/appointments/:id/status {status:completed} → appointment | Patient đọc AppointmentStatus.completed; chưa có staff UI | appointment + notification; confirmed→completed | Staff guard + transition; **không yêu cầu visit/đã đến khám/thời điểm khám trong handler hiện tại** | PASS BY CODE cho API; BLOCKED pipeline |
| Completed→visit | **Không có API tạo visit từ appointment trong routes hiện tại** | Visit model/RecordsService chỉ đọc | Chưa có write pipeline | Không được coi completed notice là bằng chứng visit tồn tại | MISSING / BLOCKED BY CONTRACT |
| Patient đọc kết quả/đơn/hóa đơn | GET patients/:id/visits/invoices/treatments; visits/:id; visits/:id/prescriptions; invoices/:id | RecordsService, PatientDataProvider, Visit/Prescription/Receipt/TreatmentPlan; các màn Records | visits, prescriptions, invoices, treatments/treatment_sessions | Auth + patient access; đọc dữ liệu đã tồn tại; missing/null/invalid date không tự sinh 1970; A06/A16 tests | PASS BY CODE / LOCAL cho read; A21 PARTIAL |
| Link visit→buổi điều trị | POST /api/treatments/:id/sessions/link-visit {visitId,sessionId} → session | VisitDetailScreen, RecordsService, linkVisitToTreatment | transaction treatment_sessions; gắn visitId/appointmentId và **status completed** | Check cùng patient/ownership/double link nhưng không đọc appointment completed | PARTIAL / A10 BLOCKED |
| Records→follow-up | GET /api/patients/:id/follow-ups → array | Followup, FollowupScreen; PatientDataProvider | follow_ups đã có sẵn | Không có API tạo mới/clinical cancellation contract trong đường đi này | PASS BY CODE cho đọc; creation BLOCKED |
| Follow-up→booking draft | UI chuyển tab; chưa ghi | BookingRequest + applyInitialValues: patientId, serviceIds, doctorId, suggestedDate, replaceSelection | Không ghi | Catalog API service có thật, doctor phù hợp hoặc chọn lại; guard session; không suy service từ lần khám trước | PASS BY CODE / LOCAL |
| Rebooking→truy vết nguồn | POST booking hiện **không nhận/lưu/echo followUpId** | BookingRequest/BookingService/Appointment hiện chưa có followUpId | Chưa có liên kết appointment→follow_ups | Prefill không đủ làm bằng chứng traceability; A08 cần contract | MISSING / BLOCKED BY CONTRACT |

Các endpoint trên lấy từ route đang có; mọi endpoint/field mới ở phần đề xuất bên dưới đều chưa tồn tại/chưa được duyệt.

### State machine và quyền hiện có

`booked → confirmed → completed`; nhánh `booked → rejected/cancelled`, `confirmed → cancelled`. Staff PATCH chỉ nhận confirmed/rejected/completed; patient chỉ có cancel chính chủ. Không đổi state machine.

`middleware/requireStaff.js` chỉ cho claim role=staff do backend verifyIdToken xác minh. **role=admin hiện bị từ chối**; không tự mở quyền. Flutter không có quyền quyết định role server. SDK token thật, refresh/revocation/custom claims thật chưa nghiệm thu.

Backend ghi notification booked cùng transaction create; confirmed/rejected/completed dùng document ID appointmentId_status cùng transaction chuyển trạng thái. Cancel lặp không chuyển trạng thái lần hai. Đây là document notification được đọc qua REST, **không phải push FCM**.

## C. Thay đổi kỹ thuật và root cause

| File / hàm | Chủ sở hữu / phạm vi | Root cause và thay đổi | Test |
|---|---|---|---|
| frontend/lib/features/booking/booking_controller.dart: applyVoucher, refreshQuote, _pricingCurrent, _acceptQuote | Phương; chỉ lớp tích hợp Flutter | Validate trước đây chỉ guard disposed, độc lập quote; nay shared revision+session+selection, validate rồi full quote, kiểm tra số tiền nhất quán, không publish preview stale | booking_pricing_race_test.dart |
| Cùng file: toggleCatalogItem/toggleService/applyInitialValues, _verifyDoctorForSelection | Phương; UI/state | Đổi dịch vụ giữ voucher/doctor không phù hợp; nay xóa voucher, reload quote, rà toàn bộ serviceIds+combo; freeze doctor khi request uncertain | pricing tests: đổi selection/doctor/frozen retry |
| Cùng file: _onDataChanged, loadAvailability, submit | Nhi/Phương integration | Voucher/availability muộn và draft cũ thiếu reset trên session; nay xóa riêng tư/invalidate generation; catch POST cũ không bật retry cho session mới; chặn submit khi validate | pricing/session tests + booking_api_sync_test.dart |
| frontend/lib/features/records/appointment_detail_screen.dart: lifecycle, _refresh, RecordsPage.onRefresh | Ngân/Nhi integration | Chỉ fetch khi mở, không refresh tại resume/pull; nay có observer, chống fetch chồng, detach dispose, dùng nguyên API/ownership/session guards | appointment_refresh_api_test.dart, 2 test mới |
| frontend/lib/features/booking/steps/confirm_booking_step.dart: note TextFormField | Phương/Nhi UI | Backend giới hạn 500 nhưng UI chưa có; thêm maxLength=500; server vẫn validate/trim như cũ | Backend note regression; full Flutter suite |
| frontend/test/booking_pricing_race_test.dart (mới) | QA integration | MockClient + Completer ép response sai thứ tự, pending final quote, failure, logout, availability, doctor freeze | 14 test mới chạy cả lệnh default và API bằng test-local config, không skip |
| frontend/test/appointment_refresh_api_test.dart | QA integration | Thêm pull/resume/dispose/overlap assertions, giữ test cũ | 2 test mới |
| backend/test/module2/staff-concurrency.test.cjs (mới) | QA Module 2 | Dùng fake transaction có version/retry để ép hai thao tác staff cùng đọc trước commit; patient gửi role giả không được complete | 3 test: confirm/confirm, confirm/reject, patient role spoof |
| frontend/docs/handover/BOOKING_TO_FOLLOWUP_INTEGRATION.md (mới) | Nhi | Contract map, phê duyệt, test và checklist | Báo cáo này |

Không sửa code backend production, API/schema Firestore, dependency, cấu hình production, auth/role, seed hay `backend/api-test.http`. Không ghi đè nội dung các báo cáo cũ. BOOKING_FLOW_AUDIT.md là snapshot trước các sửa kỹ thuật này.

### Tái hiện trước sửa

- 7 test pricing đầu tiên FAIL trên code cũ: late voucher, newest voucher, quote/voucher coordination, confirm pending, remove voucher, logout, invalid validation response. Test phối hợp full quote cũng FAIL vì code cũ chưa gọi full quote sau validate (truy cập pending quote thứ hai không tồn tại); 6 ca còn lại cho thấy assertion state sai trực tiếp.
- 2 test detail mới FAIL trước sửa: chưa có RefreshIndicator; resume không tạo GET mới (1 thay vì 2).
- Sau sửa chạy lại nhóm integration: 64 PASS, 0 FAIL, 2 SKIP sẵn có ở lượt trung gian. Sau đó thêm coverage doctor/session/error và chạy lại toàn bộ suite ở phần D.
- Trong quá trình gọi test có hai lần chạy từ gốc repository báo không có pubspec.yaml; đã chạy lại trong frontend. Đây là lỗi chọn thư mục lệnh, không phải kết quả test sản phẩm.

## D. Kết quả kiểm thử

Kết quả cuối đã chạy ngày 31/10/2026, sau thay đổi cuối cùng; tất cả lệnh trả exit 0. Không có regression quan sát được trong các suite này; không suy ra coverage tuyệt đối. Tăng 16 test Flutter và 3 test backend so với baseline, số SKIP giữ nguyên.

| Kiểm tra | Baseline đã báo | Kết quả cuối |
|---|---|---|
| Backend fake | 87 PASS, 0 FAIL | **90 PASS, 0 FAIL, 0 SKIP**, exit 0 (+3) |
| Flutter API-mode MockClient | 359 PASS, 0 FAIL, 13 SKIP | **375 PASS, 0 FAIL, 13 SKIP**, exit 0 (+16) |
| Flutter mặc định | 241 PASS, 0 FAIL, 131 SKIP | **257 PASS, 0 FAIL, 131 SKIP**, exit 0 (+16) |
| flutter analyze --no-pub | sạch | **No issues found**, exit 0 |

Lệnh (tại đúng thư mục):

```sh
# backend/
node --test test/module2/*.test.cjs test/module3/*.test.cjs test/module4/*.test.cjs
# frontend/
flutter test --dart-define=DATA_SOURCE=api --reporter expanded
flutter test --reporter expanded
flutter analyze --no-pub
```

Log full-suite được rút gọn bằng `tail` với `set -o pipefail`, giữ exit Flutter; không sửa test setup toàn cục. Test mới tự scope DataSource.api và restore bằng tearDown. Không thêm skip. Một lượt analyze ban đầu báo 3 lint thiếu braces ở code mới; đã sửa trước lượt cuối.

| Tầng | Phạm vi bằng chứng |
|---|---|
| Backend HTTP fake | Express routes thật trên loopback + Firestore/Auth fake qua require.cache; 90 test gồm Module 2/3/4, không phải 87 test riêng Booking |
| Flutter unit/widget/API-mode | MockClient/fixture, không gọi Firebase; bao phủ quote/idempotency/notification/records/follow-up/session |
| Flutter→backend server thực tế | NOT VERIFIED; hai bộ fake không phải test cùng một stack mạng |
| Firebase Emulator | NOT VERIFIED; không khởi động/chưa xác minh cấu hình an toàn |
| Firebase sandbox | NOT VERIFIED; không ghi/không đăng nhập tài khoản thật |
| UTC/UTC+7/UTC+9 trên thiết bị | NOT VERIFIED; unit test clinicInstant/wallTime có bằng chứng số học nhưng chưa chạy app đủ ba timezone |

Các regression cũ giữ nguyên: backend slot/voucher concurrency, idempotency payload conflict, note limit, staff patient403, transitions/dedupe; 3 test mới ép staff concurrency có transaction retry và patient không thể complete qua role trong payload; Flutter duplicate submit, quote API, notification mark-read failure/uncached/403/404/account switch, receipt visitId độc lập, invalid date, follow-up real service prefill và clear session.

## E. Quyết định cần nhóm phê duyệt — chưa triển khai

Tất cả mục dưới là **BLOCKED BY CONTRACT/APPROVAL** theo quy tắc 8/10, C2, E/F/H của yêu cầu. Đây không phải đề nghị cấp quyền chung; cần duyệt lựa chọn cụ thể, actor, contract và dữ liệu test.

### E1. A05 — Bình + Ngân + người dùng: archived family chỉ đọc

Hiện GET family-members loại isArchived=true; backend records vẫn kiểm tra document tồn tại nên lịch sử có thể đọc nếu biết ID, nhưng selector Flutter không liệt kê đủ archived. Không dùng cache appointment để suy ra danh sách đầy đủ.

Đề xuất query tùy chọn `GET /api/family-members?includeArchived=true`, response thêm isArchived; mặc định response cũ giữ nguyên. Records selector phân active/archived, booking luôn active; không unarchive ngầm. Quyền chỉ owner. Cần duyệt field/query và phạm vi UI; test foreign/active/archive/history/booking archived400, race archive/create; không migration bắt buộc cho document thiếu flag (giữ active như hiện tại).

### E2. A08 — Phương + Ngân + người dùng: contract followUpId tối thiểu

Đề xuất cho endpoint **đang có** POST /api/appointments, chưa thêm vào code:

| Thành phần | Đề xuất chờ duyệt |
|---|---|
| Request | followUpId?: string, nonempty/trim, bỏ trống giữ booking thông thường |
| Validate | Transaction đọc follow_ups/{id}; owner bằng patientId==uid hoặc family thuộc uid; cùng patientId; serviceId đúng catalog/selection; xác minh visitId/treatmentId cùng patient nếu nguồn có; dữ liệu thiếu không suy đoán hợp lệ |
| Active/cancelled | Ngân chốt status enum và quy tắc follow-up còn dùng được; chưa tự đặt enum mới |
| Persistence | Lưu followUpId trên appointment mới; không sửa/xóa lịch sử khi cancel; có hay không cập nhật backlink trên follow-up phải duyệt riêng |
| Response/model | Echo followUpId; thêm optional vào Appointment, BookingRequest→Controller→BookingService, không hiển thị liên kết giả khi server chưa hỗ trợ |
| Idempotency | Thêm followUpId vào fingerprint server/client; cùng key cùng nguồn replay cùng ID; cùng key khác nguồn409; concurrency tối đa active tùy lựa chọn dưới |
| Multiplicity | Đề xuất nhiều lịch lịch sử nhưng tối đa một appointment active cho một follow-up; cần chọn quy tắc khi cancelled/rejected/completed. Nếu cần unique active lock, schema/index và release transaction phải được duyệt |
| Backward compatibility | Appointment cũ thiếu followUpId vẫn đọc được, booking thường giữ nguyên; không backfill bằng heuristic service/date. Có backfill chỉ khi mapping nguồn được chủ dữ liệu xác nhận |
| Regression | Missing/foreign/wrong patient/service/source/cancelled follow-up; same/different key và source; race hai key; cancel/rebook; legacy client/document; sandbox trace appointment→follow-up→visit/treatment |

Đây là đề xuất contract, không phải endpoint/schema đã triển khai. Hiện Followup model chưa giữ visitId/treatmentId/status; chưa đủ cơ sở để chứng minh truy vết hoặc ngăn dùng follow-up đã hủy ở client.

### E3. A10 — Ngân + Phương + người dùng: tách link và clinical completion

Root cause xác minh tại `backend/src/routes/treatments.js:107`: link-visit ghi `status:'completed'` và completedAt ngay khi link, không đọc appointment/visit clinical status. Route chỉ auth+ownership, nên patient owner có thể kích hoạt việc hoàn tất session gián tiếp. Cross-patient/double-link đã được transaction bảo vệ nhưng không giải quyết điều kiện lâm sàng. Test backend hiện xác nhận hành vi cũ; không được sửa expected để che thay đổi nghiệp vụ.

Hai lựa chọn cần duyệt:

1. **Đề xuất:** link chỉ gắn visitId/appointmentId; hoàn tất session qua actor staff/clinician và API riêng được nhóm chốt. Cần contract API/quyền, status và idempotency riêng; chưa tự đặt endpoint.
2. Giữ link đồng thời completed nhưng bắt buộc transaction đọc appointment liên quan và trạng thái lâm sàng được duyệt, cùng patient/account, completed và actor có thẩm quyền. Cần thống nhất patient còn được gọi link hay không; chỉ kiểm tra appointment completed không tự chứng minh visit đã ký kết quả.

Mọi reads ownership/source/appointment/target/query phải trước writes; replay đúng liên kết trả nguyên kết quả hay409 cần chốt. Tests: chưa khám/pending/confirmed/rejected/cancelled/missing source không được complete, đúng nguồn được phép, cross-account/patient, duplicate/concurrent/race source-state thay đổi, abort không partial write. Migration các session đã bị complete do link phải review dữ liệu, không tự đảo trạng thái hàng loạt.

### E4. A21 — Ngân + người dùng: clinical status

Visit hiện chưa có status model; routes trả document; UI API hiển thị “Trạng thái chưa cập nhật”, không tự suy completed. TreatmentPlan cũng không dùng số buổi để khẳng định trạng thái API. TreatmentSession đọc status==completed theo contract hiện tại (chịu rủi ro A10).

Cần chốt enum visit/treatment/session, actor/điều kiện chuyển, nguồn sự thật, cách hiển thị missing/unknown, và backfill. Chỉ sau duyệt mới thêm field/model mapping; không coi appointment completed là clinical completion mặc định. Tests phải phân biệt unknown/missing với completed.

### E5. Staff UI/quyền và file HTTP dùng chung — Phương + Bình + người dùng

Không tìm thấy staff screen hoặc role source đã nối vào UserProvider hiện tại. Backend queue/status đủ cho staff hiện có, nhưng /appointments/:id chỉ owner nên staff không thể dùng patient detail endpoint để đọc chi tiết tùy ý.

Phương án tối thiểu đề xuất: màn staff riêng dùng thông tin queue (đã trả note/services/patientId/price/date/status), xác nhận hoặc từ chối có lý do, refresh queue, loading/error/empty/in-flight guards. Dùng custom claim qua Auth service để hiện UI, server vẫn requireStaff. Không dựa email, role client gửi hay local flag. Nếu cần chi tiết lâm sàng/tên bệnh nhân ngoài dữ liệu queue, phải duyệt API/quyền riêng. Chọn **staff-only theo backend hiện tại** hoặc staff+admin (đổi guard/test cần duyệt Bình/Phương); chưa triển khai UI/role adapter.

**Phạm vi HTTP đề xuất chờ duyệt C2:** chỉ Module 2, A01-7 thay ID cố định bằng `{{a01Appt.response.body.$.id}}` như các bước khác (hoặc đặt biến `{{appointmentId}}` từ response đó và dùng nhất quán). Không sửa phần đăng nhập/Module 1/3/4. Không chạy request. File hiện dùng dotenv cho mật khẩu, chưa theo biến testPassword/staffPassword nêu trong yêu cầu; đề xuất alias hai biến này đến dotenv, không điền giá trị. Phần login dùng chung nằm ngoài Module 2 nên cần duyệt phạm vi riêng nếu muốn chuẩn hóa. **Chưa sửa file HTTP.**

Ngày mẫu A01 hiện là 02/11; khi demo 03/11 phải chọn ngày/giờ thực sự còn tương lai, có schedule/voucher hợp lệ. Không tự seed/gán staff.

### E6. Completed→visit pipeline — Phương + Ngân + người dùng

Hiện staff có quyền confirmed→completed bằng PATCH status, không check visit hoặc attendance. Không có API tạo visit/đơn/hóa đơn/follow-up trong route đã đọc; handler completed chỉ cập nhật appointment+notice. Patient không được đổi appointment completed (guard staff đã có).

Cần chọn mô hình:

- **Đề xuất:** visit được clinician/staff tạo/finalize theo contract Ngân, rồi hoàn tất appointment atomically hoặc qua điều phối idempotent đã thống nhất. Khi visit chưa tồn tại/khác patient/chưa final thì không complete. Cần xác định actor có quyền y khoa, attendance và nguồn trạng thái.
- Hoặc completed tạo một visit draft duy nhất, không coi đó là kết quả đã khám; clinical completion/đơn/hóa đơn/follow-up là bước staff riêng. Cần duyệt draft enum, dữ liệu bắt buộc, thời điểm ghi, idempotency và liên kết một/multiple visits.

Contract cần chốt: appointmentId/patientId/account ownership, unique link/retry, transaction/failure recovery giữa status và visit, schema clinical result, quyền tạo/chỉnh sửa/đọc, migration lịch completed cũ không visit, và lúc tạo follow-up. Không tự sáng tác endpoint để triển khai. Trước khi chốt, demo chuỗi bắt buộc dừng ở chặng này.

### E7. Các rủi ro còn lại cần Phương review

- Idempotency-Key/pending request chỉ lưu trong bộ nhớ; restart giữa timeout chưa có durable recovery. “Chọn lại” so patient+ngày/giờ còn có thể nhận nhầm lịch khác bác sĩ/dịch vụ; GET rỗng chưa bảo đảm request cũ không commit sau đó. Chưa sửa thiết kế retry trong đợt kỹ thuật này.
- Slot là snapshot; 409 hiện báo lỗi, cần chọn/tải lại giờ. Backend chặn conflict; kiểm tra future ở trước transaction có race sát giờ, chưa đổi transaction.
- Backend tính lại giá tại create; giá catalog/voucher có thể đổi sau quote. Muốn bắt xác nhận lại nếu chênh giá cần Phương chốt quote/version contract; chưa tự thêm expectedTotal hay quote token.
- Bucket lock15 phút có thể chặn slot không chồng nếu duration/slot không căn15; cần kiểm tra dữ liệu và invariant, không đổi schema lock.
- Lifecycle refresh không phải realtime; giữ app foreground không tự thấy staff update đến khi kéo refresh/tab/notification.
- Các màn records detail truyền object snapshot; reload nguồn không đồng nghĩa mọi detail object tự thay mới. Chưa sửa model/navigation sang fetch theo ID ở đợt này; chốt scope nếu demo thay clinical data khi đang mở màn.

## F. Checklist demo và nghiệm thu sandbox

Toàn bộ ghi Firebase dưới đây **NOT VERIFIED / CHỜ DUYỆT**, không được coi là lệnh đã chạy. Mock PASS không nâng các ô này thành PASS thật.

| Bước | Actor/fixture cần có | API / thao tác | Kỳ vọng | Trạng thái hiện tại |
|---|---|---|---|---|
| 1 | Patient A sandbox active | Firebase login, users/me | UID/profile đúng, không lộ secret | NOT VERIFIED |
| 2 | Catalog giá/duration, doctor serviceIds, ca tương lai | GET services/combos/doctors/availability | Chỉ slot hợp lệ theo UTC+7 | NOT VERIFIED |
| 3 | A và family active, voucher sandbox còn lượt | quote/validate→POST appointments với key | 201 booked, giá backend, một notice/lock/request | NOT VERIFIED |
| 4 | A, appointment vừa tạo | GET appointments/:id + list | Trường/id/status/ownership đúng sau reload | NOT VERIFIED |
| 5 | Staff sandbox đã được chủ dự án gán quyền từ trước | Login; GET appointments/staff | Queue đúng, patient token403 | NOT VERIFIED; UI BLOCKED |
| 6 | Staff + ID lấy từ response step3 | PATCH status confirmed | 200, một confirmed notice; lặp409 | NOT VERIFIED; HTTP fix chờ duyệt |
| 7 | A app | Refresh tab/detail/resume | confirmed ở cả hai store và Home | NOT VERIFIED |
| 8 | A app | GET notifications, tap, read | Notice đúng account; read lỗi vẫn điều hướng đúng | NOT VERIFIED |
| 9 | Staff/clinician và contract hoàn tất đã duyệt | PATCH completed theo điều kiện được chốt | Completed đúng quyền và nguồn lâm sàng | BLOCKED E6 |
| 10 | Visit/appointment/source đúng patient | API tạo/link theo contract được duyệt | Unique relation, không partial writes | BLOCKED E3/E6 |
| 11 | Records/đơn/invoice đã tạo hợp lệ | GET patients/visits/invoices/... | Đúng nguồn/patient; receipt IDs độc lập, không 1970 giả | NOT VERIFIED; data creation BLOCKED |
| 12 | Follow-up source hợp lệ | GET patients/:id/follow-ups | Service/source/status đúng contract | BLOCKED E2/E4/E6 cho chuỗi tự tạo |
| 13 | A từ FollowupScreen | Prefill→quote→POST booking | Người khám/dịch vụ đúng; backend xác nhận | Prefill PASS LOCAL, Firebase NOT VERIFIED |
| 14 | followUpId contract đã duyệt | GET lịch mới và nguồn | Truy vết followUpId→visit/treatment gốc | BLOCKED E2 |
| 15 | Patient B, archived family, staff/admin theo scope | GET/PATCH bằng actor sai quyền | 401/403 và không đổi dữ liệu người khác | NOT VERIFIED; admin/A05 chờ duyệt |

Ca bổ sung bắt buộc: A/B tranh slot; hai request tranh voucher cuối; double tap; commit rồi mất response; retry cùng/khác payload; validation sai thứ tự; archive đồng thời create; cancelled/rejected trong lúc xem detail; logout→B với response pending; restart app; UTC/UTC+7/UTC+9; server400/401/403/404/409/500. Ghi expected/actual, số document trước/sau và ID test đã loại thông tin riêng tư. Không dùng records seed có sẵn để khẳng định pipeline tạo mới đã PASS.

## G. Hướng dẫn kiểm thử thật sau phê duyệt

1. Chủ dự án xác nhận **project ID sandbox cụ thể**, base URL backend, tài khoản/role được phép, fixture, ca/voucher và phạm vi POST/PATCH/DELETE; người phụ trách giữ secret ngoài báo cáo/chat. Agent chưa kiểm tra thông tin credential/project ở đợt này.
2. Chủ môi trường kiểm tra project Firebase của app Flutter và backend trùng sandbox, so với allowlist đã duyệt bằng **project ID không nhạy cảm**; không chỉ tin URL localhost (backend local vẫn có thể kết nối production). Không in nội dung credential, token, mật khẩu; không sửa Rules/IAM để vượt lỗi.
3. Trước mọi ghi, xác minh project bằng Firebase Console project selector và cấu hình triển khai đã được người phụ trách kiểm tra riêng; nếu không chứng minh được sandbox thì STOP. Không tự thêm đường debug lộ credential hay sửa config production. Emulator chỉ dùng khi đã xác nhận cả Auth và Firestore trỏ emulator/test project, không fallback credential thật.
4. Frontend dùng DATA_SOURCE=api; Android emulator API_BASE_URL=http://10.0.2.2:3000, desktop localhost:3000, thiết bị thật dùng host được duyệt. Các cờ này không chứng minh DB là sandbox. Không truyền secret qua dart-define, không commit local credentials.
5. Bắt đầu bằng GET catalog/profile/slot và kiểm tra ownership A/B; chỉ sau duyệt ghi mới gọi create/status/cancel/mark-read/link-visit theo từng bước. **Không Send All file HTTP** vì có nhiều thao tác ghi ngoài phạm vi. Không chạy seed/set-staff trong runbook này.
6. Các request cần duyệt riêng: POST users/sync hoặc tạo fixture, POST vouchers/validate/quote (dù read-only về nghiệp vụ vẫn theo phạm vi người dùng duyệt POST), POST appointments, PATCH status/cancel/notification read, POST link-visit, và mọi clinical/follow-up write mới được nhóm chốt. Không tự tạo login/staff account.
7. Đối chiếu API response với document sandbox bằng công cụ được chủ dự án cho phép; xác minh atomicity/count/dedupe khi retry, không sửa document bằng tay để làm demo pass. Kết thúc lưu evidence đã che dữ liệu nhạy cảm, dọn fixture theo phạm vi xóa được duyệt.

## H. Điều kiện hoàn thành và bước tiếp theo

Đợt sửa kỹ thuật đã hoàn tất trong phạm vi cho phép: kết quả D đạt, không có regression quan sát được trong suite. Không tự chuyển BLOCKED contract thành DONE. Cần người dùng/chủ module duyệt E1–E6 (có thể chọn riêng từng mục), sau đó triển khai contract, test fake/emulator và mới xin phê duyệt sandbox cụ thể. **Chưa đủ điều kiện END-TO-END READY cho 03/11/2026.**
