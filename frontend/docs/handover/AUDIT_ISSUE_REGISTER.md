# Audit issue register — MediCare Dental

Ngày audit: 01/11/2026, Asia/Ho_Chi_Minh. Snapshot: source trong workspace hiện tại; không xác định commit bằng Git. Không sửa source/test trong nhiệm vụ audit. Các bản sửa từ những lượt trước đã có trong snapshot.

18 phát hiện: **P0: 0; P1: 6; P2: 10; P3: 2**. Đây là số nguyên nhân/gap riêng biệt, không phải số test thất bại. Không có kết luận đã khai thác production hay Firebase E2E PASS.

VERIFIED = đọc source hoặc tái hiện bằng mock/fake, được ghi riêng ở mỗi mục. PARTIALLY VERIFIED = code có vấn đề nhưng chưa chứng minh đầy đủ tác động runtime/concurrency thật. NOT VERIFIED = chưa kiểm chứng. BLOCKED = không thể xác minh trong phạm vi được phép. NOT IMPLEMENTED = không có implementation trong đường chạy đã khảo sát.

## AUD-01 — P1 — Hoàn tất khám không tạo đơn thuốc/hóa đơn

- Module/chủ sở hữu: M3 Ngân, phối hợp M2 Phương.
- Bằng chứng: `backend/src/utils/clinical.js:10` (`parseCompletionBody`), `:16` (`readCompletion`), `:19` (`writeCompletion`); `backend/src/routes/appointments.js:551` route status. Chỉ `transaction.set(visits/visit_<appointmentId>)`; không ghi prescriptions/invoices. `staffUid` truyền vào nhưng không được dùng.
- Tái hiện an toàn: backend fake test `module3/clinical-records.test.cjs:110`, `:126`, `:136`; hoàn tất confirmed appointment, cả có và không gửi invoice.
- Thực tế: các test invoice đọc `undefined`; ca hoàn tất đầu thiếu `createdBy` kỳ vọng. API có thể trả thành công và gửi visit_result dù thiếu các chứng từ.
- Tác động: chuỗi completed → records → đơn thuốc/biên lai bị thiếu dữ liệu; README mô tả khả năng chưa có trong code.
- Trạng thái: VERIFIED bằng source + fake; phần tạo invoice/prescription NOT IMPLEMENTED trong completion hiện tại.
- Hướng sửa đề xuất: thống nhất contract completion, validate và tạo các chứng từ liên kết trong cùng transaction; lưu staff audit fields. Chưa thực hiện.
- Hồi quy cần bổ sung/khôi phục: invoice tự lập theo giá chốt, invoice nhập tay, prescription items, rollback toàn bộ khi một bước lỗi.

## AUD-02 — P1 — Ghi đè visit đã tồn tại

- Module/chủ sở hữu: M3 Ngân.
- Bằng chứng: `backend/src/utils/clinical.js:16-21`: không đọc visit hiện có, dùng `transaction.set` không có precondition. Line range ở đây là mô tả nguồn, không phải liên kết IDE.
- Tái hiện: confirmed appointment có sẵn `visits/visit_<id>` rồi gọi completed. Fake test `clinical-records.test.cjs:159` mong 409 nhưng nhận 200.
- Tác động: nội dung hồ sơ có sẵn ở ID deterministic có thể bị thay thế. State machine chặn lần complete thứ hai thông thường, nhưng không bảo vệ dữ liệu bất nhất/import sẵn.
- Trạng thái: VERIFIED source + fake; chưa xảy ra mất dữ liệu thật được xác minh.
- Hướng sửa: đọc chứng từ trong transaction, từ chối dữ liệu xung đột hoặc thiết kế replay an toàn.
- Hồi quy: preexisting visit/invoice/rx không bị ghi đè; completion fail không đổi appointment/notification.

## AUD-03 — P1 — Tạo follow-up thiếu kiểm tra quan hệ người khám và nguồn

- Module/chủ sở hữu: M3 Ngân, Bình hỗ trợ ownership.
- Bằng chứng: `backend/src/routes/followUps.js:13-20`: chỉ đọc `users/<accountId>`; không đọc family member, visit, treatment, doctor, service được gửi. Khi patientId khác accountId, điều kiện kiểm tra tồn tại user còn bị bỏ qua. `assertPatientAccess` import nhưng không dùng.
- Tái hiện: staff gửi patientId đã archived/không thuộc account, visitId khác bệnh nhân, serviceId/treatmentId không tồn tại; các ca `clinical-records.test.cjs:347` trở đi thất bại do nhận 201 thay vì 400.
- Tác động: recommendation/notification có liên kết sai nguồn, không thể đặt lại hoặc không mở đúng hồ sơ. Không khẳng định bệnh nhân tự vượt quyền: route vẫn có requireStaff.
- Trạng thái: VERIFIED source + fake.
- Hướng sửa: validate account/patient/source/service/status trong transaction trước ghi; thống nhất policy archived.
- Hồi quy: sai account/patient/source, archived, thiếu service, nguồn bị đổi trong lúc ghi; mọi ca lỗi không tạo notification.

## AUD-04 — P1 — Hủy lịch cũ có thể mở lại follow-up đang gắn lịch khác

- Module/chủ sở hữu: M2 Phương + M3 Ngân.
- Bằng chứng: `backend/src/utils/followUps.js:3`: nhận appointmentId nhưng không kiểm tra với `snap.data().appointmentId`, accountId hay patientId; `reopenFollowUp` tại `:9` xóa appointmentId vô điều kiện. Các caller ở `appointments.js:594` và `:671`.
- Tái hiện: follow-up gắn appointment B nhưng appointment A cũ vẫn lưu followUpId; hủy A. Fake test `reminders-followup.test.cjs:238` nhận suggested thay vì giữ booked.
- Tác động: liên kết active bị xóa; có thể mở đường đặt thêm lịch active cho cùng đề xuất nếu dữ liệu đã lệch.
- Trạng thái: VERIFIED source + fake; không nói flow booking sạch tự tạo lệch liên kết này.
- Hướng sửa: xác nhận liên kết hai chiều, ownership và status bằng transaction trước reopen/complete.
- Hồi quy: stale A không sửa B; đúng A reopen; completed follow-up không bị lịch cũ đảo trạng thái.

## AUD-05 — P1 — Reminder ghi từ snapshot cũ, có race với hủy/read

- Module/chủ sở hữu: M4 Nhi + M2 Phương.
- Bằng chứng: `backend/src/jobs/reminders.js:5-15`: query → đọc user → ref.get → ref.set, không transaction/create precondition; không đọc lại appointment lúc ghi. Scheduler `:19` không chặn overlap; nhiều server/manual trigger có thể chạy cùng lúc.
- Tái hiện đề xuất bằng fake: pause job sau query confirmed, hủy và xóa notification, resume job; notification có thể được tạo lại. Hai job cùng đọc ref chưa có rồi một job ghi đè notification đã được read.
- Bằng chứng chạy: `reminders-followup.test.cjs:121` fail vì không có transaction conflict/recheck kỳ vọng. Đây chưa phải bằng chứng tải/concurrency Firebase thật.
- Tác động: nhắc lịch đã hủy, reset read/unread hoặc thay createdAt. ID cố định hạn chế nhiều document trùng nhưng không giải quyết race.
- Trạng thái: VERIFIED cấu trúc code; PARTIALLY VERIFIED tác động interleaving; Firebase concurrency NOT VERIFIED.
- Hướng sửa: transaction đọc appointment/preferences/reminder, ghi có điều kiện; guard overlap và lifecycle shutdown.
- Hồi quy: hủy/complete/tắt preference giữa read và write, 2 worker, restart, read đồng thời.

## AUD-06 — P1 — Không xem được lịch sử người thân đã archived

- Module/chủ sở hữu: Bình + Ngân, Nhi tích hợp UI.
- Bằng chứng: `backend/src/routes/familyMembers.js:16` ẩn archived; `backend/src/utils/records.js:20-23` từ chối archived; cả bốn list route `backend/src/routes/patients.js:10,18,26,34` dùng guard này. `PatientDataProvider.syncPatients` tại `frontend/lib/data/providers/patient_data_provider.dart:196` chỉ nhận danh sách active, focusVisit/focusFollowUp tại `:145/:169` yêu cầu bệnh nhân còn trong danh sách.
- Tái hiện: người thân có hồ sơ cũ, không còn lịch tương lai active, archive thành công; gọi GET patients/<id>/visits trả 403; danh sách chọn bệnh nhân không còn người đó.
- Tác động: dữ liệu vẫn tồn tại nhưng user không truy cập lịch sử qua UI/list API, trái thông báo xóa mềm. Detail có accountId có thể vẫn đọc được nhờ assertRecordAccess nên policy không nhất quán.
- Trạng thái: VERIFIED source; archived-history runtime trên Firebase NOT VERIFIED.
- Hướng sửa: tách quyền xem lịch sử khỏi quyền tạo lịch/ghi mới, thiết kế danh sách lịch sử archived theo account.
- Hồi quy: owner xem lịch sử archived, tài khoản khác 403, archived không đặt lịch mới được.

## AUD-07 — P2 — Thiếu reminder 2h và reminder tái khám

- Module/chủ sở hữu: M4 Nhi; Ngân/Phương xác nhận rule.
- Bằng chứng: toàn bộ `backend/src/jobs/reminders.js:3-19` chỉ duyệt confirmed appointment trong 24 giờ; ID không phân biệt mốc 24h/2h; không query follow_ups hoặc mốc 08:00 UTC+7. Fake `reminders-followup.test.cjs:90` mong follow-ups nhưng thực tế rỗng.
- Tái hiện: follow-up suggested đến hạn 3 ngày hoặc trong ngày; không có nhánh nào tạo reminder. Appointment đã có reminder 24h thì đến 2h vẫn cùng ID và bị skip.
- Tác động: khả năng được yêu cầu audit chưa được triển khai; không đánh đồng với event follow_up đã có.
- Trạng thái: **DEFERRED (out of demo scope)**, Nhi/Phương/Ngân đã xác nhận hoãn nhắc tái khám tự động. **Chưa triển khai, không FIXED.** Duy nhất test acceptance nhắc tái khám 3 ngày được đánh dấu TODO có callback, giữ toàn bộ assertion; TODO không tính PASS. Các mốc nhắc bổ sung vẫn chưa triển khai; giữ reminder appointment 24 giờ và scheduler 10 phút.
- Điều kiện mở lại: owners Nhi/Phương/Ngân duyệt timing/eligibility và policy rebook, triển khai theo phạm vi riêng, xác minh fake clock/acceptance criteria và bỏ TODO sau kiểm chứng. Không thay worker hoặc regression AUD-05/AUD-08 trong lần đóng baseline này.
- Hồi quy: 24h/2h, 3 ngày/ngày khám 08:00, rebook, legacy không followUpId, ngày UTC khác ngày VN.

## AUD-08 — P2 — Reminder cũ còn hiện sau hoàn tất/tắt preference

- Module/chủ sở hữu: M4 Nhi + M2 Phương + Bình.
- Bằng chứng: `backend/src/routes/appointments.js:603-611` chỉ xóa reminder trong nhánh rejected; completed không xóa. Cancel có xóa ID hiện tại tại `:677`. `backend/src/routes/notifications.js:20,29,34` list/count/read-all chỉ lọc userId/isRead; PATCH users/me chỉ lưu preference (`users.js:56`).
- Tái hiện: đã có unread appointment_reminder rồi staff completed hoặc user tắt notification; list/count vẫn tính document cũ. Đổi lịch qua công cụ khác cũng không có cleanup ID ngày/giờ cũ trong job.
- Tác động: chuông còn báo nhắc không còn phù hợp. Các endpoint nhất quán với nhau về owner, nhưng không có source-validity policy. Test xóa reminder legacy fail còn liên quan khác biệt format ID, không quy toàn bộ cho lỗi này.
- Trạng thái: **FIXED (fake), đã được người phụ trách tích hợp nghiệm thu.** Backend lọc hiệu lực appointment_reminder theo nguồn/owner/lịch/preference; giữ event history và reminder document. AUD-08: 43 PASS, AUD-05: 25 PASS; backend toàn bộ 630 PASS / 8 FAIL / 0 SKIP (8 lỗi baseline ngoài phạm vi). **Chưa có Firebase E2E PASS.**
- Hướng sửa: định nghĩa cleanup/source-filter policy dùng chung list/count/read-all và các transition.
- Hồi quy: completed/cancelled/rejected, đổi giờ, off/on preference; giữ event notification theo policy đã thống nhất.

## AUD-09 — P2 — Parse ngày backend quá rộng, không có quy ước clinic rõ

- Module/chủ sở hữu: M3 Ngân.
- Bằng chứng: `backend/src/utils/clinical.js:7` dùng new Date(v); `backend/src/routes/followUps.js:18-19` tương tự, không kiểm tra ngày tương lai. `treatments.js:62` gọi optionalDate.
- Tái hiện fake: `clinical-records.test.cjs:264` nhập 01/02/2099 được 201; follow-up 2020-01-01 được 201. Ca date-only được UTC midnight, lệch expectation clinic 09:00 trong test tại `:249/:338`.
- Tác động: ngày mơ hồ, lịch tái khám đã qua hoặc thời điểm hiển thị không đúng quy ước dự kiến. 09:00 là expectation test, chưa khẳng định là quy tắc sản phẩm đã duyệt.
- Trạng thái: VERIFIED source + fake; acceptance time-of-day PARTIALLY VERIFIED.
- Hướng sửa: chốt contract ISO/date-only và timezone; từ chối format mơ hồ và ngày không hợp lệ/đã qua theo nghiệp vụ.
- Hồi quy: DD/MM vs MM/DD, ngày không tồn tại, offsets, date-only, biên UTC/VN.

## AUD-10 — P2 — Completion nhận payload clinical sai rồi bỏ qua

- Module/chủ sở hữu: M3 Ngân.
- Bằng chứng: `backend/src/utils/clinical.js:10-14` chỉ kiểm tra array/length prescriptions; visit sai kiểu đổi thành {}; không validate từng thuốc hay invoice.
- Tái hiện: fake suite có các ca visit chuỗi, thiếu medicineName, durationDays 0/2.5, invoice.items rỗng, giá âm, paid chuỗi đều fail vì route nhận thành công.
- Tác động: caller tưởng đã ghi đúng dữ liệu khám; input không được báo lỗi. Liên quan AUD-01 nhưng nguyên nhân riêng ở validation.
- Trạng thái: VERIFIED source + fake.
- Hướng sửa: schema/validator có giới hạn kiểu, số lượng, giá, text; fail trước đổi status.
- Hồi quy: ma trận invalid payload hiện có, đảm bảo không có partial writes.

## AUD-11 — P2 — Không phân trang và N+1 reads khi tải records

- Module/chủ sở hữu: Ngân + Nhi; các owner backend phối hợp.
- Bằng chứng còn mở: `PatientDataProvider.loadRecords` trong `frontend/lib/data/providers/patient_data_provider.dart` vẫn tải 4 list bắt buộc, rồi tối đa 2 request/visit, 1/invoice và 2/treatment tuần tự. Snapshot đầy đủ vẫn có công thức 4+2V+I+2T; chưa thay đổi backend hoặc API contract.
- AUD-11A: chỉ bỏ qua HTTP 404 của detail/Rx/sessions sau khi xác minh ID trong list hiện tại; bỏ nguyên nhóm parent/children tương ứng. Một phần thiếu có cảnh báo và tải lại; toàn bộ detail không khả dụng có lỗi và retry, không hiện empty state. List lỗi, lỗi quyền/network/server, response hỏng và linkage mâu thuẫn vẫn là lỗi tải.
- Navigation: selector đổi patient chỉ gọi một lượt tải; notification focus phải tìm thấy target trong snapshot mới, giữ mã lỗi API và không dùng detail cũ. Giữ request-generation/session isolation.
- Trạng thái: **PARTIALLY FIXED (fake) — AUD-11A. N+1/pagination vẫn OPEN.** Performance runtime chưa xác minh; **chưa có Firebase E2E PASS**.
- Hồi quy AUD-11A: Flutter default/mock 115 PASS / 0 FAIL / 4 SKIP; API fake 104 PASS / 0 FAIL / 0 SKIP; cả hai exit code 0. Bốn skip là điều kiện API có sẵn của private-session tests, chạy PASS ở cấu hình API fake; không thêm skip. Hai lượt có test trùng, không cộng thành tổng coverage riêng biệt. `flutter analyze --no-pub`: PASS, không có issue.
- Fixture archived follow-up được bổ sung target vào list cho ca focus thành công; ca target biến mất khỏi list có regression riêng xác minh không điều hướng. Không nới assertion hoặc quyền orphan/archived.
- Phần tiếp theo vẫn cần duyệt riêng: đo latency/reads, pagination/cursor, summary contract hoặc lazy-load detail. Không triển khai các phần đó trong AUD-11A.

## AUD-12 — P2 — Lệnh test backend bỏ suite chính; test helper không cô lập Firebase

- Module/chủ sở hữu: QA Nhi + các owner backend.
- Bằng chứng: `backend/package.json:9` script `node --test test/**/*.test.js`, trong khi suites module2/3/4 là `.test.cjs`; `backend/test/booking-safeguards.test.js:3` import utils/booking, `backend/src/utils/booking.js:1` import config Firebase thật, không installFakeFirebase.
- Tái hiện: đối chiếu glob với file extensions; helper import dẫn tới config đọc credential. Không chạy npm test hay helper này trong audit.
- Tác động: test command không bao phủ suite cjs; không phù hợp audit offline vì có thể nạp credential/SDK thật dù assertion chỉ dùng hàm thuần.
- Trạng thái: VERIFIED source; test helper SKIP theo yêu cầu an toàn. Không khẳng định helper đã ghi Firebase.
- Hướng sửa: tách pure helpers khỏi initialization; test entrypoint explicit và fail nếu nạp config thật.
- Hồi quy: chạy không credential/network, discovery đếm đủ suites, không khởi động server/job thật.

## AUD-13 — P2 — Suite media lỗi ngay khi load

- Module/chủ sở hữu: Ngân + Bình, Nhi QA.
- Bằng chứng: `backend/test/module3/media.test.cjs:10` import MAX_IMAGE_BYTES nhưng `backend/src/utils/media.js:39` không export constant; `media.test.cjs:124` dùng kích thước tính từ undefined.
- Tái hiện: lệnh backend audit báo Buffer.alloc size NaN; file suite thất bại trước các test ảnh.
- Tác động: chưa kiểm chứng được ảnh/avatar qua suite này; đây là lỗi tương thích test/code, không suy ra upload runtime hỏng.
- Trạng thái: VERIFIED runtime fake; media acceptance BLOCKED bởi harness.
- Hướng sửa: nhóm thống nhất public constant và contract ảnh; audit không tự sửa test.
- Hồi quy: suite load được, JPEG/PNG/size/ownership/atomic replacement/rollback.

## AUD-14 — P2 — Staff/admin policy không nhất quán giữa endpoint

- Module/chủ sở hữu: Bình + Ngân.
- Bằng chứng: `backend/src/middleware/requireStaff.js:3` chấp nhận staff/admin boolean hoặc role; `backend/src/routes/treatments.js:283` chỉ nhận role staff cho ảnh; `backend/src/routes/followUps.js:9` không nhận role admin. Visit/invoice/treatment detail chỉ gọi owner access.
- Tái hiện đề xuất fake: cùng identity có staff:true nhưng không role staff được tạo treatment, sau đó xem/tải ảnh của patient khác bị đi vào nhánh owner; role admin không được nhận ở GET follow-up.
- Tác động: nhân viên có claim hợp lệ cho thao tác tạo nhưng bị từ chối ở thao tác liên quan. Chưa chứng minh bypass, P0 không phù hợp.
- Trạng thái: **BLOCKED — awaiting owner policy approval (Bình + Ngân).** Chưa triển khai thay đổi authorization; không ghi FIXED. Ma trận claim runtime và Firebase E2E chưa được xác minh.
- Hướng sửa: chốt quyền đọc/ghi clinical của staff/admin, dùng policy chung từ verified claims.
- Hồi quy: patient/staff:true/admin:true/role staff/role admin theo từng endpoint, không tin role từ request body.

## AUD-15 — P3 — Comment body limit không khớp middleware

- Module/chủ sở hữu: backend chung; Bình/Phương/Ngân xác nhận phương án B cho demo.
- Contract đã duyệt: JSON request body toàn API **1 MiB = 1.048.576 bytes**, giữ nguyên `express.json({ limit: '1mb' })`. Ảnh sau giải mã **716.800 bytes**, không đổi `MAX_IMAGE_BYTES`.
- Thay đổi: đồng bộ media tests, comment trong `server.js`, README và demo checklist. Không thay production behavior, field validation, authorization, schema/Rules hoặc response contract.
- Trạng thái: **FIXED (fake)** sau kiểm thử. Chưa có Firebase E2E PASS.
- Hồi quy: đo `Buffer.byteLength(JSON.stringify(body), 'utf8')`; JSON dưới/đúng 1 MiB nhưng address sai trả 400 và không ghi; vượt 1 MiB trả 413 trước route trên profile/ba endpoint ảnh, không ghi. Ảnh đúng 716.800 bytes được nhận khi JSON trong giới hạn; vượt giới hạn ảnh trả 413, không ghi.
- Kết quả: discovery/isolation 20 PASS / 0 FAIL / 0 SKIP / 0 TODO; media/reminder 162 PASS / 0 FAIL / 0 SKIP / 1 TODO; AUD-05/AUD-08 68 PASS / 0 FAIL / 0 SKIP / 0 TODO; npm test **650 PASS / 0 FAIL / 0 SKIP / 1 TODO**, exit 0. Nhóm con có coverage trùng, không cộng tổng. TODO duy nhất là AUD-07 deferred, không phải tính năng đã hoàn thành.
- Đối chiếu baseline 644 PASS / 2 FAIL / 0 SKIP: body-limit được xử lý; một FAIL AUD-07 chuyển TODO theo phê duyệt; thêm 5 test transport/boundary. Không xóa hoặc skip test.

## AUD-16 — P3 — Handover và log khởi động lỗi thời

- Module/chủ sở hữu: Nhi, từng owner xác nhận phần mình.
- Bằng chứng: `frontend/docs/handover/NHI_NEXT_STEPS.md:6` nói default mock; `BOOKING_TO_FOLLOWUP_INTEGRATION.md:21` nói không lưu followUpId; `CONTENT_MODULE_HANDOVER.md:46` nói chưa có badge. Source AppConfig default api, appointments lưu followUpId, Home có Badge. `frontend/lib/main.dart:36` còn log patient flows demo. `backend/README.md:167-172` mô tả invoice/rx mà completion chưa ghi.
- Tái hiện: đối chiếu source với câu tài liệu, không dùng báo cáo cũ làm chứng cứ PASS.
- Tác động: demo/triage và bàn giao dựa trên trạng thái sai.
- Trạng thái: VERIFIED đối chiếu văn bản/source.
- Hướng sửa: sau khi sửa và kiểm chứng, cập nhật tài liệu theo source; nêu rõ mock vs Firebase.
- Hồi quy: checklist tài liệu, command/config/feature inventory khớp hiện trạng.

## AUD-17 — P2 — Ba test UI dừng vì nhãn avatar cũ

- Module/chủ sở hữu: Bình + Nhi QA.
- Bằng chứng: `frontend/test/me_test.dart:248` expect Thay ảnh (demo); `frontend/lib/features/me/edit_profile_screen.dart:119` hiển thị Thay ảnh.
- Tái hiện: flutter test cả default và api, các width 360/390/430 đều fail cùng assertion Found 0.
- Tác động: kiểm tra các destination tiếp theo trong cùng test không được thực hiện; không có bằng chứng đây là overflow.
- Trạng thái: **FIXED (fake), đã được người phụ trách tích hợp nghiệm thu.** Nhãn đúng là `Thay ảnh`; giữ assertion `findsOneWidget`. `me_test.dart`: 17 PASS, gồm cả 3 width 360/390/430 chạy hết destination/back và các test keyboard/profile. Regression liên quan default/mock: 60 PASS / 0 FAIL / 5 SKIP; API fake (suite avatar/profile/session riêng): 47 PASS / 0 FAIL / 1 SKIP; analyze PASS. Không thêm skip. Chưa chạy toàn Flutter suite, chưa xác minh thiết bị/Firebase E2E.
- Hướng sửa: nhóm xác nhận label đúng rồi cập nhật expectation có chủ đích; không thay source/test trong audit.
- Hồi quy: toàn bộ destination, keyboard, text scale, back ở 3 width chạy hết; không chỉ đổi assertion để xanh.

## AUD-18 — P2 — Chưa có rate limiting trong Express app

- Module/chủ sở hữu: Bình + Phương, backend chung.
- Bằng chứng: `backend/src/server.js:1-52` middleware CORS/parser/routes/error; package.json không có limiter; các route public quote/availability quét dữ liệu, reminder manual có auth staff nhưng không throttle.
- Tái hiện về mặt code: một client có thể lặp request, không có nhánh 429/window trong app. Không thực hiện load test hay spam API thật.
- Tác động: thiếu kiểm soát tải/read cost ở application layer. Gateway/proxy rate limit triển khai ngoài repo NOT VERIFIED, không khẳng định toàn hệ thống không được bảo vệ.
- Trạng thái: VERIFIED gap trong source; mức phơi nhiễm triển khai NOT VERIFIED.
- Hướng sửa: xác nhận hạ tầng trước, định budget/limit phù hợp public vs authenticated endpoint.
- Hồi quy: giới hạn theo identity/IP, retry headers, tránh chặn người dùng chung mạng; load test chỉ sandbox được duyệt.
