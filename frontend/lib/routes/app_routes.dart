import 'package:flutter/material.dart';

import '../data/models/user_model.dart';
import '../screens/home/home_screen.dart';
import '../screens/user/user_form_screen.dart';
import '../screens/user/user_list_screen.dart';

class AppRoutes {
  static const home = '/';
  static const users = '/users';
  static const userForm = '/users/form';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case users:
        return MaterialPageRoute(builder: (_) => const UserListScreen());
      case userForm:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(builder: (_) => UserFormScreen(user: user));
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Không tìm thấy trang')),
          ),
        );
    }
  }
}
