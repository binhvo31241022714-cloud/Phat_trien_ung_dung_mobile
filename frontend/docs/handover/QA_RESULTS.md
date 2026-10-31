> Cập nhật tích hợp 31/10/2026: backend hiện tại là Node.js/Express + Firebase Admin; `DATA_SOURCE` mặc định là `api`. Phần baseline/mock/backend Dart bên dưới là lịch sử, không phải bằng chứng nghiệm thu hiện tại. Xem [báo cáo và runbook hiện hành](INTEGRATION_AUDIT_962a981.md).

# Prompt 11 — Kết quả bàn giao frontend

## Phạm vi và thay đổi

Chỉ sửa frontend. Không sửa/hoàn tác backend, Firebase/Firestore, endpoint hoặc
thay đổi DATA_SOURCE mặc định. Không tích hợp auth/booking/records/content API
thật. Không tạo commit. Các thay đổi chưa commit có sẵn được giữ nguyên.

Hai thiếu sót frontend được xử lý:

1. Article chỉ có summary, chưa có nơi chứa body đầy đủ. Thêm content nullable
   và getter body; chi tiết ưu tiên content, fallback summary, hoặc thông báo
   thiếu nội dung. Mock summary cũ hiển thị như trước; không sáng tác nội dung y khoa.
2. Notification title/message rỗng hiển thị khoảng trống. Thêm text fallback;
   không đổi filter/read/link, layout, màu hoặc card. Model vẫn typed non-null cho
   hai trường này; chưa có JSON adapter và không tuyên bố đã xử lý contract API thiếu/null.

## Danh sách file thuộc Prompt 11

Sửa:

- lib/data/models/article.dart
- lib/features/articles/article_detail_screen.dart
- lib/features/me/notifications_screen.dart

Tạo mới:

- test/content_handover_test.dart (8 test)
- integration_test/content_handover_test.dart
- test_driver/handover_driver.dart
- Sáu tài liệu bên dưới và QA_RESULTS.md này.
- Log và ảnh trong qa_artifacts/handover/.

Không đổi PatientDataProvider, UserProvider, mock data, Home layout, AppConfig,
ApiClient, repository legacy hoặc ScrollBehavior đã được xác minh trước đó.

## Tình trạng module và đồng bộ

| Module | Kết quả / giới hạn |
|---|---|
| Bài viết | List/detail/Back, body dài cuộn, summary trống, ảnh asset lỗi fallback; 360/390/430px. Mock vẫn chỉ có summary, chưa có image URL/HTML/featured flag |
| Home | Giữ lời chào/lịch gần nhất/dịch vụ nổi bật/bác sĩ/bài viết và đích detail. Test mới thêm/hủy lịch cập nhật ngay Home; điều hướng danh sách/chi tiết có test cũ và Android |
| Thông báo | Bốn filter, không mất list, read status trong Provider, linked appointment mở Records, orphan/empty có fallback và nhãn demo. Chưa push/FCM; offer/system không có link chỉ đánh dấu đọc |
| Bookmark | Set ID dùng chung, Home/detail/Saved đồng bộ hai chiều, không có bản ghi ID trùng; chỉ trong RAM, chưa sync server |
| Người thân/tài khoản | Test cũ vẫn giữ: thêm/sửa giữ ID, selector cập nhật, chọn người khám không đổi account; không chuyển nghiệp vụ sang API |
| Scroll/UI | Dùng AppScrollBehavior đã có, không stretch; giữ bốn tab/Bottom Navigation/card và các đường Back. Không đổi thiết kế |

## Tài liệu bàn giao

- [FRONTEND_OVERVIEW.md](FRONTEND_OVERVIEW.md): kiến trúc, screens/routes, Provider,
  models/mock, API foundation và điểm vào ứng dụng.
- [API_INTEGRATION_MAP.md](API_INTEGRATION_MAP.md): map module/screen/Provider/model/
  mock/nhu cầu API theo từng người; phân biệt endpoint đã xác minh lịch sử và
  chức năng chưa có contract. Không đặt URL endpoint dự kiến.
- [TEAM_HANDOVER.md](TEAM_HANDOVER.md): file, model, integration points và checklist
  cho Bình, Phương, Ngân, Nhi; lưu ý quy tắc thời lượng Home còn chờ chốt.
- [CONTENT_MODULE_HANDOVER.md](CONTENT_MODULE_HANDOVER.md): source Home thực tế và
  scaffolds, article/notification fields mong đợi, flow và các bước nhận contract.
- [DEMO_RUN_GUIDE.md](DEMO_RUN_GUIDE.md): dependencies/emulator, Mock/API giới hạn,
  test, luồng demo và hạn chế.
- [PENDING_BACKEND_REVIEW.md](PENDING_BACKEND_REVIEW.md): ghi đúng hai file từ
  Prompt 10 cũ để người phụ trách review, không sửa/hoàn tác.

## Kiểm thử mới trong lần bàn giao

- Flutter analyze: **No issues found**.
- Flutter test: **97 test đạt = 89 test cũ + 8 test mới**, không bỏ/giảm test cũ.
- Format toàn bộ lib/test/integration_test/test_driver: không còn tệp cần format.
- git diff --check: không lỗi whitespace.
- Tám test mới: body fallback; ba kích thước màn hình với body dài/cuộn/bookmark;
  Home thêm/hủy lịch; ảnh asset lỗi/mô tả trống; article list rỗng; notification
  text trống và chuyển filter lặp giữ nguyên list.
- Các test sẵn có tiếp tục kiểm tra article → detail → Saved → bỏ lưu, filter/
  read/link/orphan, các tab, forms, người thân và đăng nhập/logout demo.

Log: [analyze.log](../../qa_artifacts/handover/analyze.log),
[test.log](../../qa_artifacts/handover/test.log).

Android emulator-5554, Android 17/API 37, DATA_SOURCE=mock: **2 scenario đạt**:

1. Nội dung: login → Home article/detail → bookmark → Saved/detail/bỏ lưu →
   Home → chuông → bốn filters → read status → linked appointment trong Records →
   Booking/Tôi → logout; tài khoản giữ nguyên và không có stretch/exception.
2. Luồng demo đầy đủ: login/Home/article/bookmark → booking bốn bước có ghi chú →
   Records/chi tiết → thêm/sửa người thân → Saved/Settings → logout.

Mỗi runner báo +2 gồm một scenario ứng dụng và tearDownAll; không cộng teardown
thành test nghiệp vụ. Scenario nội dung chạy 20 giây, luồng demo 30 giây (không
tính build/cài). Đây là test tự động trên emulator, chưa kiểm tra điện thoại vật
lý/iOS/TalkBack. Không xác minh backend/Firebase/push thật trong lần này.

Log: [android_content.log](../../qa_artifacts/handover/android_content.log),
[android_flow.log](../../qa_artifacts/handover/android_flow.log).
Có 14 ảnh trong [screenshots](../../qa_artifacts/handover/screenshots/); đã xem ảnh
thông báo thực tế. Build/chạy lại main.dart Mock sau test có log android_run.log.
Không tuyên bố pixel-perfect hoặc mọi thiết bị từ các kiểm tra này.

## API đang chờ và phân công tiếp theo

- **Nhi:** chốt contract list/detail/sort/featured/body/image bài viết, list/filter/
  paging/mark-read notifications; nhận nội dung được biên tập/duyệt; adapter/
  repository frontend chỉ khi có contract và phạm vi được giao; giữ checklist UI.
- **Bình:** Auth/profile/family, catalog services/doctors và bookmark theo tài khoản;
  phối hợp bookmark article. Xem riêng route user legacy và hai file backend pending.
- **Phương:** availability, giá/voucher, submit/cancel idempotency, trạng thái và
  timezone/slot/duration; phối hợp cập nhật Home/notification theo lịch thật.
- **Ngân:** records/visit/result/prescription/receipt/treatment/photos/followup theo
  bệnh nhân có phân quyền; không biến dữ liệu thiếu thành bệnh án giả.

Các endpoint content/patient chưa có contract được bàn giao trong Prompt 11.
Thông tin health/user API trong tài liệu là kiểm chứng lịch sử Prompt 10, không
phải kiểm tra API mới. Không tạo DTO/interface hoặc endpoint nội dung giả để báo
sẵn sàng tích hợp. Firebase/auth thật/push/persistence vẫn chưa triển khai.
