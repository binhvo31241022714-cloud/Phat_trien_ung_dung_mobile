# End-to-end flow audit — MediCare Dental

Ngày 01/11/2026. **Không có Firebase E2E PASS.** Source tracing + fake backend + Flutter MockClient chỉ chứng minh từng phần; hai bộ fake không cùng chạy một database/backend thực nối với Flutter. Không tự sửa contract hay tạo clinical data thật trong audit.

## Chuỗi nghiệp vụ và bằng chứng

| Bước | UI/model/service | API và dữ liệu/ID | Trạng thái và giới hạn |
|---|---|---|---|
| 1. Authentication | login_screen/register_screen; FirebaseAuthService; UserProvider | Firebase Auth SDK → UID; POST users/sync → users/<uid>; ApiClient gắn ID token | VERIFIED source + fake UI; Firebase sign-in/email/token thật BLOCKED |
| 2. Profile/family/catalog | ProfileProvider/CatalogProvider; UserProfile/FamilyMember/DentalService/Doctor | GET/PATCH users/me; CRUD family-members; GET services/combos/doctors; favorites dưới user | VERIFIED mock/source; ownership dùng UID; archived history lỗi AUD-06 |
| 3. Chọn booking | BookingScreen + BookingController; AvailabilitySlot | POST bookings/quote, GET availability, POST vouchers/validate | VERIFIED fake/mock; serviceIds/comboId/doctorId, clinic date/startTime; không chứng minh dữ liệu danh mục Firebase đang hợp lệ |
| 4. Tạo appointment | BookingService.createAppointment; Appointment; AppointmentsProvider | POST appointments → appointments/<id>, appointment_slots/slot_<hash>, appointment_requests/<uid>_<key>, event notification | VERIFIED fake: atomic lock/voucher/idempotency/owner/family; Firestore concurrency thật NOT VERIFIED |
| 5. Staff confirmation | Không thấy staff console Flutter hoàn chỉnh; API staff | GET appointments/staff; PATCH appointments/<id>/status confirmed; deterministic notification <id>_confirmed | VERIFIED fake; requireStaff từ token claims, không role body; không gán staff trong audit |
| 6. Staff completion → Visit | Patient đọc Visit/RecordsService; staff API ghi | PATCH status completed → visit_<appointmentId>, appointment.visitId, notification <id>_completed type visit_result/refId visitId | PARTIALLY VERIFIED: visit có ghi, state transition fake pass; collision guard/staff audit metadata thiếu, AUD-02 |
| 7. Prescription/invoice/receipt | Prescription/Receipt; records screens | GET visits/<id>/prescriptions; patients/<id>/invoices; invoices/<id> | GET có code, mock có dữ liệu giả; **NOT IMPLEMENTED trong writeCompletion hiện tại**, AUD-01. Không có chứng cứ payment gateway |
| 8. Treatment | TreatmentPlan/TreatmentSession; detail/photos/progress screens | POST treatments (staff) → treatments + treatment_sessions; PATCH sessions; POST sessions/link-visit | VERIFIED một phần fake: tạo/link/progress; ngày validation fail; backend media harness BLOCKED. Đây là bước staff riêng, không tự tạo khi complete |
| 9. Patient Records | PatientDataProvider.loadRecords, RecordsHome/Visit/ExamResult/Receipt screens | 4 list + detail/prescriptions/sessions; patientId nối patient; visitId/appointmentId nối chứng từ | VERIFIED mock/source cho đọc dữ liệu sẵn; PARTIALLY VERIFIED nghiệp vụ vì thiếu chứng từ từ completion; một detail fail chặn load |
| 10. Staff follow-up | Followup model; FollowupScreen; notification navigation | POST follow-ups → follow_ups/<id>, event notification type follow_up/refId <id> | PARTIALLY VERIFIED: persist code có, fake cho thấy validation nguồn/ngày sai; không tự tạo từ completion |
| 11. Rebooking | FollowupScreen → BookingRequest → controller → BookingService | followUpId đưa vào appointment/fingerprint; transaction update follow-up booked + appointmentId | VERIFIED normal fake/mock; stale backlink AUD-04 và source integrity AUD-03 chưa giải quyết |
| 12. Cancel/reject/complete linked appointment | AppointmentsProvider/record status | PATCH cancel/status → reopen/complete follow-up; release slot/voucher nếu cancel/reject | VERIFIED normal fake, PARTIALLY VERIFIED bất thường: helper không so appointmentId |
| 13. Event notifications | ContentProvider; ApiNotificationsView; badge Home | GET notifications/unread-count; PATCH read/read-all; owner userId | VERIFIED fake/mock; persisted source code, không phải push |
| 14. Scheduled reminders | jobs/reminders.js từ server.listen | immediate + interval10m; confirmed appointment 0–24h → notifications/<appointmentId>_<date>_<startTime> | PARTIALLY VERIFIED, race AUD-05; không reminder2h riêng, không follow-up3d/08:00, không rebook suppression |
| 15. Push khi app đóng | Không có FCM SDK/service/device token | Không có send push pipeline trong source | NOT IMPLEMENTED; không dùng in-app event làm bằng chứng push |

## Contract/ID invariants cần giữ

- Identity đáng tin cậy là req.user.uid từ verifyIdToken; accountId booking lấy từ UID. patientId self = UID hoặc family doc thuộc users/<UID>.
- Appointment lưu patientId/accountId/doctorId/serviceIds/comboId/date/startTime/endTime/price/voucher/followUpId. Follow-up cần trỏ ngược về cùng appointmentId khi status booked. Booking bình thường kiểm tra status và đổi trong transaction, nhưng release helper chưa bảo vệ backlink.
- Completion hiện dùng visit_<appointmentId>. Source chỉ tạo Visit; các ID rx/inv được mô tả trong README/test không chứng minh writer tồn tại.
- Prescription query lọc visitId rồi patientId; invoice model Receipt có ID độc lập và optional visitId/appointmentId. Không dùng receipt ID thay visit ID trong navigation.
- Treatment sessions nối treatmentId và patientId; link-visit kiểm tra visit completed, cùng patient và chưa link nơi khác trong transaction. Photos/media có ownerAccountId, patientId, mediaId và treatmentId.
- Notification userId là owner, refId tùy type. visit_result cần visitId, follow_up cần followUpId, appointment_* dùng appointmentId. Flutter fetch lại nguồn trước mở; nguồn 403/404 không lấy dữ liệu mock để thay thế.
- Appointment không followUpId vẫn được hỗ trợ. Follow-up thiếu serviceId hiện UI chặn rebook và yêu cầu liên hệ phòng khám; backend chỉ enforce service khi field có giá trị.

## Các cổng chưa đạt cho E2E

1. Completion thiếu invoice/prescriptions và validation/collision protection; chuỗi clinical không thể được đánh dấu đầy đủ.
2. Follow-up tạo được với patient/source sai; chưa có bảo đảm liên kết hai chiều ở mọi status transition.
3. Archived family không còn nằm trong patient selector, list history bị guard chặn dù data chưa xóa.
4. Scheduled reminders chỉ một cửa sổ appointment, không đáp ứng các mốc yêu cầu; race và stale-source policy chưa giải.
5. Chưa chạy Flutter → Express → Firestore cùng một phiên thật; chưa kiểm token, IAM, index, dữ liệu thực, restart/multiworker, notification quyền OS.

## Bằng chứng test và giới hạn

Backend fake suite: 120 pass /35 fail trong 155 entries; Flutter default: 308 pass /3 fail /132 skip; Flutter api MockClient: 426 pass /3 fail /14 skip; analyze sạch. Các số này dùng chung với FULL_APPLICATION_AUDIT, không cộng pass hai mode để suy ra số test unique.

Một số integration semantics đã được fake backend test (booking/status/link-visit/rebooking), nhưng thiếu end-to-end DB thật và còn failures. Media file suite crash khi load do MAX_IMAGE_BYTES không export; ba Flutter destination tests dừng ở stale label. Những bước sau trong test bị dừng không được coi là đã chạy.

## Kế hoạch xác minh tiếp theo sau khi được duyệt

Đây chỉ là đề xuất, chưa thực hiện: owner thống nhất contracts → sửa theo issue register → mock/fake regression xanh có review → chuẩn bị sandbox riêng và dữ liệu tổng hợp được duyệt → kiểm cùng UID/patient qua từng ID → kiểm account B không đọc account A → kiểm confirmed/completed/clinical/follow-up/rebook/cancel → kiểm restart/worker/preferences → báo cáo từng API và kết quả thực. Không dùng credential production hoặc người bệnh thật để demo tự động.
