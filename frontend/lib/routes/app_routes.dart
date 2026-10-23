import 'package:flutter/material.dart';

import '../data/models/user_model.dart';
import '../screens/user/user_form_screen.dart';
import '../screens/user/user_list_screen.dart';

import '../app/main_shell.dart';
import '../features/auth/welcome_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/shared/patient_detail_screen.dart';

class AppRoutes {
  // MediCare Dental
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const main = '/main';
  static const detail = '/patient/detail';

  // Route cũ của project
  static const home = '/';
  static const users = '/users';
  static const userForm = '/users/form';

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      // ===== MEDICARE DENTAL =====

      case welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        );

      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
        );

      case forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
        );

      case main:
        return MaterialPageRoute(
          builder: (_) => const MainShell(),
        );

      case detail:
        final arguments = settings.arguments;
        if (arguments is! PatientDetailArguments) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidRouteArgumentsScreen(),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PatientDetailScreen(details: arguments),
        );

      // ===== ROUTE CŨ =====

      case home:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        );

      case users:
        return MaterialPageRoute(
          builder: (_) => const UserListScreen(),
        );

      case userForm:
        final user = settings.arguments as UserModel?;

        return MaterialPageRoute(
          builder: (_) => UserFormScreen(user: user),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Không tìm thấy trang'),
            ),
          ),
        );
    }
  }
}

class _InvalidRouteArgumentsScreen extends StatelessWidget {
  const _InvalidRouteArgumentsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Không thể mở nội dung')),
      body: const Center(
        child: Text('Thông tin trang chi tiết không hợp lệ.'),
      ),
    );
  }
}
