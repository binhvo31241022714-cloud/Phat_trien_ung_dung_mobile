# Phân loại và xử lý 41 test API-mode — 31/10/2026

## Kết quả

Tái hiện đúng baseline: **301 PASS, 41 FAIL, 13 SKIP**. Sau sửa: lệnh toàn bộ API-mode **359 PASS, 0 FAIL, 13 SKIP**; Flutter mặc định **241 PASS, 0 FAIL, 131 SKIP**; backend fake **87 PASS**; analyze không có issue.

**41/41 test lỗi ban đầu hiện đều được chạy và đạt, không test nào bị xóa hoặc chuyển sang skip.** Kiểm tra danh sách JSON cho thấy giữ đủ 355 test baseline, thêm 17 test mới; 13 skip của lệnh API là đúng 13 test đã skip trong baseline. Không có regression quan sát được trong hai lệnh toàn bộ.

Phải phân biệt phạm vi: 32/41 là kịch bản dành riêng cho MockData/local-demo, nay khai báo rõ mode mock theo fixture; 9/41 tiếp tục chạy API và được sửa DI/session/kỳ vọng hiện hành. Không coi 32 test này là bằng chứng API. Thêm **17 test API đối ứng** chạy với `AppConfig=api` trong cả lệnh mặc định và lệnh API, dùng service/provider thật cùng MockClient và PrivateSession; không dùng subclass provider để giả kết quả. Runtime mặc định vẫn API, test runner không đổi, không thêm skip.

Không sửa file runtime `lib/`, backend, dependency, schema, contract, phân quyền hoặc dữ liệu lâm sàng. **0/41 cần BLOCKED để Bình/Phương/Ngân đổi nghiệp vụ.** A05/A08/A10 vẫn là 3 quyết định tồn đọng độc lập; A21 vẫn cần Ngân xác nhận status contract. Không triển khai A03/A23, không đọc secret, không chạy Git và không ghi Firebase thật.

## Nhóm nguyên nhân

| Nhóm | Số test | Nguyên nhân chung | Cách xử lý |
|---|---:|---|---|
| G1 | 26 | 25 thiếu ContentProvider, 1 thiếu CatalogProvider trong helper khi fixture demo bị chạy ở nhánh API | Khai báo đúng mode demo; có API counterpart inject đầy đủ graph; scroll test độc lập mode bổ sung hai provider thiếu |
| G2 | 3 | Provider đọc demo/read-only/local collections/notify count nhưng DATA_SOURCE là API | Scope mock cho đúng contract local; test API đối ứng tải Records qua HTTP và xác minh session |
| G3 | 1 | Test giá local so với Controller API chưa có quote HTTP | Scope đúng bài test local; thêm test API lấy quote qua service và kiểm tra request |
| G4 | 4 | Helper Me không bind ContentProvider theo user session | BindUser trong API mode, Home fixture đúng schema; notification demo cũ tách scope và có counterpart API |
| G5 | 4 | UID/family API bị so với patient-001/số người mock | Assert UID/danh sách theo response và A04; giữ nhánh mock cũ |
| G6 | 2 | Local savedArticleIds bị kỳ vọng xuất hiện trong server favorites API | Giữ bài test local có scope; thêm bookmark/Saved/filter/delete thật qua HTTP giả |
| G7 | 1 | Logout API bị kỳ vọng còn lịch mock | Assert dữ liệu riêng bị xóa ở API; counterpart dùng PrivateSession và kiểm tra Back |

Các lỗi là setup/fixture/kỳ vọng mode; không thấy bằng chứng lỗi môi trường hay nhu cầu đổi contract trong 41 lỗi tái hiện. “Regression do commit nào” không thể xác định chỉ từ workspace và log; không sử dụng Git theo yêu cầu. Chỉ khẳng định cả 41 có trước đợt sửa này và không tái diễn sau sửa.

## Bảng đầy đủ 41 test

`test/` là gốc của các đường dẫn dưới đây. Module là nơi sở hữu hành vi đang kiểm tra, không có nghĩa đã sửa nghiệp vụ module đó. Mỗi test đều PASS, executed, không skip. Chi tiết stack/testID trong [JSON phân loại](../../qa_artifacts/api_mode_41/classification.json), bản [CSV](../../qa_artifacts/api_mode_41/classification.csv). Cột regression của mọi dòng: **chưa đủ bằng chứng quy cho thay đổi gần đây; đã có trong baseline**.

| ID | File / tên test | Thông báo lỗi trước sửa | Root cause / nhóm | Module | Loại | Mode sau sửa |
|---|---|---|---|---|---|---|
| T01 | patient_data_test.dart<br>provider chia sẻ dữ liệu và phát thông báo khi đổi bệnh nhân | Expected: true   Actual: <false> | G2: Kỳ vọng read-only demo hoặc đúng 3 notify; API mode có loadRecords bất đồng bộ nên thêm notify. | 1/3/4, tích hợp | Kỳ vọng test sai theo DATA_SOURCE (không phải contract mới) | mock (demo contract) |
| T02 | patient_data_test.dart<br>provider chia sẻ bệnh nhân, thông báo và bài viết đã lưu | Expected: <3>   Actual: <4> | G2: Kỳ vọng read-only demo hoặc đúng 3 notify; API mode có loadRecords bất đồng bộ nên thêm notify. | 1/3/4, tích hợp | Kỳ vọng test sai theo DATA_SOURCE (không phải contract mới) | mock (demo contract) |
| T03 | booking_test.dart<br>services, total and steps preserve selections | Expected: <500000>   Actual: <0> | G3: Test tổng giá local nhưng BookingController API chờ báo giá HTTP; chưa có quote nên total=0. | 2 | Test setup / thiếu fixture | mock (demo contract) |
| T04 | records_test.dart<br>filter every collection and stable appointment ordering by patient | Expected: an object with length of <1>   Actual: []    Which: has length of <0> | G2: Seed MockData nhưng getter API chỉ đọc _apiVisits chưa tải; test lọc demo chưa khai báo mode. | 3, tích hợp | Kỳ vọng test sai theo DATA_SOURCE (không phải contract mới) | mock (demo contract) |
| T05 | records_test.dart<br>overview filters relatives, counts and keeps account at 360.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T06 | widget_test.dart<br>MainShell không hiển thị màn hình quản lý người dùng | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T07 | final_qa_test.dart<br>large text and short viewport across four tabs 360.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T08 | records_test.dart<br>visit, prescription, receipt, treatment photos and back fit 360.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T09 | final_qa_test.dart<br>large text and short viewport across four tabs 390.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T10 | widget_test.dart<br>luồng đăng nhập, chuyển tab, chi tiết, Back và đăng xuất | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T11 | final_qa_test.dart<br>large text and short viewport across four tabs 430.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T12 | records_test.dart<br>overview filters relatives, counts and keeps account at 390.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T13 | final_qa_test.dart<br>Home article bookmark reaches Saved and removes in both places | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T14 | records_test.dart<br>visit, prescription, receipt, treatment photos and back fit 390.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T15 | records_test.dart<br>overview filters relatives, counts and keeps account at 430.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T16 | records_test.dart<br>visit, prescription, receipt, treatment photos and back fit 430.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T17 | records_test.dart<br>live shared appointment, confirmation, cancellation and Home update | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T18 | scroll_behavior_test.dart<br>real App routes and all four tabs inherit the shared behavior | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4, tích hợp | Test setup / thiếu fixture | API |
| T19 | records_test.dart<br>followup and empty appointments open booking for correct patient without submitting | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T20 | records_test.dart<br>missing optional visit records hide actions; result route shows supplied read-only data | ProviderNotFoundException: Provider<CatalogProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T21 | records_test.dart<br>empty appointments start a draft for the selected relative | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T22 | records_test.dart<br>past followup passes relative only, retains stack, does not create an appointment | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T23 | records_test.dart<br>multiple treatment plans open the matching detail and progress | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 3, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T24 | me_test.dart<br>all six account destinations, settings, password and FAQ fit 360.0 | Expected: exactly one matching candidate Actual: _TextWidgetFinder:<Found 0 widgets with text "Tất cả": []> Which: means none were found but one was expected | G4: ContentProvider trong helper không bind phiên user nên màn API yêu cầu đăng nhập, không có danh sách notification. | 1/4, tích hợp | Test setup / thiếu fixture | API |
| T25 | content_handover_test.dart<br>long article scrolls and bookmark stays unique at 360.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4 | Test setup / thiếu fixture | mock (demo contract) |
| T26 | me_test.dart<br>profile validation, keyboard and PATCH /api/users/me at 360.0 | Expected: 'patient-001' Actual: 'uid-test' Which: is different. Expected: patient-00 ... Actual: uid-test ^ Differ at offset 0 | G5: Kỳ vọng danh tính/danh sách mock giữ nguyên; hợp đồng API đồng bộ UID và family từ ProfileProvider (A04). | 1/4, tích hợp | Kỳ vọng test sai theo DATA_SOURCE (không phải contract mới) | API |
| T27 | content_handover_test.dart<br>long article scrolls and bookmark stays unique at 390.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4 | Test setup / thiếu fixture | mock (demo contract) |
| T28 | content_handover_test.dart<br>long article scrolls and bookmark stays unique at 430.0 | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4 | Test setup / thiếu fixture | mock (demo contract) |
| T29 | content_handover_test.dart<br>new appointment and cancellation immediately update Home | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4 | Test setup / thiếu fixture | mock (demo contract) |
| T30 | content_handover_test.dart<br>missing description and invalid image asset render fallback | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4 | Test setup / thiếu fixture | mock (demo contract) |
| T31 | content_handover_test.dart<br>empty article list has a real empty state | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4 | Test setup / thiếu fixture | mock (demo contract) |
| T32 | content_handover_test.dart<br>missing notification text and repeated category changes preserve data | ProviderNotFoundException: Provider<ContentProvider> | G1: Helper dùng demo fixture thiếu provider khi rẽ vào UI API; không phải thiếu provider trong main.dart. | 4 | Test setup / thiếu fixture | mock (demo contract) |
| T33 | me_test.dart<br>all six account destinations, settings, password and FAQ fit 390.0 | Expected: exactly one matching candidate Actual: _TextWidgetFinder:<Found 0 widgets with text "Tất cả": []> Which: means none were found but one was expected | G4: ContentProvider trong helper không bind phiên user nên màn API yêu cầu đăng nhập, không có danh sách notification. | 1/4, tích hợp | Test setup / thiếu fixture | API |
| T34 | me_test.dart<br>profile validation, keyboard and PATCH /api/users/me at 390.0 | Expected: 'patient-001' Actual: 'uid-test' Which: is different. Expected: patient-00 ... Actual: uid-test ^ Differ at offset 0 | G5: Kỳ vọng danh tính/danh sách mock giữ nguyên; hợp đồng API đồng bộ UID và family từ ProfileProvider (A04). | 1/4, tích hợp | Kỳ vọng test sai theo DATA_SOURCE (không phải contract mới) | API |
| T35 | me_test.dart<br>all six account destinations, settings, password and FAQ fit 430.0 | Expected: exactly one matching candidate Actual: _TextWidgetFinder:<Found 0 widgets with text "Tất cả": []> Which: means none were found but one was expected | G4: ContentProvider trong helper không bind phiên user nên màn API yêu cầu đăng nhập, không có danh sách notification. | 1/4, tích hợp | Test setup / thiếu fixture | API |
| T36 | me_test.dart<br>profile validation, keyboard and PATCH /api/users/me at 430.0 | Expected: 'patient-001' Actual: 'uid-test' Which: is different. Expected: patient-00 ... Actual: uid-test ^ Differ at offset 0 | G5: Kỳ vọng danh tính/danh sách mock giữ nguyên; hợp đồng API đồng bộ UID và family từ ProfileProvider (A04). | 1/4, tích hợp | Kỳ vọng test sai theo DATA_SOURCE (không phải contract mới) | API |
| T37 | me_test.dart<br>family list states and add/edit/delete via API | Expected: <2> Actual: <1> | G5: Kỳ vọng danh tính/danh sách mock giữ nguyên; hợp đồng API đồng bộ UID và family từ ProfileProvider (A04). | 1/4, tích hợp | Kỳ vọng test sai theo DATA_SOURCE (không phải contract mới) | API |
| T38 | me_test.dart<br>notifications filter, mark read, preserve category and open linked appointment | Bad state: No element | G4: ContentProvider trong helper không bind phiên user nên màn API yêu cầu đăng nhập, không có danh sách notification. | 1/4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T39 | me_test.dart<br>saved items load from /api/favorites, open details and remove | Expected: exactly one matching candidate Actual: _TextWidgetFinder:<Found 0 widgets with text "Chải răng đúng cách để bảo vệ nụ cười": []> Which: means none were found but one was expected | G6: Ghi bookmark vào PatientDataProvider local nhưng màn API chỉ đọc server favorites qua CatalogProvider. | 1/4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T40 | me_test.dart<br>saved tabs filter, show counts and update after removal | Expected: exactly one matching candidate Actual: _TextWidgetFinder:<Found 0 widgets with text "Bài viết (1)": []> Which: means none were found but one was expected | G6: Ghi bookmark vào PatientDataProvider local nhưng màn API chỉ đọc server favorites qua CatalogProvider. | 1/4, tích hợp | Test setup / thiếu fixture | mock (demo contract) |
| T41 | me_test.dart<br>logout cancellation, confirmed session clearing, no Back to shell and login again | Expected: non-empty Actual: [] | G7: Kỳ vọng dữ liệu demo còn sau logout; API phải clearPrivateState để bảo vệ dữ liệu tài khoản. | 1/4, tích hợp | Kỳ vọng test sai theo DATA_SOURCE (không phải contract mới) | API |

## Test API đối ứng và giới hạn

`test/api_mode_parity_test.dart` có 17 test mới, bắt buộc API mode trong từng test và tự khôi phục cấu hình khi kết thúc:

- Bốn tab ở 360/390/430 px, chữ 1.5, viewport thấp: dữ liệu Home/Profile/Catalog/Records/Appointment từ HTTP fixture.
- Cuộn bài dài, bookmark qua POST `/api/favorites`, mở Saved, DELETE favorite tại cả ba kích thước; xác nhận không ghi savedArticleIds local.
- Chọn người thân từ dropdown Records: giữ danh tính primary account, thay selected patient theo hành vi API hiện hành, chỉ hiện visit đúng người; mở đơn thuốc/hóa đơn với visitId khác appointmentId.
- Counts/progress liệu trình lấy từ GET; status thiếu vẫn “Trạng thái chưa cập nhật”, không bổ sung enum lâm sàng.
- Follow-up mở draft đúng người/dịch vụ, không POST appointment; không triển khai followUpId đang chờ duyệt.
- Lọc thông báo, mark-read qua PATCH, cache lịch rỗng vẫn GET detail và mở đúng lịch.
- Nội dung/ngày/ảnh tùy chọn sai hoặc thiếu có fallback, danh sách bài API rỗng thực sự gọi GET.
- Bài notification thiếu title/body vẫn lọc lặp lại an toàn.
- Saved tabs đúng favorite service/doctor/article trên HTTP, bỏ bài cuối xóa tab và cập nhật số lượng.
- Hủy lịch qua PATCH, giữ lịch không ghi, Home tải lại từ HTTP và không còn lịch active.
- Login/logout và Back qua App thật, PrivateSession xóa patients/appointments/notifications/favorites; scroll configuration kế thừa trên bốn tab.
- Booking quote dùng giá response HTTP 125000, không lấy giá MockData.

Auth và transport trong fixture vẫn giả; không kiểm tra Firebase token thật, Firestore index/rules, OS lifecycle, ảnh mạng thật hoặc quyền thiết bị. Fixture không phải triển khai backend và không chứng minh backend phân quyền — phần đó có test Node fake hiện có. Không đánh dấu A05/A08/A10/A21 DONE bằng các test này.

## Lệnh và kết quả thực tế

Chạy tại `frontend/`:

```sh
# Tái hiện baseline trước sửa: 301 PASS, 41 FAIL, 13 SKIP
flutter test --dart-define=DATA_SOURCE=api --reporter=json

# Nhóm 8 suite có lỗi sau sửa scope/setup: 65 PASS, 0 FAIL, 0 SKIP
flutter test --dart-define=DATA_SOURCE=api test/patient_data_test.dart test/booking_test.dart test/records_test.dart test/widget_test.dart test/final_qa_test.dart test/content_handover_test.dart test/me_test.dart test/scroll_behavior_test.dart

# Sau sửa binding ContentProvider và thêm API counterpart: 39 PASS, 0 FAIL, 0 SKIP
flutter test --dart-define=DATA_SOURCE=api test/api_mode_parity_test.dart test/me_test.dart test/profile_fields_test.dart test/family_archive_test.dart

# Mở rộng API counterpart: 17 PASS, 0 FAIL, 0 SKIP
flutter test test/api_mode_parity_test.dart

# Cuối đợt, toàn bộ API command: 359 PASS, 0 FAIL, 13 SKIP
flutter test --dart-define=DATA_SOURCE=api --reporter=json

# Cuối đợt, toàn bộ default command: 241 PASS, 0 FAIL, 131 SKIP
flutter test --reporter=json

# No issues found
flutter analyze
```

Chạy tại `backend/`: `node --test test/module2/*.test.cjs test/module3/*.cjs test/module4/*.cjs` → **87 PASS, 0 FAIL, 0 SKIP** (fake Firestore).

Số test toàn bộ tăng từ 355 lên 372 do thêm 17 API counterpart. Không đổi skip của bất kỳ test baseline nào. Lệnh API command bao gồm test có fixture mock tường minh — không đồng nghĩa 359 test đều đi qua API. Test mặc định cũng chạy 17 counterpart API vì các test đó khai báo mode riêng. Không đổi test runner để ép tất cả test sang mock.

Chứng cứ máy đọc được ở `frontend/qa_artifacts/api_mode_41/`: `before.jsonl`, `api_final.jsonl`, `default_final.jsonl`, `classification.json`, `classification.csv`; log các nhóm, analyze và backend cùng thư mục. JSON reporter giữ message/stack theo testID, không thu thập thông tin xác thực.

## File đã sửa trong đợt xử lý 41 test

| File tính từ frontend/ | Thay đổi | Phạm vi |
|---|---|---|
| test/support/data_source_scope.dart (mới) | Scope mode theo fixture, addTearDown khôi phục; không skip | Test infrastructure |
| test/support/api_app_fixture.dart (mới) | HTTP fixture, production provider/service graph, PrivateSession, ghi request và fail route ngoài fixture | API integration tests |
| test/api_mode_parity_test.dart (mới) | 17 test API đối ứng, chạy cả ở lệnh default | Module 4 và tích hợp 1/2/3 |
| test/support/empty_content_provider.dart | Home response đủ bốn trường contract thay vì `{}` | Module 4 fixture |
| test/patient_data_test.dart | Khai báo MockData fixture cho các phép kiểm tra demo/local | Test tích hợp |
| test/booking_test.dart | Chỉ scope test tính giá local; widget/API tests khác giữ mode người gọi | Module 2 tests, không đổi nghiệp vụ |
| test/records_test.dart | Scope rõ kịch bản demo, giữ các assertion/mock flow cũ | Module 3 tests, không đổi dữ liệu lâm sàng |
| test/content_handover_test.dart | Scope các fixture local article/notification | Module 4 tests |
| test/final_qa_test.dart | Scope kiểm tra demo layout/local bookmark | Module 4 tests |
| test/widget_test.dart | Scope demo navigation/fixture; API counterpart kiểm tra login và session thật của app bằng HTTP giả | Flutter integration |
| test/scroll_behavior_test.dart | Bổ sung ContentProvider/AppointmentsProvider cho helper; vẫn theo source người gọi | Flutter integration |
| test/me_test.dart | Bind ContentProvider trong API mode; UID/family/clearing theo contract; ba test bookmark/notification local scope mock | Module 1/4 tests |
| test/profile_fields_test.dart | Khi phiên API đã bind, kỳ vọng hộp thư rỗng thay cho yêu cầu đăng nhập | Module 1/4 regression |
| docs/handover/API_MODE_41_TEST_REVIEW.md (mới) | Báo cáo đầy đủ, bảng 41 test và giới hạn | Nhi |
| docs/handover/INTEGRATION_AUDIT_962a981.md | Trỏ báo cáo mới; giữ snapshot lịch sử | Nhi |
| qa_artifacts/api_mode_41/* | Bằng chứng kết quả, CSV/JSON phân loại | QA |

## BLOCKED và khả năng chuyển sang Firebase

Không có lỗi nào trong 41 test phải sửa nghiệp vụ Module 1/2/3: **0 BLOCKED mới**. Các hạng mục riêng vẫn giữ nguyên: A05 cần Bình/Ngân duyệt API archived, A08 cần Phương/Ngân duyệt followUpId/idempotency, A10 cần Ngân/Phương chốt điều kiện completed; A21 cần contract trạng thái. Chi tiết đề xuất trong báo cáo audit gốc, chưa sửa các phần đó.

Không thấy regression trong phạm vi kiểm thử: tất cả 355 test baseline còn nguyên danh tính, 41 lỗi ban đầu đều executed PASS, default suite vẫn 0 FAIL, skip không tăng và thêm 17 API tests cũng đạt. Chưa có bằng chứng để suy ngược commit gây ra lỗi từ trước; không dùng Git để tìm.

Đã đủ điều kiện về unit/widget/fake integration để **lập bước kiểm thử Firebase sandbox tiếp theo**, chưa đủ để nghiệm thu Firebase thật hoặc tuyên bố mọi luồng demo hoàn tất. Cần xác minh riêng đăng nhập/token thật, địa chỉ backend trên thiết bị, dữ liệu/catalog/index, các GET có phân quyền và kịch bản ghi đã được người dùng duyệt. Chưa thực hiện các request đó trong đợt này. A05/A08/A10/A21 không nằm trong phạm vi có thể nghiệm thu đầy đủ trước khi được chốt.
