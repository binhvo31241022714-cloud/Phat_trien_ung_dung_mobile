# Kế hoạch staging hiện tại — Android-only, Prompt 12.7

Trạng thái: **PRE-COMMIT**. Phạm vi được Nhi duyệt: Flutter source/config/
dependencies/tests + Android scaffold + tài liệu frontend. Không commit/push.

## Danh sách hiện tại

[FRONTEND_COMMIT_FILES.txt](FRONTEND_COMMIT_FILES.txt) hiện liệt kê **154 đường dẫn
root-relative chính xác**: 149 file từ năm batch Prompt 12.6, bốn tài liệu được
phép đồng bộ và một manifest Android-only mới. Không dùng danh sách 264 file cũ
để stage; danh sách cũ đã được lưu lại trong annotation của manifest lịch sử.

| Nhóm hiện tại | Số file |
|---|---:|
| Flutter config/dependencies/assets | 11 |
| Flutter source | 92 |
| Unit/widget/integration tests và drivers | 19 |
| Android scaffold | 19 |
| Handover docs, danh sách và manifests | 13 |
| Tổng | 154 |

AppConfig/ApiClient/repository/UserService/UserModel, hai Provider, routes và
màn hình user legacy đều được giữ vì thuộc source/dependency hiện tại. Sáu widget/
export dự phòng có vai trò rõ ràng cũng được giữ; tám scaffold chỉ có comment
không stage, không sửa và không xóa.

Không stage backend, root config, iOS/web/macOS/Linux/Windows, artifact QA, log,
screenshot, build/cache, file local hoặc secrets. Platform ghi trong .metadata
hoặc đường dẫn trong tài liệu lịch sử không có nghĩa stage code platform đó.

## Hash và bằng chứng kiểm thử

[FRONTEND_BASELINE_MANIFEST.json](FRONTEND_BASELINE_MANIFEST.json) giữ nguyên các
trường, 254 path/hash và aggregate SHA256 của Prompt 12. Đó là snapshot lịch sử,
không phải phạm vi commit Android-only và không thể dùng để yêu cầu clone Android
có đủ mọi platform cũ. Annotation mới chỉ giải thích phạm vi và giữ danh sách
264 candidate trước khi đồng bộ; không đổi hash lịch sử.

[FRONTEND_ANDROID_PRECOMMIT_MANIFEST.json](FRONTEND_ANDROID_PRECOMMIT_MANIFEST.json)
là snapshot **PRE-COMMIT** hiện tại. Nó liệt kê đủ 154 path, ghi SHA256 của 153
file còn lại, không tự hash chính nó để tránh vòng tham chiếu. Hash mới lấy từ
byte working tree sau đồng bộ docs, không phải hash đã được chạy lại 97 tests.
Khi stage, đối chiếu từng hash với Git index blob và so sánh danh sách chính xác;
kiểm tra riêng file manifest mới bằng byte/hash working tree so với index.

97 Flutter tests, analyzer không lỗi, hai Android scenario và HTTP attempts=0
là kiểm chứng **lịch sử Prompt 12**. Prompt 12.7 không chạy lại tests/build/API.
Không sửa UI, Provider, mock hoặc Android applicationId/signing.

## Staging có kiểm soát

Chỉ stage đường dẫn cụ thể trong danh sách hiện tại khi branch main, index trống,
149 file khớp review và không có vấn đề bảo mật/dependency. Năm batch gốc được
stage trước, sau đó bốn docs đã đồng bộ và manifest mới. Không wildcard, force-add,
stage toàn thư mục, reset, unstage hàng loạt, commit hoặc push.

Sau staging kiểm tra name-status, cached --check, stat, staged diff và đối chiếu
manifest. Nếu sai lệch, dừng và báo Nhi; không tự commit hay gỡ file của nhóm.

## Bàn giao và giới hạn

Ảnh/log QA được bàn giao riêng theo cấu trúc qa_artifacts/ và qa_screenshots/;
không nằm trong danh sách 154. QA_RESULTS.md và báo cáo baseline lịch sử có các
liên kết artifact local, nên clone source đơn thuần không có các minh chứng đó.

Android vẫn dùng com.example.frontend, label mẫu và debug signing; đây là bản
bàn giao source/demo Mock, chưa phát hành store. Gradle wrapper đang bị ignore;
Flutter SDK baseline có cơ chế tự bổ sung wrapper thiếu khi build. Chưa chạy
clone sạch. Dùng Flutter 3.47.2 / Dart 3.13.2 như baseline; lock cần Dart >=3.11.0-0,
không suy ra mọi SDK đáp ứng constraint ^3.5.0 của pubspec đều chạy được.

## Phụ lục — kế hoạch Prompt 12 được giữ để đối chiếu lịch sử

Các số 264 candidate, 326 file lúc bắt đầu và các câu mô tả chưa staging dưới đây
chỉ phản ánh **Prompt 12**, không phải trạng thái sau staging Prompt 12.7.

> # Kế hoạch commit Frontend riêng — chờ Nhi duyệt
>
> Không có lệnh git add/commit/stash/reset/clean nào được thực hiện. Không sửa
> .gitignore, root config hoặc backend. Danh sách sau là đề nghị review, không phải
> xác nhận tác giả của mọi thay đổi chưa commit hoặc bảo đảm không có secret.
>
> ## Kiểm kê thực tế lúc bắt đầu Prompt 12
>
> `git status --short`, `git diff --stat`, `git diff --name-only` và status với
> untracked đầy đủ đã được lưu trong `qa_artifacts/release_baseline/`.
> Lúc chụp có 326 file thay đổi/untracked (320 frontend, 4 backend, 2 file root).
> Đây không phải 326 thay đổi do Prompt 12 và không gồm các file ignored.
>
> | Phân loại | Phạm vi | Xử lý |
> |---|---|---|
> | Frontend có từ trước | lib, tests, nền tảng, assets, pubspec/config, API foundation, handover Prompt 11, log/ảnh QA | Giữ nguyên; review diff/file untracked rồi chọn theo danh sách |
> | Frontend Prompt 12 | README, tài liệu baseline/kế hoạch/next steps, hai file test harness và artifact mới | Chi tiết danh sách ở FRONTEND_RELEASE_BASELINE.md; không đổi mã runtime/UI |
> | Backend có từ trước | backend/lib/services/user_service.dart; backend/test/http_contract_test.dart; backend/bin/server.dart; backend/lib/core/api_response.dart | Không đưa vào commit Frontend, không sửa/hoàn tác |
> | Root cần nhóm xem xét | .gitignore, .vscode/launch.json | Ngoài phạm vi frontend; lịch sử hội thoại có liên quan nhưng Git không đủ thông tin quy kết mọi tác giả/hunk |
>
> Backend user_service/http_contract_test từ Prompt 10 cũ đã ghi trong
> PENDING_BACKEND_REVIEW.md. Hai file server/api_response đã có diff trước Prompt 10.
> Không lấy diff so với HEAD làm danh sách riêng của Prompt 12.
>
> ## Danh sách đề nghị đưa vào commit
>
> [FRONTEND_COMMIT_FILES.txt](FRONTEND_COMMIT_FILES.txt) liệt kê **264 đường dẫn cụ thể**
> root-relative của file frontend thay đổi/untracked dự kiến, gồm chính tài liệu
> baseline. Không tự stage toàn bộ thư mục frontend hoặc toàn repository vì có
> artifact QA và scaffold cần review.
>
> | Nhóm | Đề nghị | Review trước khi Nhi quyết định |
> |---|---|---|
> | frontend/lib/** | Giữ trọn các file source phụ thuộc lẫn nhau | Provider/mock/API legacy, routes, scaffold comment; không bỏ file làm hỏng import |
> | frontend/test/**, integration_test/**, test_driver/** | Giữ tests và driver có thể tái hiện | api_foundation integration cũ cần backend thật và không thuộc lệnh baseline Mock; fixture/token test chỉ là test |
> | pubspec.yaml, pubspec.lock, analysis_options.yaml | Giữ để khóa dependency/app checks | Không nâng phiên bản khi stage; pubspec.lock đang untracked, nên đưa vào commit ứng dụng |
> | frontend/.gitignore, .metadata | Giữ cấu hình Flutter/template | .metadata được Flutter quản lý; kiểm tra diff, không sửa tay để che phiên bản SDK |
> | frontend/android/** không ignored | Cần cho bản Android đang được kiểm tra | namespace/applicationId hiện com.example.frontend, nhãn mẫu, release ký debug; chưa đủ phát hành store |
> | frontend/ios, macos, linux, windows, web | Có trong source và danh sách đề nghị; nhóm quyết định giữ scaffold | Chưa build/test release các nền tảng này; review config/bundle IDs, generated template code, không quảng bá đã hỗ trợ production |
> | frontend/assets/** | Giữ tệp source/placeholder README hiện có | Kiểm tra quyền sử dụng ảnh thật nếu thêm sau; không có ảnh y khoa riêng trong gói mock hiện tại |
> | frontend/README.md, docs/handover/** | Giữ tài liệu bàn giao/baseline | Đường dẫn API chưa có contract chỉ là nhu cầu; manifest ghi hash, không phải tag/commit đã tạo |
>
> Tệp generated source của template (ví dụ registrant/CMake plugin files được Git
> liệt kê) phải được review theo quy ước nền tảng. Không stage cache/ephemeral chỉ
> vì chúng được sinh ra khi build. Danh sách không chứa file ignored.
>
> ## Artifact và tài liệu lịch sử — review riêng, không stage mặc định
>
> - `frontend/qa_artifacts/**`: log, JSON kiểm kê/probe, ảnh và snapshot Git;
>   `frontend/qa_screenshots/**`: ảnh QA cũ. Chỉ chọn minh chứng cần thiết sau review.
> - `frontend/{FINAL_QA_REPORT,ME_IMPLEMENTATION,RECORDS_IMPLEMENTATION}.md`: báo cáo
>   lịch sử, không thay thế release baseline mới. Có thể giữ trong commit tài liệu
>   riêng sau khi kiểm tra đường dẫn và trạng thái kết quả lịch sử.
> - Log *.log hiện đã bị frontend/.gitignore bỏ qua. Ảnh/JSON/MD QA vẫn có thể là
>   untracked. Nếu nhóm muốn loại cả artifact, cân nhắc qa_artifacts/qa_screenshots/
>   trong .gitignore sau; Prompt 12 **không sửa ignore** và không xóa artifact.
> - Docs baseline/Prompt 11 liên kết artifact local. Nếu không commit artifact,
>   bàn giao chúng thành gói QA riêng có cùng cấu trúc thư mục hoặc ghi vị trí
>   tải cho nhóm; clone source đơn thuần sẽ không mở được các liên kết artifact.
>   Không dùng git add -f để đưa mọi log bị ignore vào Git.
>
> ## Không đưa vào commit Frontend
>
> Bốn file backend nêu trên; root .gitignore và .vscode/launch.json; build/,
> .dart_tool/, coverage/, caches, android/.gradle, android/local.properties,
> Generated.xcconfig/flutter_export_environment.sh/ephemeral, signing secrets,
> keystore/key.properties, service-account JSON, .env chứa secrets, token thực.
> Các mẫu ignore nền tảng đã xử lý nhiều loại này; không dùng force-add để vượt qua.
>
> ## Kiểm tra thông tin nhạy cảm
>
> Quét các file text frontend thay đổi/untracked tại đầu tác vụ bằng một số pattern
> private key/API key/token có độ tin cậy cao: không phát hiện match. Kết quả chỉ
> ghi path/line/type, không in giá trị; xem sensitive_scan.json trong artifact.
> Đây không phải chứng nhận bảo mật hoặc quét lịch sử Git/file ignored.
>
> Nhi vẫn cần xem kỹ ApiClient/AppConfig (không secret trong source/dart-define),
> Android/iOS signing/config, mock names/phones, ảnh chụp, log VM service/đường dẫn
> máy cá nhân, test fixtures và nội dung docs. Tên/số điện thoại demo không được
> nhầm thành dữ liệu bệnh nhân thật. Khi thêm ảnh hoặc payload API thật, ẩn dữ liệu
> nhạy cảm trước khi bàn giao. Không chép credentials vào báo cáo.
>
> ## Trước khi Nhi tự xác nhận commit
>
> 1. Xem từng file trong danh sách, kể cả untracked và các scaffold ngoài Android.
> 2. Đối chiếu manifest/source hash với baseline; không chỉnh UI hoặc dependency
>    trong cùng bước stage mà không chạy lại kiểm thử tương ứng.
> 3. Chọn phạm vi frontend đã review, quyết định tài liệu lịch sử/artifact/nền tảng.
> 4. Tự stage các đường dẫn được duyệt; xem lại staged diff để bảo đảm không có
>    backend/root/secrets/cache. Không stage toàn repository bằng một lệnh rộng.
> 5. Nhi quyết định commit; agent không thực hiện. Sau commit, nhóm nên kiểm tra
>    clone sạch với cùng SDK, flutter pub get và chạy Mock. Clone sạch và store
>    release signing chưa được kiểm thử trong Prompt 12.
