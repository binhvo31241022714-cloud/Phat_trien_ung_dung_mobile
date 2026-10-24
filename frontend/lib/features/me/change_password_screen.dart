import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../providers/user_provider.dart';
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
  bool _saving = false;
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

  /// Xác thực lại bằng mật khẩu hiện tại rồi đổi mật khẩu trên Firebase.
  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await context
        .read<UserProvider>()
        .changePassword(_current.text, _password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      meMessage(context, error);
      return;
    }
    meMessage(context, 'Đã đổi mật khẩu');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) =>
      MePage(title: 'Đổi mật khẩu', children: [
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
                            enabled: !_saving,
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
                              if (i == 1 && value == _current.text) {
                                return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                              }
                              if (i == 2 && value != _password.text) {
                                return 'Mật khẩu xác nhận không khớp';
                              }
                              return null;
                            })),
                  PrimaryButton(
                      label: 'Đổi mật khẩu',
                      onPressed: _submit,
                      isLoading: _saving),
                ]))),
      ]);
}
