# Bằng chứng QA

- `source_audit.json`: thống kê import graph từ main.dart, các tệp không nằm trong graph,
  scaffold chỉ có comment, Provider và phép tính tương phản chữ phụ.
- `flutter_test.log`: lần chạy cuối toàn bộ 68 test unit/widget.
- `flutter_analyze.log`, `dart_format.log`: kiểm tra static và định dạng cuối.
- `android_integration.log`: build và chạy kịch bản tích hợp trên emulator; một kịch bản
  ứng dụng cộng bước tearDownAll của framework. Ảnh ở `../qa_screenshots/`.
- `android_run.log`: cài/chạy lại entrypoint lib/main.dart thông thường sau integration test.
- `before_catalog_test.log`, `before_auth_test.log`: log trung gian trước khi hoàn tất QA.
  Log catalog tái hiện lỗi pop navigator của tab ẩn; log auth có locator test ban đầu
  trùng tiêu đề/nút. Chúng không phải kết quả kiểm thử cuối.
