import 'package:flutter/material.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import 'me_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  final _hidden = [true, true, true];
  @override
  void dispose() {
    _current.clear();
    _password.clear();
    _confirm.clear();
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MePage(title: 'Đổi mật khẩu', children: [
        const Text(
            'Đổi mật khẩu chưa khả dụng trong chế độ demo. Biểu mẫu chỉ kiểm tra dữ liệu; không kiểm tra mật khẩu hiện tại và không lưu mật khẩu.',
            style: TextStyle(color: Color(0xFF666666))),
        const SizedBox(height: 12),
        MeCard(
            child: Form(
                key: _form,
                child: Column(children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AppTextField(
                            label: [
                              'Mật khẩu hiện tại',
                              'Mật khẩu mới',
                              'Xác nhận mật khẩu mới'
                            ][i],
                            controller: [_current, _password, _confirm][i],
                            obscureText: _hidden[i],
                            suffixIcon: IconButton(
                                tooltip: _hidden[i]
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () =>
                                    setState(() => _hidden[i] = !_hidden[i]),
                                icon: Icon(_hidden[i]
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined)),
                            validator: (value) {
                              final required =
                                  Validators.required(value, field: 'Mật khẩu');
                              if (required != null) return required;
                              if (value!.length < 6) {
                                return 'Mật khẩu phải có ít nhất 6 ký tự';
                              }
                              if (i == 2 && value != _password.text) {
                                return 'Mật khẩu xác nhận không khớp';
                              }
                              return null;
                            })),
                  PrimaryButton(
                      label: 'Kiểm tra biểu mẫu (demo)',
                      onPressed: () {
                        if (_form.currentState!.validate()) {
                          meMessage(context,
                              'Đổi mật khẩu chưa khả dụng trong chế độ demo. Không có mật khẩu nào được thay đổi.');
                        }
                      }),
                ]))),
      ]);
}
