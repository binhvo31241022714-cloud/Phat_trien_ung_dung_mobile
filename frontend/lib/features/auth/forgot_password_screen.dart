import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Demo: giả lập gửi yêu cầu khôi phục mật khẩu.
    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              child: _submitted ? _successView() : _formView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFFE8F3FF),
              child: Icon(
                Icons.lock_reset_rounded,
                size: 45,
                color: Color(0xFF1677DA),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Khôi phục mật khẩu',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nhập email đã đăng ký. Chúng tôi sẽ '
            'hướng dẫn bạn khôi phục mật khẩu.',
            style: TextStyle(
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'example@gmail.com',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return 'Vui lòng nhập email';
              }

              if (!RegExp(
                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
              ).hasMatch(email)) {
                return 'Email không hợp lệ';
              }

              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Tiếp tục',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Quay lại đăng nhập',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successView() {
    return Column(
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 85,
          color: Color(0xFF1677DA),
        ),
        const SizedBox(height: 24),
        const Text(
          'Đã ghi nhận yêu cầu!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Đây là bản demo. Chưa có email thật '
          'được gửi đến ${_emailController.text.trim()}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Về đăng nhập'),
          ),
        ),
      ],
    );
  }
}
// Mục đích: Màn hình bắt đầu quy trình khôi phục mật khẩu.
