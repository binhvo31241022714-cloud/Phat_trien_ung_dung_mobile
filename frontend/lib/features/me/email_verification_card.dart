import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'me_widgets.dart';

/// Thẻ nhắc "Email chưa được xác minh" ở tab "Tôi". Không chặn dùng app.
class EmailVerificationCard extends StatefulWidget {
  const EmailVerificationCard({super.key});
  @override
  State<EmailVerificationCard> createState() => _EmailVerificationCardState();
}

class _EmailVerificationCardState extends State<EmailVerificationCard> {
  Timer? _ticker;
  bool _busy = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Vẽ lại mỗi giây trong lúc đếm ngược, hết giờ thì dừng.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (context.read<UserProvider>().verificationCooldownSeconds == 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    final error = await context.read<UserProvider>().resendVerificationEmail();
    if (!mounted) return;
    setState(() => _busy = false);
    meMessage(context, error ?? 'Đã gửi lại thư xác minh.');
    if (error == null) _startTicker();
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    final users = context.read<UserProvider>();
    final error = await users.refreshEmailVerified();
    if (!mounted) return;
    setState(() => _busy = false);
    meMessage(
        context,
        error ??
            (users.emailVerified == true
                ? 'Đã xác minh email.'
                : 'Email vẫn chưa được xác minh. Hãy bấm vào liên kết trong thư rồi thử lại.'));
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>();
    final wait = users.verificationCooldownSeconds;
    // Vừa đăng ký xong (thư đã gửi) thì bắt đầu đếm ngược ngay.
    if (wait > 0 && (_ticker == null || !_ticker!.isActive)) _startTicker();
    return MeCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.mark_email_unread_outlined, color: Color(0xFFE65100)),
        SizedBox(width: 10),
        Expanded(
            child: Text('Email chưa được xác minh',
                style: TextStyle(fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 6),
      Text(
          'Chúng tôi đã gửi thư xác minh tới ${users.account.email}. Hãy mở thư và bấm vào liên kết (kiểm tra cả hộp thư Spam).',
          style: const TextStyle(color: Color(0xFF666666))),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        OutlinedButton(
            onPressed: _busy || wait > 0 ? null : _resend,
            child: Text(wait > 0 ? 'Gửi lại sau $wait giây' : 'Gửi lại thư')),
        FilledButton(
            onPressed: _busy ? null : _check,
            child: const Text('Tôi đã xác minh')),
      ]),
    ]));
  }
}
