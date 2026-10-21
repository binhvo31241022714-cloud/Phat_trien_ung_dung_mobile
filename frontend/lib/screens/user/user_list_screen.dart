import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/loading_view.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<UserProvider>().fetchUsers(),
    );
  }

  Future<void> _confirmDelete(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá người dùng'),
        content: Text('Xoá "${user.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final error = await context.read<UserProvider>().deleteUser(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Đã xoá')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Người dùng')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.userForm),
        child: const Icon(Icons.add),
      ),
      body: Builder(builder: (_) {
        if (provider.isLoading) return const LoadingView();
        if (provider.error != null) {
          return AppErrorView(message: provider.error!, onRetry: provider.fetchUsers);
        }
        if (provider.users.isEmpty) {
          return const Center(child: Text('Chưa có người dùng nào'));
        }
        return RefreshIndicator(
          onRefresh: provider.fetchUsers,
          child: ListView.separated(
            itemCount: provider.users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final user = provider.users[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(user.name),
                subtitle: Text(user.email),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.userForm,
                  arguments: user,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(user),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
