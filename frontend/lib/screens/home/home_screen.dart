import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flutter_dash, size: 96),
            const SizedBox(height: 16),
            Text('KTHP PTUD', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.users),
              icon: const Icon(Icons.people),
              label: const Text('Quản lý người dùng'),
            ),
          ],
        ),
      ),
    );
  }
}
