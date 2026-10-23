# Bàn giao Android-only — cập nhật Prompt 12.7

Trạng thái hiện tại: **PRE-COMMIT**, chưa commit/push. Nhi đã duyệt phạm vi Flutter
source/config/dependencies/tests + Android + frontend docs. Danh sách chính xác
154 file ở [FRONTEND_COMMIT_FILES.txt](FRONTEND_COMMIT_FILES.txt); nguồn hash hiện
tại ở [FRONTEND_ANDROID_PRECOMMIT_MANIFEST.json](FRONTEND_ANDROID_PRECOMMIT_MANIFEST.json).

## Phân biệt hai mốc

- **Prompt 12 lịch sử:** 254 file runtime/platform/tests/config được snapshot,
  97 Flutter tests, analyzer không lỗi, hai Android scenario, HTTP attempts=0.
  Toàn bộ báo cáo gốc được giữ bên dưới; không đổi kết quả hoặc aggregate SHA256.
- **Prompt 12.7 Android-only:** 149 file được duyệt + bốn docs đồng bộ + một manifest
  mới = 154 file đề xuất stage. Không có source iOS/web/macOS/Linux/Windows, tám
  scaffold rỗng, backend/root hoặc artifact QA trong phạm vi mới.
- Hash hiện tại là hash **PRE-COMMIT** của byte file sau đồng bộ docs, không có
  nghĩa 154 file vừa được chạy lại tests. Không dùng manifest lịch sử 254 file để
  xác định nội dung commit mới. Danh sách staged phải đối chiếu manifest mới.

Không thay UI, Provider, mock, API contract hoặc Android ID/signing. Không chạy
API thật, Firebase, tests/build hoặc clone sạch trong Prompt 12.7. Các câu "chưa
stage" và checklist chưa xác nhận trong báo cáo gốc chỉ nói về thời điểm Prompt 12.

Gói log/ảnh được bàn giao riêng, không stage trong commit source. Các liên kết QA
trong báo cáo gốc và QA_RESULTS.md cần gói artifact tương ứng để mở trên máy nhận.
README vẫn chạy Mock không cần backend. Android còn cấu hình demo và debug signing,
SDK/lock theo baseline cũ; không tuyên bố sẵn sàng store hoặc clone sạch đã đạt.

## Báo cáo nguyên gốc Prompt 12 — giữ nguyên lịch sử

# MediCare Dental — Frontend Release Baseline (Mock)

## 1. Thời điểm và định nghĩa baseline

Kiểm tra lại ở Prompt 12, chốt snapshot tại **2026-10-21T22:11:13.840005+07:00** (Asia/Ho_Chi_Minh).
Flutter **3.47.2 stable**, Dart **3.13.2**, pubspec version **1.0.0+1**;
Android emulator-5554, sdk gphone16k arm64, Android 17/API 37.

**Sẵn sàng bàn giao source/demo Frontend Mock để Nhi review và chốt commit riêng.**
Không phải release cửa hàng/production hoặc xác nhận backend đã tích hợp.
Không tạo Git commit/tag hay đổi quyền ghi source. Đóng băng ở mức manifest SHA256:
[FRONTEND_BASELINE_MANIFEST.json](FRONTEND_BASELINE_MANIFEST.json), 254 file
runtime/assets/platform/tests/config không bị ignore; aggregate:

`2a8e04a91bbf488b46d45fba44edccdcaf78fcebf95d4873f2c8e3cc81fd58c2`

Manifest không gồm docs/README/log/ảnh QA/build/cache/backend/root config để tránh
hash tự tham chiếu; platform scaffold chưa được kiểm thử không trở thành đã kiểm
thử chỉ vì có hash. Đổi source sau mốc này cần kiểm tra lại và cập nhật baseline.

## 2. Git và phạm vi

Lúc bắt đầu có 326 file thay đổi/untracked, trong đó 320 frontend, 4 backend,
root .gitignore và .vscode/launch.json. Đó là trạng thái trước Prompt 12, không
phải số file do tác vụ này tạo. Không suy đoán tác giả của mọi diff chưa commit.
Đã chạy git status --short, diff --stat, diff --name-only và kiểm kê untracked
đầy đủ; bằng chứng ở qa_artifacts/release_baseline/.

Các file backend đang thay đổi từ trước: backend/lib/services/user_service.dart,
backend/test/http_contract_test.dart, backend/bin/server.dart,
backend/lib/core/api_response.dart. Giữ nguyên cả bốn file, root config và các
thay đổi khác; đối chiếu SHA256 các file ngoài frontend không có khác biệt so
với snapshot đầu tác vụ. Không gọi API hoặc Firebase, không dừng server.
Không git add/commit/stash/reset/clean và không sửa .gitignore.

## 3. Mock Mode và API foundation

- Default DATA_SOURCE=mock được kiểm tra trên Android **không truyền dart-define
  DATA_SOURCE**. Một lượt riêng chạy explicit mock + content scenario.
- Cả hai lượt dùng test-only HttpOverrides chặn HttpClient.openUrl trong app
  isolate: **MOCK_HTTP_ATTEMPTS=0**. Không cần backend khả dụng; không thực sự tắt
  backend đang chạy. Đây không phải kiểm thử API Mode hoặc firewall toàn OS.
- Source: AppConfig chọn Android emulator 10.0.2.2, web/desktop localhost; máy thật
  phải override host được bàn giao. API_BASE_URL ưu tiên API_URL; không chứa secret.
- ApiClient/repository/user service/model và Provider đã được đối chiếu, không
  thay contract. User legacy repository là nơi duy nhất đổi Mock/API; nó không
  phải Auth hoặc dữ liệu bệnh nhân. Không có client/repository nội dung mới.
- Có hai Provider, một BookingController cho draft; không trùng nguồn dữ liệu.
- Package/source không có Firebase SDK/FCM khởi tạo. TreatmentPhotos có nhánh
  Image.network cho HTTPS nếu được cấp đường dẫn, nhưng mock hiện không có ảnh
  mạng. Hai scenario không đại diện mọi payload tương lai.
- Không log token/body request trong ApiClient; debug main chỉ log mode/phạm vi.
  Quét một số pattern secret trên frontend text thay đổi/untracked tại đầu tác
  vụ không thấy match; không phải chứng nhận bảo mật hoặc quét mọi file ignored.

## 4. Các chức năng hoàn thành và mức kiểm chứng

| Nhóm | Kiểm thử trực tiếp trong Prompt 12 | Giới hạn |
|---|---|---|
| Auth Mock | Unit/widget Welcome/Login/Register/Forgot validation/navigation; Android login/logout | Không Auth thật/email/đa tài khoản có quyền |
| MainShell | Unit/widget 4 tab, Back lặp/tab ẩn/logout, giữ draft; Android chuyển các tab | Không chứng nhận mọi chuỗi lifecycle/thiết bị |
| Home | Unit/widget lời chào, catalog→detail, empty/missing, thêm/hủy lịch→Home; Android article và Home | Featured/sort backend chưa có contract |
| Booking | Unit/widget combo/nhiều dịch vụ, bác sĩ/hệ thống, patient/relative, ngày giờ, missing/past, submit/dispose; Android đủ 4 bước có note→success→Records | Slots/voucher/quote/availability/idempotency còn demo |
| Records | Unit/widget list/detail/cancel/history/result/thuốc/hóa đơn/liệu trình/ảnh/tái khám; Android lịch vừa tạo/detail và đổi relative | Android scenario chọn Giữ lịch trong dialog; cancel thật kiểm tra bằng widget/provider |
| Tôi | Unit/widget profile/family/filter/settings/FAQ/saved/logout; Android thêm/sửa người thân, Saved/Settings/logout | Quyền OS/biometric/password chỉ demo |
| Articles | Unit/widget list/detail/Back, long body, content/summary fallback, ảnh lỗi, 360/390/430; Android bookmark/Saved/bỏ lưu hai chiều | Mock chỉ có summary; chưa URL ảnh/HTML/API |
| Notifications | Unit/widget filters/read/unread/empty/title-message trắng/orphan; Android filters/read/link→Records | In-app mock, không push/FCM |
| UI/UX | Unit/widget chữ lớn 150%, 360/390/430, viewport thấp, keyboard, cuộn dài, global no-stretch; Android full-flow forms/keyboard/NavigationBar | Không pixel/golden certification, chưa vật lý/iOS/TalkBack |

35 điểm overscroll của lần trước là **bằng chứng lịch sử** tại
qa_artifacts/overscroll/, không cộng thành 35 kiểm tra Android mới ở Prompt 12.
Không đổi UI; ảnh Prompt 11 trong qa_artifacts/handover/screenshots/ vẫn đại diện
bố cục hiện tại. Driver baseline nhận capture từ scenario nhưng không lưu PNG trùng.

## 5. Kết quả analyzer/tests vừa chạy lại

| Kiểm tra | Kết quả mới |
|---|---|
| Dart format lib/test/integration_test/test_driver | Không còn file cần định dạng |
| flutter analyze | **No issues found** |
| flutter test | **97 test đạt**, không bỏ/thay test cũ để đạt |
| Android default Mock | **1 scenario demo đạt**, HTTP attempts=0 |
| Android explicit Mock/content | **1 scenario nội dung đạt**, HTTP attempts=0 |
| Tổng Android | **2 scenario ứng dụng đạt** |
| Build/chạy main.dart thường | Mock, không cần backend; log android_run.log |
| git diff --check | Không lỗi whitespace |

Runner Android có setUpAll/tearDownAll (in +3), không cộng chúng thành scenario
nghiệp vụ. Lượt demo khoảng 31 giây, content khoảng 20 giây, không gồm build/cài.
Không cần pub get thủ công vì dependency đã resolve và không đổi pubspec/lock;
không nâng cấp package. Kiểm thử trực tiếp chỉ trên SDK/emulator ghi ở mục 1.

Log mới: [analyze](../../qa_artifacts/release_baseline/analyze.log),
[Flutter tests](../../qa_artifacts/release_baseline/test.log),
[Android default Mock](../../qa_artifacts/release_baseline/android_default_mock.log),
[Android content](../../qa_artifacts/release_baseline/android_content_mock.log),
[build/run](../../qa_artifacts/release_baseline/android_run.log).
Cách tái hiện: [DEMO_RUN_GUIDE.md](DEMO_RUN_GUIDE.md).

## 6. Lỗi phát hiện và thay đổi Prompt 12

Không tái hiện lỗi frontend nghiêm trọng hoặc lỗi runtime mới trong phạm vi các
kiểm tra đã chạy; không sửa mã lib, Provider, model, mock, theme hoặc UI.

Phát hiện lỗi tài liệu: README cũ nói chỉ có source Dart, yêu cầu flutter create
và bắt buộc khởi động backend. Điều này không còn đúng với source/nền tảng đã có
và Mock mặc định. Đã sửa README để chạy đúng entrypoint, Mock độc lập và trỏ tới
handover; không chạy flutter create hoặc ghi đè platform.

Sửa các file tồn tại:

- frontend/README.md: sửa hướng dẫn cũ như trên.
- frontend/docs/handover/FRONTEND_OVERVIEW.md: liên kết baseline/commit plan/next steps.
- frontend/docs/handover/DEMO_RUN_GUIDE.md: SDK và lệnh baseline Mock/no-network.

Tạo mới:

- frontend/integration_test/release_baseline_test.dart: wrapper test-only chặn HTTP,
  tái sử dụng hai scenario hiện có và xác minh default/explicit Mock.
- frontend/test_driver/release_baseline_driver.dart: driver không lưu lại PNG.
- frontend/docs/handover/NHI_NEXT_STEPS.md
- frontend/docs/handover/FRONTEND_COMMIT_PLAN.md
- frontend/docs/handover/FRONTEND_COMMIT_FILES.txt (danh sách từng path đề nghị review)
- frontend/docs/handover/FRONTEND_BASELINE_MANIFEST.json
- frontend/docs/handover/FRONTEND_RELEASE_BASELINE.md (tài liệu này)
- frontend/qa_artifacts/release_baseline/: snapshot Git, inventory/hash, scan và log.

Tất cả thay đổi lib/UI từ các Prompt trước được giữ nguyên, không quy cho Prompt
12. Không sửa các tài liệu lịch sử để biến kết quả cũ thành test vừa chạy.

## 7. Chức năng đang chờ API, rủi ro còn lại

- Auth/account/family/services/doctors/bookmark: Bình; booking/availability/voucher/
  cancel: Phương; records/medical/invoice/treatment/followup: Ngân; article/Home
  composition/in-app notifications: Nhi. Contracts chưa được nhóm bàn giao.
- Nhi cần article body/images/featured/paging và notifications list/filter/read;
  giữ sync bookmark với Bình và link lịch với Phương/Ngân. Xem
  [NHI_NEXT_STEPS.md](NHI_NEXT_STEPS.md) cho câu hỏi cụ thể và thứ tự tích hợp.
- State trong RAM, mất sau restart; demo một tài khoản không có phân quyền thật.
  Không API auth/push/thanh toán/email/sinh trắc học thật. Ngày mock cố định sẽ
  thành quá khứ; không sửa mock để che vấn đề thời gian. Home minh họa giờ kết thúc
  +30 phút, cần chốt slot/duration/timezone với Phương trước khi nối lịch thật.
- Android applicationId/namespace hiện com.example.frontend, label mẫu, release
  còn dùng debug signing theo source. Chưa build ký release/store. INTERNET hiện
  từ debug/profile manifests; cần review manifest production trước khi API release.
- Đã kiểm kê platform scaffold iOS/web/desktop, chưa chạy build/test
  các nền tảng này. SDK constraint không bảo đảm mọi Flutter cũ chạy API widget mới.
- Chưa kiểm tra clone sạch sau commit, keystore release, store, hiệu năng production,
  accessibility toàn diện hoặc bảo mật. Chưa xác minh API Mode trong Prompt 12.
- Bốn file backend pending và root config còn phải nhóm review; frontend không
  tự rollback/stage chúng. Không đủ Git history để xác định tác giả mọi hunk.

## 8. Checklist bàn giao và quyết định chốt

- [x] Giữ nguyên Mock default, API contract/Provider/UI/dữ liệu demo.
- [x] Tự chạy analyzer + 97 tests + 2 Android scenario có guard HTTP=0.
- [x] Đọc toàn bộ handover hiện có; đối chiếu source/models/providers/owner và
  endpoint lịch sử/chưa contract; sửa README/hướng dẫn cần thiết.
- [x] Lập danh sách commit frontend và phân loại QA/cache/backend/root.
- [x] Ghi manifest source, thời điểm/SDK/giới hạn và công việc của Nhi.
- [ ] Nhi/nhóm review từng file, đặc biệt untracked platform/legacy/API và secrets.
- [ ] Chọn có giữ scaffold ngoài Android và gói artifact/tài liệu lịch sử riêng.
- [ ] Nhi tự xác nhận stage/commit frontend; backend/root để nhóm xem xét.
- [ ] Sau commit, nhóm kiểm tra clone sạch bằng cùng SDK.

Xem [FRONTEND_COMMIT_PLAN.md](FRONTEND_COMMIT_PLAN.md). Chưa thực hiện các bước
chờ xác nhận; agent dừng sau khi báo cáo. Baseline Mock sẵn sàng bàn giao để review,
không phải xác nhận production readiness hoặc tự nhận công việc backend.
