# Phần việc tiếp theo của Nhi — chỉ khi có API được bàn giao

Đây là kế hoạch frontend, không phải contract hoặc API đã tích hợp. Giữ
DATA_SOURCE=mock mặc định; không tự tạo endpoint/Firebase/FCM/auth thật.

## A. Article API Integration

- Màn hình: `lib/features/articles/article_list_screen.dart`,
  `article_detail_screen.dart`, `lib/features/shared/article_card.dart`,
  `lib/screens/home/home_screen.dart`; phối hợp SavedItemsScreen của Bình.
- Model `lib/data/models/article.dart`: id/title/summary/category String,
  publishedAt DateTime, readingMinutes int, content String? plain text,
  imageAsset String? local asset. `body` ưu tiên content, summary rồi text thiếu.
  Chưa có imageUrl/featured/rank/pagination/HTML renderer.
- Nguồn hiện tại: PatientDataProvider.articles → MockData.articles. Repository
  đang có chỉ phục vụ user legacy, không phải article repository.
- Cần payload list/detail, ID ổn định, phân loại, body và format, ngày/offset,
  ảnh URL hợp lệ, thứ tự/featured và phân trang. Không tự gán URL vào imageAsset.
- Khi có contract: thêm DTO/repository thật nếu cần, dùng ApiClient đang có;
  inject vào Provider hiện tại, giữ API UI; không tạo Provider trùng và không
  thay mock data để khớp schema chưa chốt.
- Bookmark dùng savedArticleIds/savedArticles chung với Saved. Phối hợp Bình
  cho add/remove theo user; toggle RAM hiện tại không idempotent khi retry HTTP.
- API state cần bổ sung theo nguồn: loading lần đầu, lỗi + retry, empty sau
  thành công, trạng thái tải trang tiếp. Hiện mock không có lifecycle API này.
  Không nuốt lỗi API rồi trả mock hoặc báo lưu thành công khi server chưa xác nhận.
- Nghiệm thu: list → đúng ID detail → Back giữ scroll; body dài và thiếu field;
  ảnh lỗi fallback; 360/390/430 và chữ lớn; Home/Saved đồng bộ hai chiều, không
  trùng ID; lỗi/timeout/offline/401/404/500 rõ ràng; không stretch; Mock vẫn chạy
  khi backend không khả dụng và không sinh request ngoài ý muốn.

## B. Home Content API Integration

| Section hiện có | Dependency/owner | Việc frontend của Nhi |
|---|---|---|
| Lời chào | primaryPatient/profile và account: Bình | Ghép đúng tên; đổi người khám không đổi tài khoản |
| Lịch sắp tới | appointments/availability/cancel: Phương | Hiển thị đúng bệnh nhân, trạng thái, thời gian; refresh theo nguồn chung |
| Dịch vụ nổi bật | services/isPopular/price/duration: Bình | Giữ card và list ngang; không tự đổi giá/đơn vị |
| Đội ngũ bác sĩ | doctors/specialty/avatar: Bình | Map nguồn chung; empty/error/ảnh fallback |
| Bài viết nha khoa | content article: Nhi | List/detail/order/featured theo contract đã nhận |
| Chuông thông báo | notifications: Nhi; link lịch Phương; auth Bình | Mở màn hình sẵn có, không thiết kế đích điều hướng mới |

Không mặc định backend có endpoint Home aggregate; trước tiên compose các nguồn
được bàn giao. Chốt refresh/cache và khi login/logout/chọn bệnh nhân. Không gọi
nhiều repository riêng cho cùng tập lịch/bệnh nhân. Home hiện minh họa kết thúc
lịch bằng +30 phút; chốt duration/slot/timezone với Phương trước khi hiển thị thật.

Nghiệm thu: giữ nguyên sections/card/màu/spacing; các list ngang vẫn cuộn; lịch
mới xuất hiện và lịch hủy bị loại; account/relative không lẫn; dữ liệu thiếu có
state đúng, không gán sang bản ghi đầu tiên; không mở detail bằng ID khác.

## C. Notification API Integration

- File: `features/me/notifications_screen.dart`, chuông trong Home, MeRoutes;
  PatientDataProvider.notifications/markNotificationRead/requestNotifications.
- Model PatientNotification: id, title, message, createdAt, isRead,
  category appointment/offer/system và appointmentId tùy chọn.
- List/filter: hiện lọc local, không xóa list khi đổi bộ lọc. Khi backend paging,
  chốt filter ở client/server, thứ tự, cursor, dedup và state riêng từng bộ lọc.
- Read status: theo user, idempotent mark-read; quyết định optimistic + rollback
  hoặc đợi server; không đánh dấu thành công sau lỗi. Giữ trạng thái khi Back/filter.
- Điều hướng hiện có: nếu appointment liên kết có thật trong Provider thì mở
  chi tiết ở Hồ sơ; không có thì báo liên kết thiếu. System/offer không có đích
  chỉ đánh dấu đọc. Backend phải bảo đảm quyền đọc lịch, không tin ID từ payload.
- Đây là màn hình in-app. Push cần hệ thống delivery/token/quyền OS/vòng đời riêng;
  không mặc định có FCM. Settings.receiveNotifications hiện chỉ là RAM demo.
- Nghiệm thu: tất cả bốn filter; empty; title/message trắng; orphan link;
  unknown category theo quy tắc đã chốt; read/unread qua tab; retry/offline;
  user A không thấy dữ liệu B; logout không giữ cache tài khoản khác; Mock không
  có network; không hiển thị thông báo mẫu như push thật.

## D. API Contract Questions — cần backend trả lời

1. Endpoint chính thức cho article list/detail/featured, notifications list và
   mark-read là gì? Method tương ứng, API version và môi trường staging nào?
2. Endpoint nào public, endpoint nào cần auth? Cơ chế token/refresh/expiration,
   scopes và quyền theo user/patient là gì? Bình bàn giao client/session lúc nào?
3. Query/path/body parameters nào required/optional? Search/category/featured/
   filter/read-status và page size có giới hạn gì? Không tự chọn tên trường.
4. Response có envelope nào? List/detail cùng schema hay khác? Field null/missing,
   kiểu ID, content format, enum, default và trường bắt buộc được quy định ra sao?
5. Pagination dùng cursor hay offset? Sort ổn định, next cursor, hasMore và dedup
   theo ID thế nào khi bài viết/thông báo được cập nhật trong lúc tải?
6. Lỗi validation/unauthorized/forbidden/not-found/rate-limit/server trả status và
   schema nào? Retry/idempotency và timeout được khuyến nghị ra sao?
7. Ảnh URL absolute/relative, base host/CDN, HTTPS, thời hạn signed URL, auth header
   và fallback policy thế nào? Không đưa secret vào frontend hoặc dart-define.
8. Mark-read là một hay nhiều ID, toàn bộ hay một item, có idempotent không?
   Response xác nhận read status và đồng bộ giữa thiết bị/các filter thế nào?
9. publishedAt/createdAt/appointment time dùng timezone/offset nào? Giá và duration
   ở Home là VND/phút hay đơn vị khác? Không tự coi local ISO thiếu offset là UTC.
10. Dữ liệu liên kết bị xóa/không có quyền và category chưa biết nên hiển thị gì?
    Featured/order và nội dung y khoa do ai biên tập/duyệt, trạng thái publish ra sao?

Không có câu trả lời mặc định trong tài liệu này; ghi nhận contract được nhóm
xác nhận trước khi code DTO hoặc bật API.

## E. Integration Order

1. Chốt baseline Mock bằng danh sách commit đã review; giữ pubspec.lock, tests và
   manifest. Không đưa backend hoặc secrets vào commit Frontend.
2. Nhận contract + payload đã ẩn thông tin nhạy cảm; phối hợp auth/session Bình.
3. Test mapping và repository article trước; sau đó list/detail, ảnh và featured.
   Chỉ gọi staging khi được giao, không tạo endpoint hoặc triển khai backend.
4. Phối hợp bookmark Bình, kiểm tra add/remove/cache theo tài khoản và retry.
5. Ghép Home từ catalog Bình, lịch Phương và article của Nhi; không nhân đôi state.
6. List/filter notifications → mark-read → link lịch, phối hợp Bình/Phương/Ngân.
7. Chạy regression Mock, các API tests mới, Android/keyboard/Back; giữ lỗi API rõ
   ràng và chế độ demo độc lập. Chỉ đổi cấu hình phát hành khi nhóm xác nhận.

Chưa cần triển khai push/FCM hoặc module ngoài phân công trong thứ tự trên.
