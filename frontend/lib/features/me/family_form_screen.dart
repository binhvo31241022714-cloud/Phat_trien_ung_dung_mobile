import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/family_member.dart';
import '../../providers/profile_provider.dart';
import 'me_widgets.dart';

class FamilyFormScreen extends StatefulWidget {
  const FamilyFormScreen({this.member, super.key});
  final FamilyMember? member;
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
    final p = widget.member;
    _name = TextEditingController(text: p?.fullName);
    _phone = TextEditingController(text: p?.phone);
    _birthday = p?.birthday;
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

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final profile = context.read<ProfileProvider>();
    final p = widget.member;
    final member = FamilyMember(
        id: p?.id ?? '',
        fullName: _name.text.trim(),
        relationship: _relationship,
        birthday: _birthday,
        phone: _phone.text.trim());
    final error = p == null
        ? await profile.addFamily(member)
        : await profile.updateFamily(member);
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      meMessage(context, 'Chưa lưu được người thân: $error');
      return;
    }
    meMessage(context,
        p == null ? 'Đã thêm người thân.' : 'Đã cập nhật người thân.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => MePage(
          title: widget.member == null ? 'Thêm người thân' : 'Sửa người thân',
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
          ]);
}
