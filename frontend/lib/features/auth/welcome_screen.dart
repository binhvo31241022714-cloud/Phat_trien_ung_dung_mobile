import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
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
                              color: const Color(0xFFE8F3FF),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Icons.medical_services_rounded,
                              size: 65,
                              color: Color(0xFF1677DA),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'MediCare Dental',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1677DA),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Chăm sóc nụ cười của bạn',
                            style: TextStyle(
                              fontSize: 18,
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
                              color: Color(0xFF666666),
                              height: 1.6,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.login,
                                );
                              },
                              child: const Text(
                                'Đăng nhập',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.register,
                                );
                              },
                              child: const Text(
                                'Tạo tài khoản',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ))))),
      ),
    );
  }
}
