# Backend pending review — không thuộc triển khai frontend Prompt 11

Hai file đã được agent sửa/tạo trong Prompt 10 cũ trước khi Nhi thu hẹp phạm vi.
Prompt 11 không sửa, chạy lại backend, xóa hoặc hoàn tác chúng.

| File | Nguồn thay đổi Prompt 10 | Việc cần người phụ trách backend quyết định |
|---|---|---|
| backend/lib/services/user_service.dart | Thêm helper _string kiểm tra name/email; create/update dùng helper để input sai kiểu trả AppException 400 thay vì lỗi cast 500 | Review quy tắc null/type/validation và quyết định giữ hoặc hoàn tác đúng hunk |
| backend/test/http_contract_test.dart | File mới: hai test HTTP chạy Shelf server loopback cổng tạm, kiểm tra health/CRUD trong RAM riêng và JSON/validation/404 | Review coverage, quy ước test và quyết định tiếp nhận |

Backend `bin/server.dart` và `lib/core/api_response.dart` đã có diff trước Prompt 10;
không quy chúng cho thay đổi Prompt 10 hoặc tự revert. Cả frontend và backend có
nhiều thay đổi chưa commit; Git không xác định tác giả của mọi thay đổi đó.

Backend user legacy chưa phải auth/profile bệnh nhân. Phân công đã nhận: Bình
Auth/account/family/catalog/bookmark; Phương booking/availability/voucher/cancel;
Ngân records/medical/invoice/treatment/followup. Nhi chỉ bàn giao frontend và module
nội dung; người phụ trách backend phối hợp review, không tự nhận toàn bộ API.

Kết quả test backend ở qa_artifacts/prompt10 là lịch sử Prompt 10, không phải kết
quả chạy trong Prompt 11. Không có thay đổi Firebase, collection, credential hoặc
endpoint mới trong Prompt 11. Chỉ hoàn tác sau khi người phụ trách xác nhận phạm
vi; không reset/clean/revert hàng loạt.
