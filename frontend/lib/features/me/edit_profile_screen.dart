import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/patient.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/user_provider.dart';
import 'me_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone, _email;
  DateTime? _birthday;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().account;
    _name = TextEditingController(text: user.name);
    _phone = TextEditingController(text: user.phone);
    _email = TextEditingController(text: user.email);
    _birthday = user.dateOfBirth;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final users = context.read<UserProvider>();
    final data = context.read<PatientDataProvider>();
    final p = data.primaryPatient;
    data.updatePatient(Patient(
        id: p.id,
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        dateOfBirth: _birthday!,
        relationship: p.relationship,
        isPrimary: p.isPrimary,
        avatarAsset: p.avatarAsset));
    users.updateDemoAccount(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        dateOfBirth: _birthday!);
    meMessage(context, 'Đã lưu thông tin trong phiên demo.');
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
                      AppTextField(
                          label: 'Số điện thoại',
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          validator: Validators.vietnamesePhone),
                      const SizedBox(height: 16),
                      AppTextField(
                          label: 'Email',
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.optionalEmail),
                      const SizedBox(height: 16),
                      PrimaryButton(
                          label: 'Lưu thay đổi',
                          onPressed: _save,
                          isLoading: _saving),
                    ]))),
        const Text(demoSessionNotice,
            style: TextStyle(color: Color(0xFF666666), fontSize: 12))
      ]);
}
