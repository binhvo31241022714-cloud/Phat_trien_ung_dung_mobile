import '../../core/widgets/page_background.dart';
import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../core/constants/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageBackground(
          child: SafeArea(
        child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                        child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Spacer(),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Icons.medical_services_rounded,
                              size: 65,
                              color: AppColors.sky,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'YourSmile Dental',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Chăm sóc nụ cười của bạn',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Đặt lịch khám dễ dàng, theo dõi hồ sơ '
                            'nha khoa và quản lý sức khỏe răng miệng '
                            'cho cả gia đình.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.login,
                                );
                              },
                              child: const Text('Đăng nhập'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.register,
                                );
                              },
                              child: const Text('Tạo tài khoản'),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ))))),
      )),
    );
  }
}
