# Demo readiness checklist — MediCare Dental

Ngày 01/11/2026. Kết luận: **có thể chuẩn bị demo các phần riêng lẻ; chưa xác nhận sẵn sàng demo toàn bộ clinical E2E trên Firebase.** Audit này không mở app trên thiết bị, không gọi API/Firebase thật, không tạo hay sửa dữ liệu demo thật.

## Có thể trình diễn từ bằng chứng hiện tại

| Chức năng | Điều kiện | Mức tin cậy |
|---|---|---|
| Home, carousel, card/detail, articles, loading/empty/error | Mock fixtures; nếu api thì cần backend + published content | Source/mock tests xác minh nhiều ca, chưa rehearsal thiết bị |
| Booking services/doctor/date/slot/quote/voucher | Catalog và schedules hợp lệ; mock tests có fake API | Fake/mock pass nhiều flow; dữ liệu thực chưa kiểm |
| Appointment list/detail/cancel, owner scope | API + authenticated account có lịch phù hợp, hủy cách giờ khám ≥2h | Code/fake có; không hủy lịch thật trong audit |
| Profile/family/favorites | Firebase Auth và backend khi chạy app thật; test có fake | Mock/source có; camera/gallery chưa kiểm OS |
| Read/unread/read-all và bell | Notifications đã tồn tại của đúng account | Fake/mock xác minh; chỉ in-app REST |
| Records đọc dữ liệu đã có | Visit/invoice/rx/treatment/follow-up cùng patient, đầy đủ liên kết | API readers/mock có; writer clinical còn lỗi |
| Follow-up → booking | Follow-up open, có serviceId active, đúng patient/account | Normal fake/mock pass; source validation/backlink còn lỗi |

Không gọi các hàng này là Firebase PASS hoặc “demo ngay chắc chắn thành công”. Chúng là phần có cơ sở để rehearsal sau khi nhóm kiểm tra môi trường.

## Mock và backend/Firebase

- Production entrypoint main() luôn initialize Firebase và dùng FirebaseAuthService. **DATA_SOURCE=mock không biến đăng nhập thành fake/offline**. Mock mode đổi nguồn dữ liệu patient/content; profile/catalog của app vẫn có những service backend. Muốn demo hoàn toàn fake cần harness có fake auth/services đã được nhóm chuẩn bị, không tự đổi main trong audit.
- Các chức năng “chỉ hoạt động với mock” ở nghĩa chứng cứ: đơn thuốc/biên lai sau completion hiện được thể hiện qua fixtures hoặc dữ liệu tồn tại sẵn, chưa có completion writer đầy đủ. Fake có thể mô tả tương lai mà backend chưa thực hiện.
- API mode cần backend cổng3000, Firebase Auth đang đăng nhập, user profile sync, catalog service price/duration hợp lệ, doctor serviceIds, doctor_schedules theo ngày, voucher còn hiệu lực khi dùng.
- Android Emulator dùng http://10.0.2.2:3000 mặc định. Máy thật cần API_BASE_URL trỏ IP/host truy cập được; localhost trên thiết bị là thiết bị. Chưa kiểm firewall/cleartext/TLS trong rehearsal thực.
- Staff API cần custom claims từ identity đáng tin cậy. Audit không tạo staff, không cấp role, không cung cấp credential hay token.

## Không nên hứa trong demo hiện tại

AUD-07: **DEFERRED (out of demo scope)** — nhắc tái khám tự động chưa triển khai, được Nhi/Phương/Ngân thống nhất hoãn. Test acceptance vẫn chạy callback/assertions dưới TODO; không tính TODO là PASS. Giữ reminder lịch hẹn confirmed 24 giờ và scheduler 10 phút, không bổ sung mốc nhắc khác.

JSON request body toàn API giữ **1 MiB (1.048.576 bytes)** theo phương án B được Bình/Phương/Ngân xác nhận. Ảnh sau giải mã tối đa **716.800 bytes**. Transport vượt giới hạn trả 413 trước route; field sai vẫn có thể trả 400 dù JSON dưới/trong giới hạn.

- Staff complete tự tạo đủ đơn thuốc + hóa đơn: AUD-01, không có writer hiện tại.
- Luồng lịch sử người thân sau archive: AUD-06.
- Reminder 2h riêng hoặc tái khám trước3 ngày/08:00 VN: AUD-07.
- Push/banner khi app đóng qua FCM: NOT IMPLEMENTED.
- Notification luôn tự cập nhật realtime: đang dựa REST reload/lifecycle, không realtime push.
- Mọi ảnh/avatar đã qua backend regression: media suite đang crash harness, AUD-13.
- App hoàn toàn offline chỉ nhờ --dart-define=DATA_SOURCE=mock.

## Nguy cơ làm demo thất bại

1. Complete trả thành công nhưng không có hóa đơn/thuốc; visit tồn tại bị overwrite.
2. Dữ liệu service/doctor/schedule lệch ID, inactive, combo duration không bằng tổng; server chủ động trả lỗi thay vì dùng mock.
3. Slot/voucher vừa được dùng, slot quá khứ hoặc ngoài30 ngày; hủy trong2 giờ bị chặn đúng nghiệp vụ.
4. Follow-up thiếu service, sai patient, đã booked, stale appointment backlink hoặc ngày parse mơ hồ.
5. Record detail mất hoặc invoice link sai làm toàn loadRecords báo lỗi; archived không chọn được.
6. API host sai trên máy thật; Firebase identity/profile sync chưa sẵn sàng; claim staff khác policy endpoint.
7. Job không chạy khi Express tắt; phải chờ tối đa khoảng10 phút sau lần quét; notification đã gửi không biến thành OS push.
8. Ba test UI width đang dừng ở nhãn avatar cũ nên chưa chứng minh hết destination; quyền camera/gallery phụ thuộc OS.

## Kịch bản demo an toàn đề xuất

Kịch bản này **chưa được chạy**. Dùng account và dữ liệu tổng hợp do nhóm chuẩn bị sẵn trong môi trường demo được duyệt; không dùng hồ sơ người bệnh thật.

1. Người phụ trách xác nhận data source, API host, backend/Firebase, profile và danh mục trước buổi demo. Không đọc/in credential lên màn hình.
2. Đăng nhập bằng tài khoản demo do nhóm quản lý; giới thiệu Home/articles/catalog và navigation/back.
3. Xem profile/family/favorites. Không archive người thân nếu đang cần trình diễn lịch sử của họ.
4. Chọn dịch vụ/bác sĩ/slot tương lai được nhóm cho phép; xem quote/voucher. Chỉ xác nhận booking khi hoạt động ghi dữ liệu demo đã được nhóm cho phép.
5. Xem lịch vừa tạo, chỉ dùng staff confirmation đã được phân quyền hợp lệ. Nếu chưa sửa clinical writer thì dừng trước lời hứa complete sinh đầy đủ chứng từ.
6. Trình diễn Records bằng bộ chứng từ có sẵn được kiểm tra nhất quán; nói rõ dữ liệu đã chuẩn bị, không nói vừa được completion tự tạo.
7. Xem notification in-app, unread/read-all; nói rõ reminder hiện là một cửa sổ24h chạy10 phút và chưa có FCM.
8. Rebooking từ follow-up hợp lệ có serviceId, nếu đã kiểm lại backlink. Không che lỗi bằng chuyển qua mock mà không thông báo.
9. Logout/login account khác và kiểm không thấy dữ liệu private trước. Không in ID token hoặc log nhạy cảm khi trình bày.

## Checklist trước demo

- [ ] Nhóm xác nhận môi trường/dataset/demo writes được phép và tài khoản không chứa dữ liệu thật.
- [ ] Chọn rõ mock harness hay API runtime; thử đăng nhập thực trên đúng thiết bị, không mặc định mock = offline auth.
- [ ] API URL Android Emulator/máy thật đúng; backend chạy; profile sync và các GET cần thiết hoạt động.
- [ ] Catalog, doctor mappings, ca làm việc, voucher và slot còn hợp lệ tại giờ demo; tránh dữ liệu hardcode ngày cũ.
- [ ] Review/sửa sáu P1 hoặc ghi rõ scope không trình diễn các flow đó.
- [ ] Ngân xác nhận completion writer, chứng từ và source links; Phương xác nhận slot/idempotency/cancel/rebooking.
- [ ] Bình xác nhận user/family ownership và staff claim matrix; không thử tự gán role trong buổi demo.
- [ ] Nhi chạy lại suites sau các bản sửa; không bỏ qua ba test label/media harness chỉ để nói xanh.
- [ ] Thử back stack, refresh, errors, small screen/text scale và quyền camera/gallery trên thiết bị.
- [ ] Phân biệt event, in-app scheduled reminder, OS push trên slide/lời nói.
- [ ] Không trình diễn archived-history hay FCM như chức năng hoàn chỉnh khi chưa triển khai/xác minh.
- [ ] Có rehearsal và phương án dừng minh bạch nếu API lỗi; không seed/cleanup tự động giữa demo.

Kết quả audit nền: backend120 pass/35 fail; Flutter default308 pass/3 fail/132 skip; API mock426 pass/3 fail/14 skip; analyze PASS. Xem [full audit](FULL_APPLICATION_AUDIT.md) cho phạm vi và [issue register](AUDIT_ISSUE_REGISTER.md) cho chủ sở hữu/hướng sửa.
