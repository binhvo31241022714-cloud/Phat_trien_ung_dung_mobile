> Cập nhật tích hợp 31/10/2026: backend hiện tại là Node.js/Express + Firebase Admin; `DATA_SOURCE` mặc định là `api`. Phần baseline/mock/backend Dart bên dưới là lịch sử, không phải bằng chứng nghiệm thu hiện tại. Xem [báo cáo và runbook hiện hành](INTEGRATION_AUDIT_962a981.md).

# Bàn giao module nội dung — Nhi

## Source đang hoạt động

| Phần | File/nguồn |
|---|---|
| Home | lib/screens/home/home_screen.dart: _HomeOverview, _ServiceTile, _DoctorTile, _ArticleTile và helper card lịch/section |
| Home scaffolds | lib/features/home/widgets/{home_header,upcoming_appointment_card,featured_services,featured_doctors,featured_articles}.dart: chỉ comment, không được Home import |
| Danh sách bài viết | lib/features/articles/article_list_screen.dart |
| Chi tiết bài viết | lib/features/articles/article_detail_screen.dart |
| Card danh sách | lib/features/shared/article_card.dart; imageAsset null hoặc asset lỗi → icon fallback |
| Điều hướng catalog | lib/features/shared/catalog_navigation.dart, Home navigator |
| Thông báo | lib/features/me/notifications_screen.dart, MeRoutes.notifications và chuông Home |
| Bookmark | PatientDataProvider.savedArticleIds/savedArticles/toggleSavedArticle; SavedItemsScreen trong tab Tôi |
| Models | lib/data/models/article.dart; PatientNotification/NotificationCategory trong patient_records.dart |
| Mock | lib/data/mock_data.dart: articles và notifications; không có bài viết/API thứ hai |

## Hiển thị và hành vi

Home đọc primaryPatient cho lời chào; lịch gần nhất của appointmentPatientId,
chỉ pending/confirmed chưa qua giờ, loại completed/cancelled. Dịch vụ chọn
isPopular, tối đa 6; bác sĩ/bài viết dùng thứ tự Provider hiện có, không có cờ
featured article. Không thêm section/banner hoặc endpoint Home tổng hợp.

Home article dùng icon minh họa theo thiết kế, không có vùng ảnh mới. Danh sách
bài viết dùng ảnh asset với fallback. Chi tiết giữ bố cục tiêu đề, category/ngày/
thời gian đọc, nội dung và nút lưu; không tự thêm hero image, tác giả hoặc rich text.

Article.content là trường plain text tùy chọn được thêm trong Prompt 11, không
phải contract backend. Article.body ưu tiên content không trắng, rồi summary,
rồi thông báo thiếu nội dung. Mock hiện vẫn chỉ có summary, chưa có bài viết dài
được biên tập. Không tự sáng tác hướng dẫn điều trị cá nhân. Nội dung dài cuộn được.

Bookmark Set ID chỉ có một bản ghi cho mỗi article; lưu/bỏ lưu là toggle, không
phải thao tác add idempotent để gọi retry từ API. Khi tích hợp phải chốt riêng
add/remove semantics với Bình, tránh retry một toggle làm đảo trạng thái.

Thông báo có filters All/appointment/offer/system, lọc trên list không xóa list.
Read status cập nhật Provider bằng ID; trở lại filter cũ giữ trạng thái. Tiêu đề/
body trống có fallback; liên kết lịch không còn tồn tại nêu rõ thiếu dữ liệu.
Appointment có thật trong Provider → đánh dấu đọc, focusAppointmentsFor, chuyển
Hồ sơ/chi tiết. Offer/system không có link hiện chỉ đánh dấu đọc; không thiết kế
đích mới. Các thông báo đều ghi là mẫu/demo; receiveNotifications là cài đặt RAM,
không phải quyền hệ điều hành hay FCM. Không có unread badge/bộ đếm ở Home cần API mới.

## Fields frontend mong đợi — chưa áp đặt schema

| Dữ liệu | Trường hiện có / kiểu Dart | Hiển thị/mapping cần thống nhất |
|---|---|---|
| Article identity | id: String | ID ổn định cho list/detail/bookmark; không ép từ ID user legacy |
| Tiêu đề | title: String | Chốt required/empty rule, giới hạn nội dung |
| Mô tả | summary: String | Có thể rỗng; list giới hạn hai dòng; không dùng thay body khi API có body |
| Nội dung | content: String? (mới, optional) | Plain text hiện tại; nếu backend rich text/HTML cần thống nhất renderer trước, chưa hỗ trợ HTML |
| Phân loại | category: String | Text; backend enum/tên hiển thị cần mapping nếu khác |
| Ngày đăng | publishedAt: DateTime | Chốt ISO/offset UTC hoặc local; frontend format dd/MM/yyyy |
| Thời gian đọc | readingMinutes: int | Đơn vị phút, validation từ contract; không tự đổi kiểu/đơn vị |
| Ảnh | imageAsset: String? | Local asset hiện có; image URL là nhu cầu tương lai, chưa có field/loader mạng và không gán URL vào imageAsset |
| Nổi bật/thứ tự | Chưa có isFeatured/rank | Home hiện dùng thứ tự list; cần quy tắc sort/featured/paging từ backend |
| Notification identity | id: String | Dùng để mark-read, ID phải duy nhất ổn định |
| Loại | NotificationCategory: appointment/offer/system | Chốt mapping enum/string và unknown category policy trước DTO |
| Tiêu đề/body | title/message: String | Rỗng có fallback; JSON null/missing phải được adapter xử lý theo contract, hiện chưa có adapter |
| Ngày tạo | createdAt: DateTime | Model giữ ngày; UI hiện không render timestamp. Chốt timezone, thứ tự list từ backend |
| Đã đọc | isRead: bool, mặc định false | API mark-read cần idempotent, theo user; UI chỉ lưu RAM |
| Liên kết | appointmentId: String? | Phải kiểm tra quyền sở hữu trước khi trả dữ liệu; route chỉ mở khi có appointment hợp lệ trong Provider |
| Home data | primaryPatient, appointments, services, doctors, articles | Ghép nguồn từ Bình/Phương/Nhi; không giả định endpoint aggregate |

Không thêm DTO/repository nội dung trong Prompt 11 vì chưa có contract; tránh
một interface giả bị hiểu nhầm là đã kết nối backend. Giữ nền tảng ApiClient/
AppConfig/UserReadRepository hiện có, không đổi DATA_SOURCE sang api.

## Những API đang chờ

List/detail/featured/sort/paging bài viết; ảnh URL và loại body; list/filter/paging
thông báo; mark-read và bảo mật user; bookmark bài viết phối hợp Bình. Mọi method/
path/response/envelope cho nhóm này chưa được xác nhận; không có URL dự kiến.

## Khi backend bàn giao

1. Nhận tài liệu và payload đã ẩn thông tin nhạy cảm; xác nhận method/path/status/
   envelope/paging, auth thật, quyền, field null, ID/timezone và enum.
2. Thống nhất tên/kiểu field bằng bảng trên, không đổi schema backend hàng loạt.
3. Với phạm vi được giao, viết adapter/repository frontend dùng ApiClient hiện có;
   inject vào Provider hiện tại, không thay UserProvider/PatientDataProvider.
4. Test mapping + JSON thiếu/sai/empty/400/401/404/500/timeout/offline; API lỗi
   phải hiển thị lỗi, không âm thầm trả dữ liệu mock.
5. Xác minh staging được cấp phép, Android host đúng; bookmark/read-status đồng bộ
   khi đổi màn hình. Không dùng token giả, không tự kết nối Firebase/FCM.
6. Kiểm tra lại thiết kế, keyboard, danh sách ngang, Back, scroll không stretch;
   bổ sung kết quả thật vào QA_RESULTS.md trước khi bật nguồn API.
