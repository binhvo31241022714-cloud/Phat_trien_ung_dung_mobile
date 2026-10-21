import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/patient.dart';
import '../../data/providers/patient_data_provider.dart';
import 'me_widgets.dart';

class FamilyFormScreen extends StatefulWidget {
  const FamilyFormScreen({this.patient, super.key});
  final Patient? patient;
  @override
  State<FamilyFormScreen> createState() => _FamilyFormScreenState();
}

class _FamilyFormScreenState extends State<FamilyFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone;
  DateTime? _birthday;
  String _relationship = 'Con';
  bool _saving = false;
  static const relationships = [
    'Con',
    'Bố',
    'Mẹ',
    'Vợ/Chồng',
    'Anh/Chị/Em',
    'Khác'
  ];
  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _name = TextEditingController(text: p?.fullName);
    _phone = TextEditingController(text: p?.phone);
    _birthday = p?.dateOfBirth;
    if (p != null) {
      _relationship =
          relationships.contains(p.relationship) ? p.relationship : 'Khác';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = context.read<PatientDataProvider>();
    final p = widget.patient;
    try {
      if (p == null) {
        data.addRelative(
            name: _name.text,
            relationship: _relationship,
            dateOfBirth: _birthday!,
            phone: _phone.text);
      } else {
        data.updatePatient(Patient(
            id: p.id,
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            dateOfBirth: _birthday!,
            relationship: _relationship,
            isPrimary: false,
            avatarAsset: p.avatarAsset));
      }
      meMessage(
          context,
          p == null
              ? 'Đã thêm người thân trong phiên demo.'
              : 'Đã cập nhật người thân trong phiên demo.');
      Navigator.pop(context);
    } catch (_) {
      setState(() => _saving = false);
      meMessage(
          context, 'Chưa thể lưu người thân. Vui lòng kiểm tra lại hồ sơ.');
    }
  }

  @override
  Widget build(BuildContext context) => MePage(
          title: widget.patient == null ? 'Thêm người thân' : 'Sửa người thân',
          children: [
            MeCard(
                child: Form(
                    key: _form,
                    child: Column(children: [
                      AppTextField(
                          label: 'Họ và tên',
                          controller: _name,
                          validator: (v) =>
                              Validators.required(v, field: 'Họ và tên')),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          initialValue: _relationship,
                          decoration:
                              const InputDecoration(labelText: 'Quan hệ'),
                          isExpanded: true,
                          items: [
                            for (final r in relationships)
                              DropdownMenuItem(value: r, child: Text(r))
                          ],
                          onChanged: (v) {
                            if (v != null) _relationship = v;
                          }),
                      const SizedBox(height: 16),
                      BirthdayField(
                          value: _birthday,
                          onChanged: (v) => setState(() => _birthday = v)),
                      const SizedBox(height: 16),
                      AppTextField(
                          label: 'Số điện thoại',
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          validator: Validators.vietnamesePhone),
                      const SizedBox(height: 16),
                      PrimaryButton(
                          label: 'Lưu người thân',
                          onPressed: _save,
                          isLoading: _saving),
                    ]))),
            const Text(demoSessionNotice,
                style: TextStyle(color: Color(0xFF666666), fontSize: 12))
          ]);
}
