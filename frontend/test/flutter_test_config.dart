import 'dart:async';

import 'support/mock_data_source.dart';

/// flutter test tự chạy hàm này trước mọi file trong test/.
/// Mặc định test dùng dữ liệu giả, không gọi backend. Muốn chạy nhánh API
/// (vẫn dùng MockClient, không gọi mạng thật) thì truyền rõ
/// --dart-define=DATA_SOURCE=api.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (!const bool.hasEnvironment('DATA_SOURCE')) useMockDataSource();
  await testMain();
}
