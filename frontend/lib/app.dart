import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'routes/app_routes.dart';

class App extends StatelessWidget {
  /// true khi Firebase còn nhớ phiên đăng nhập, mở thẳng trang chính.
  final bool signedIn;

  const App({super.key, this.signedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediCare Dental',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
      initialRoute: signedIn ? AppRoutes.main : AppRoutes.welcome,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
