import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../providers/user_provider.dart';
import 'health_info_section.dart';
import 'me_widgets.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final data = profile.profile;
    if (data == null) {
      return MePage(title: 'Thông tin cá nhân', children: [
        if (profile.profileError != null && !profile.profileLoading)
          ErrorState(
              message: profile.profileError!, onRetry: profile.loadProfile)
        else
          const Padding(
              padding: EdgeInsets.only(top: 80), child: LoadingView()),
      ]);
    }
    return _ProfileForm(
        key: ValueKey('${profile.sessionGeneration}:${data.id}'),
        profile: data);
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.profile, super.key});
  final UserProfile profile;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone, _email;
  DateTime? _birthday;
  late final HealthFormController _health;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.fullName);
    _phone = TextEditingController(text: p.phone);
    _email = TextEditingController(
        text: p.email.isNotEmpty
            ? p.email
            : context.read<UserProvider>().account.email);
    _birthday = p.birthday;
    _health = HealthFormController(initial: p.health, gender: p.gender);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _health.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ProfileProvider>();
    final session = provider.sessionGeneration;
    final error = await provider.saveProfile(
        fullName: _name.text,
        phone: _phone.text,
        birthday: _birthday,
        gender: _health.gender,
        health: _health.build());
    if (!mounted || !provider.isSessionCurrent(session)) return;
    if (error != null) {
      setState(() => _saving = false);
      meMessage(context, 'Chưa lưu được: $error');
      return;
    }
    meMessage(context, 'Đã lưu thông tin cá nhân.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) =>
      MePage(title: 'Thông tin cá nhân', children: [
        MeCard(
            child: Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: MeAvatar()),
                      Center(
                          child: TextButton(
                              onPressed: () => meMessage(context,
                                  'Thay ảnh chỉ là chức năng demo; chưa hỗ trợ chọn hoặc tải ảnh lên.'),
                              child: const Text('Thay ảnh (demo)'))),
                      const SizedBox(height: 8),
                      AppTextField(
                          label: 'Họ và tên',
                          controller: _name,
                          validator: (v) =>
                              Validators.required(v, field: 'Họ và tên')),
                      const SizedBox(height: 16),
                      BirthdayField(
                          value: _birthday,
                          onChanged: (date) =>
                              setState(() => _birthday = date)),
                      const SizedBox(height: 16),
                      GenderField(
                          value: _health.gender,
                          onChanged: (v) => setState(() => _health.gender = v)),
                      const SizedBox(height: 16),
                      AppTextField(
                          label: 'Số điện thoại',
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          validator: Validators.vietnamesePhone),
                      const SizedBox(height: 16),
                      // Email là email đăng nhập Firebase, backend không cho
                      // đổi qua API nên chỉ hiển thị.
                      AppTextField(
                          label: 'Email',
                          controller: _email,
                          enabled: false,
                          keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 24),
                      HealthInfoSection(
                          controller: _health,
                          onChanged: () => setState(() {})),
                      const SizedBox(height: 16),
                      PrimaryButton(
                          label: 'Lưu thay đổi',
                          onPressed: _save,
                          isLoading: _saving),
                    ]))),
      ]);
}
