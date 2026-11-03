# Đợt 2 — Home, Articles, Notifications & Bottom Navigation

## 1. Phạm vi đã thực hiện

Chỉ presentation của Home, Articles, Notifications và bottom navigation.
Branding YourSmile Dental được giữ nguyên. Không đổi navigation, dữ liệu, auth,
API contract, notification type/payload, predicate lọc hoặc điều kiện nghiệp vụ.
Không chạy Git, đọc credentials/token, khởi động server hoặc kết nối Firebase thật.

## 2. File đã thay đổi

| File | Thay đổi |
|---|---|
| `frontend/lib/app/main_shell.dart` | Chỉ đổi surface, border/shadow, màu icon active/inactive và nhãn bottom bar; giữ nguyên 4 tab, callback, key và back. |
| `frontend/lib/features/articles/article_list_screen.dart` | Spacing theo token, empty state rõ; giữ load/retry/save/navigation. |
| `frontend/lib/features/articles/article_detail_screen.dart` | Giới hạn chiều rộng đọc 720, title 22, body 15 với line height 1.65, ảnh bo góc 16:9; không blur. |
| `frontend/lib/features/shared/article_card.dart` | Thumbnail 16:9, radius theo card token, title/summary phân cấp; giữ public API và callback. |
| `frontend/lib/features/me/api_notifications_view.dart` | Card/filter dùng UI chung, caption giải thích tái khám trong nhóm Lịch hẹn; không đổi predicate, type, refId hay các thao tác đọc/mở. |
| `frontend/lib/features/me/notifications_screen.dart` | Style tương ứng cho chế độ mock, giữ categories và callback. |
| `frontend/lib/screens/home/home_screen.dart` | Nền solid; header tối thiểu 48; hero gradient có scrim bảo đảm contrast; service/doctor/article dùng AppCard trắng, giữ callback và chiều cao theo nội dung. |
| `frontend/lib/features/me/notification_widgets.dart` | NotificationCard và NotificationFilterChip thuần presentation; border unread nhẹ, card trắng, selected chip pastel có checkmark. |
| `frontend/test/blue_batch2_ui_test.dart` | 22 test offline: 9 cấu hình list/detail/save và notification actions; hero/nav/link, loading/error/retry/empty và CTA Home. |

## 3. Các quyết định UI

- Hero dùng AppGradients.hero với scrim navy 68% và các surface trắng bán trong suốt
  sẵn có (calendar/badge); không thêm blur. Test contrast chữ trắng trên từng điểm
  màu của gradient sau scrim >= 4.5:1.
- Carousel vẫn giữ chiều rộng item 176/120/180 và ảnh hiện có; các card trong từng
  nhóm tự giãn theo nội dung, tên bác sĩ/specialty và article title giữ ellipsis.
- Bottom navigation: active Sky Blue, inactive Slate Gray, pill Ice Blue; nhãn active
  navy để dễ đọc. Surface trắng và shadow nhẹ, không đổi route/key/callback.
- Bài viết dùng ảnh rõ, title 18 ở list, summary 14 và metadata 12. Detail giữ toàn
  bộ body, cho phép cuộn tới nút lưu, không blur văn bản.
- Notification filter vẫn giữ nhóm hiện hành. Ở API, nhóm Lịch hẹn đã bao gồm
  appointment_*, follow_up/follow_up_reminder và visit_result. Chỉ thêm chú thích
  giúp chọn nhóm; không tách thêm tab làm thay đổi logic lọc.
- Unread dùng border xanh nhạt và chấm xanh; trạng thái read/unread vẫn lấy từ
  dữ liệu provider, không có nguồn state mới.
- Kiểm tra caller xác nhận ArticleCard hiện dùng ở ArticleList; SavedItems dùng
  tile riêng. ArticleDetail được dùng lại khi mở bài viết đã lưu; ma trận UI kiểm tra
  các trang Saved/Me để phát hiện tác động của component/theme.

## 4. Kết quả kiểm tra

| Kiểm tra | Kết quả |
|---|---|
| flutter analyze --no-pub | PASS — không có lỗi/warning |
| Nhóm UI/foundation/header chính | PASS — 118 test |
| Liên kết thông báo–tái khám và cài đặt bằng API giả | PASS — 9 test |
| Notifications retry/read-all và refresh unread khi unmount | PASS — 2 test |
| Width 320/360/411; text scale 1.0/1.3/1.5 | PASS trong widget tests |
| CTA navy/text, chữ trắng trên hero scrim | PASS theo contrast assertions |
| Article footer không bị bottom navigation che ở 320/1.5 | PASS |
| Android Emulator/device/live Firebase E2E | SKIP — chưa chạy, không tuyên bố nghiệm thu hình ảnh thực tế |

Tổng 129 test trong các nhóm xác minh nêu trên đạt. Đây không phải kết luận toàn
bộ test của repository đều đạt. Không sửa bất kỳ test hiện có nào trong Đợt 2.

Lệnh nhóm chính:

```sh
flutter analyze --no-pub
flutter test --no-pub test/blue_batch2_ui_test.dart test/ui_responsive_test.dart test/ui_components_test.dart test/home_card_layout_test.dart test/content_handover_test.dart test/records_patient_header_test.dart test/design_foundation_test.dart
flutter test --no-pub --dart-define=DATA_SOURCE=api test/phase3_notifications_followup_api_test.dart
flutter test --no-pub --dart-define=DATA_SOURCE=api test/module4_test.dart --name 'notifications Retry then read-all UI|leaving notifications refreshes unread after unmount'
```

Các API test dùng MockClient/fake service; production không bị chuyển sang mock.
Đối chiếu SHA-256 với đầu Đợt 2: chỉ 7 file source hiện có trong bảng trên thay đổi;
142 file source khác giữ nguyên, bao gồm provider/controller/service/model.

## 5. FAIL còn tồn tại, được báo riêng

### Ba test nhãn trạng thái đã biết

Chạy lại:

```sh
flutter test --no-pub test/records_test.dart --plain-name 'visit, prescription, receipt, treatment photos and back fit'
```

FAIL cả 3 trường hợp width 360/390/430 vì test chờ `Đã hoàn tất`, còn mapping hiện
có dùng `Đã hoàn thành`. Không sửa file status, nghiệp vụ hoặc assertion để tạo PASS.

### Bộ test cũ mở rộng

Lượt API-mode mở rộng với module4_test, phase3_notifications_followup_api_test và
home_article_image_test: 28 PASS / 10 FAIL. Các lỗi bên dưới chưa được xử lý trong
phạm vi UI. Có test provider gọi loadArticles mà chưa setAccount, fixture không
khởi tạo session đầy đủ, kỳ vọng parsing ngày và geometry cũ. Cần rà soát riêng;
không coi toàn bộ đây là regression UI và không khẳng định toàn suite đạt.

- `module4_test.dart: Timestamp JSON, ISO, missing and malformed dates are safe`
- `module4_test.dart: articles error has no mock fallback and supports retry`
- `module4_test.dart: empty articles remain empty`
- `module4_test.dart: in-flight article requests are deduplicated`
- `module4_test.dart: late unread response cannot undo a successful PATCH`
- `module4_test.dart: user lifecycle clears favorites and private content`
- `home_article_image_test.dart: API Home article image uses API URL with original image bounds and rounded corners`
- `module4_test.dart: API mode widgets article list error Retry and empty API states`
- `module4_test.dart: API mode widgets network article image failure uses placeholder`
- `module4_test.dart: API mode widgets detail 404 shows Retry without fallback`

Cụ thể, home_article_image_test chờ height 96 trong khi thumbnail Home đang giữ
height 62 hiện có; chưa thay assertion hoặc ép ảnh theo test đó.

Lượt chạy mở rộng ban đầu ở cấu hình mặc định: 72 PASS / 12 FAIL / 12 SKIP.
Danh sách lỗi được ghi lại để không bỏ qua kết quả không đạt (một số case trùng
với lượt API trên):

- `module4_test.dart: Timestamp JSON, ISO, missing and malformed dates are safe`
- `module4_test.dart: articles error has no mock fallback and supports retry`
- `module4_test.dart: empty articles remain empty`
- `module4_test.dart: home has no mock appointment or catalog fallback`
- `module4_test.dart: in-flight article requests are deduplicated`
- `module4_test.dart: late unread response cannot undo a successful PATCH`
- `module4_test.dart: user lifecycle clears favorites and private content`
- `module4_test.dart: home refreshes after appointments change`
- `home_appointment_test.dart: Home endTime is preferred over duration`
- `home_appointment_test.dart: Home endAt Timestamp takes precedence over endTime and duration`
- `home_appointment_test.dart: Home uses valid explicit duration when end is missing`
- `home_appointment_test.dart: invalid end times do not normalize into invented dates`

Các sai lệch giờ/Timestamp nằm ở model/helper ngày hiện có; source đó không thay
đổi trong Đợt 2. Không sửa model hoặc nghiệp vụ để làm test UI đạt.

## 6. Cần nghiệm thu và bước tiếp theo

- Chỉ nghiệm thu source/analyze/widget test offline ở đợt này.
- Cần kiểm tra trực tiếp Home với ảnh thật, hero hai trạng thái, carousel và CTA;
  article list/detail/save; notification filters/read/read-all/deep link; 4 tab và Back.
- Xác nhận cách trình bày nhóm Lịch hẹn bao gồm tái khám, cùng style active navigation.
- Chờ duyệt Đợt 2 trước khi bắt đầu Đợt 3 (Auth/Profile/Family/Catalog).
- Không thay branding hoặc UI các module khác trong Đợt 2.
