# Demo readiness checklist, MediCare Dental

Cập nhật 02/11/2026 cho buổi demo 03/11/2026, sau giai đoạn 1 và 2 của đợt sửa audit. Bản ngày 01/11/2026 (kết luận "chưa xác nhận sẵn sàng clinical E2E") đã lỗi thời; xem lịch sử git của file này nếu cần.

**Kết luận:** luồng chính đã chạy thật trên API và Firestore `yoursmile-49379` bằng `backend/scripts/e2e-smoke.js` ngày 02/11/2026: **14 PASS, 0 FAIL, 0 BỎ QUA**, dữ liệu thử tự dọn sạch. `preflight-demo.js`: 0 lỗi, 0 cảnh báo. Có thể demo các chức năng ở bảng dưới, với điều kiện làm đủ checklist sáng hôm demo. Chưa diễn tập trên điện thoại thật trong đợt này.

## Bằng chứng

| Kiểm tra | Kết quả 02/11/2026 |
|---|---|
| `npm test` (Node 24, Firestore giả) | 670 đạt, 0 lỗi |
| `flutter analyze` | Không có lỗi |
| `flutter test` (mặc định) | 403 đạt, 0 lỗi, 132 bỏ qua (test riêng chế độ API) |
| `flutter test --dart-define=DATA_SOURCE=api` | 521 đạt, 0 lỗi, 14 bỏ qua (test riêng chế độ mock) |
| `node scripts/preflight-demo.js` | 0 lỗi, 0 cảnh báo; 5 bác sĩ có ca 7 ngày tới; 5 dịch vụ, 5 combo đều có bác sĩ; voucher DENTAL10 dùng được |
| `node scripts/e2e-smoke.js` | 14 PASS: đặt lịch, xác nhận, nhắc lịch, hoàn tất kèm kết quả và 2 thuốc, bệnh nhân đọc visit/đơn thuốc/hóa đơn, liệu trình và buổi 1, đề xuất tái khám, nhắc tái khám, đặt lịch từ tái khám, hủy, tải và xóa ảnh trước sau. Dọn 20 bản ghi, kiểm tra lại 0 bản ghi sót |

## Trình diễn được

| Chức năng | Điều kiện | Mức tin cậy |
|---|---|---|
| Đăng ký, đăng nhập, hồ sơ, người thân, ảnh đại diện | Firebase Auth, backend bật | Test fake; dùng hằng ngày trên máy ảo |
| Trang chủ, danh mục, bài viết, đã lưu | Backend bật, dữ liệu danh mục hợp lệ (preflight OK) | Test fake |
| Đặt lịch, voucher, hủy (cách giờ khám ít nhất 2 giờ) | Có ca làm việc (`seed-schedules --apply`) | Test fake + E2E thật |
| Staff xác nhận, hoàn tất kèm kết quả khám, đơn thuốc, hóa đơn (khối DEMO D1 đến D4) | Đăng nhập staff trong `api-test.http` | Test fake + E2E thật |
| Hồ sơ khám, liệu trình, ảnh trước sau | Như trên | Test fake + E2E thật |
| Đề xuất tái khám, đặt lịch từ đề xuất | Như trên | Test fake + E2E thật |
| Nhắc lịch hẹn (24 giờ), nhắc tái khám (3 ngày) | **Backend đang bật**; bấm D7 để chạy ngay | Test fake + E2E thật |
| Lịch sử người thân đã xóa | Có người thân đã xóa kèm hồ sơ cũ | Test fake, chưa thử trên Firebase |

## Không hứa trong demo

- Thông báo đẩy (FCM) khi app đóng: chưa có, thông báo chỉ hiện trong app.
- Màn hình nhân viên trong app: chưa có, staff dùng `backend/api-test.http`.
- Nhắc lịch mốc 2 giờ trước giờ khám: chưa có.
- Rate limit: chưa có; backend chỉ chạy trong mạng nội bộ (AUD-18).
- Phân trang hồ sơ khám: chưa có (AUD-11).
- Tự làm mới token khi API trả 401: chưa có, app báo phiên hết hạn.
- `DATA_SOURCE=mock` không phải chế độ offline: đăng nhập vẫn dùng Firebase thật.

## Nguy cơ và cách tránh

1. Không có ca làm việc cho ngày demo: chạy `seed-schedules.js --apply` và `preflight-demo.js` sáng hôm demo.
2. Nhắc lịch không xuất hiện: backend chưa bật, hoặc lịch không còn trong 24 giờ tới, hoặc tài khoản tắt "Nhận thông báo". Đặt lịch ngày mai buổi sáng, bấm D7 **trước** D4.
3. D1, D3 lấy nhầm lịch của người khác: kiểm tra `patientName` ở phần tử đầu trước khi bấm D2, D4. D4 không hoàn tác được.
4. Token staff hết hạn (khoảng 1 giờ): bấm lại đăng nhập staff ngay trước demo.
5. Máy thật không gọi được backend: dùng `--dart-define=API_BASE_URL=http://<IP>:3000`, cùng Wi-Fi; ưu tiên máy ảo.
6. Hủy lịch sát giờ (dưới 2 giờ) bị chặn đúng nghiệp vụ, không phải lỗi.

## Checklist sáng hôm demo

- [ ] `cd backend`, `node scripts/seed-schedules.js` rồi `node scripts/seed-schedules.js --apply`.
- [ ] `node scripts/preflight-demo.js`: 0 LỖI.
- [ ] Bật backend (`npm start`) và để chạy suốt buổi.
- [ ] (Nên làm) `node scripts/e2e-smoke.js`: 0 FAIL; chạy xong trước giờ demo, không chạy trong lúc demo.
- [ ] Mở `backend/api-test.http`, đăng nhập staff ngay trước demo.
- [ ] `flutter run` trên máy ảo, đăng nhập thử.
- [ ] Tài khoản demo chỉ chứa dữ liệu giả lập; không trình chiếu mật khẩu, token.
- [ ] Làm theo kịch bản demo ở README gốc mục 4 (D1 đến D8).

Xem thêm: [README gốc](../../../README.md) (cách chạy, kịch bản demo, checklist), [issue register](AUDIT_ISSUE_REGISTER.md) (trạng thái từng mục AUD).
