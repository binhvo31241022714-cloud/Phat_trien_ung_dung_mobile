import 'package:flutter/material.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/models/health_info.dart';

/// Giữ dữ liệu đang nhập của giới tính và thông tin sức khỏe, dùng chung cho
/// màn hình Thông tin cá nhân và Thêm/Sửa người thân.
class HealthFormController {
  HealthFormController(
      {HealthInfo initial = const HealthInfo(), this.gender = ''})
      : allergies = TextEditingController(text: initial.allergies),
        medications = TextEditingController(text: initial.currentMedications),
        notes = TextEditingController(text: initial.healthNotes),
        conditions = {...initial.medicalConditions},
        isPregnant = initial.isPregnant;

  final TextEditingController allergies, medications, notes;
  final Set<String> conditions;
  bool isPregnant;

  /// '' là chưa chọn.
  String gender;

  /// Dữ liệu để gửi lên máy chủ. Giới tính khác Nữ thì isPregnant = false.
  HealthInfo build() => HealthInfo(
        allergies: allergies.text.trim(),
        medicalConditions: [
          for (final key in medicalConditionLabels.keys)
            if (conditions.contains(key)) key
        ],
        currentMedications: medications.text.trim(),
        isPregnant: isPregnant,
        healthNotes: notes.text.trim(),
      ).forGender(gender);

  void dispose() {
    allergies.dispose();
    medications.dispose();
    notes.dispose();
  }
}

/// Ô chọn giới tính (Nam / Nữ / Khác), cùng kiểu ô "Quan hệ".
class GenderField extends StatelessWidget {
  const GenderField({required this.value, required this.onChanged, super.key});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      decoration: const InputDecoration(labelText: 'Giới tính'),
      hint: const Text('Chưa chọn'),
      isExpanded: true,
      items: [
        for (final entry in genderLabels.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value))
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      });
}

String? _maxLength(String? value) =>
    (value?.trim().length ?? 0) > 500 ? 'Tối đa 500 ký tự' : null;

/// Mục "Thông tin sức khỏe": dị ứng, bệnh nền, thuốc, mang thai, ghi chú.
class HealthInfoSection extends StatelessWidget {
  const HealthInfoSection(
      {required this.controller, required this.onChanged, super.key});
  final HealthFormController controller;

  /// Gọi sau khi chọn chip hoặc bật công tắc để màn hình vẽ lại.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Thông tin sức khỏe',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text(
          'Thông tin này giúp bác sĩ chuẩn bị an toàn trước khi điều trị.',
          style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
      const SizedBox(height: 12),
      AppTextField(
          label: 'Dị ứng thuốc',
          hint: 'Ví dụ: Penicillin, Lidocaine',
          controller: c.allergies,
          validator: _maxLength),
      const SizedBox(height: 12),
      const Text('Bệnh nền', style: TextStyle(color: Color(0xFF666666))),
      const SizedBox(height: 8),
      // Cùng kiểu chip đen trắng ở màn hình Thông báo, Đã lưu.
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final entry in medicalConditionLabels.entries)
          FilterChip(
              label: Text(entry.value),
              selected: c.conditions.contains(entry.key),
              showCheckmark: false,
              selectedColor: Colors.black,
              labelStyle: TextStyle(
                  color: c.conditions.contains(entry.key)
                      ? Colors.white
                      : Colors.grey),
              onSelected: (selected) {
                selected
                    ? c.conditions.add(entry.key)
                    : c.conditions.remove(entry.key);
                onChanged();
              })
      ]),
      const SizedBox(height: 12),
      AppTextField(
          label: 'Thuốc đang dùng',
          controller: c.medications,
          validator: _maxLength),
      // Chỉ hỏi mang thai khi giới tính là Nữ.
      if (c.gender == 'female')
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: Colors.black,
            title: const Text('Đang mang thai'),
            value: c.isPregnant,
            onChanged: (v) {
              c.isPregnant = v;
              onChanged();
            })
      else
        const SizedBox(height: 12),
      AppTextField(
          label: 'Ghi chú khác',
          controller: c.notes,
          maxLines: 3,
          validator: _maxLength),
    ]);
  }
}

/// Nhãn nhỏ "⚠ Có lưu ý sức khỏe" khi có dị ứng hoặc bệnh nền.
class HealthWarningBadge extends StatelessWidget {
  const HealthWarningBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(10)),
      child: const Text('⚠ Có lưu ý sức khỏe',
          style: TextStyle(
              color: Color(0xFFE65100),
              fontSize: 12,
              fontWeight: FontWeight.w600)));
}
