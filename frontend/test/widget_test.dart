import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('trang chủ hiển thị nút quản lý người dùng', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(create: (_) => UserProvider(), child: const App()),
    );

    expect(find.text('KTHP PTUD'), findsOneWidget);
    expect(find.text('Quản lý người dùng'), findsOneWidget);
  });
}
