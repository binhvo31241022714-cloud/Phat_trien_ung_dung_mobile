import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_client.dart';

export '../core/network/api_client.dart'
    show ApiClient, ApiException, ApiErrorKind;

/// Client gọi backend Node dùng chung cho cả app.
///
/// - Địa chỉ mặc định: http://10.0.2.2:3000 trên máy ảo Android,
///   http://localhost:3000 trên nền tảng khác. Đổi bằng
///   --dart-define=API_BASE_URL=http://<ip-máy-tính>:3000 khi chạy máy thật.
/// - Tự gắn header "Authorization: Bearer <ID token>" của user đang đăng nhập.
/// - Lỗi được ném ra dạng [ApiException], message là tiếng Việt, hiện được
///   thẳng lên UI.
///
/// Ví dụ:
/// ```dart
/// final services = await api.get('/api/services');
/// await api.post('/api/favorites', {'type': 'service', 'itemId': 'svc_01'});
/// ```
final api = ApiClient(
  tokenProvider: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
);
