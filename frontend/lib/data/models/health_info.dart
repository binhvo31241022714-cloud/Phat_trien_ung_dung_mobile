import 'json_read.dart';

/// Giới tính backend nhận; '' là chưa chọn.
const genderLabels = {'male': 'Nam', 'female': 'Nữ', 'other': 'Khác'};

/// Đọc giới tính, giá trị lạ coi như chưa chọn.
String readGender(Object? value) =>
    value is String && genderLabels.containsKey(value) ? value : '';

/// Bệnh nền backend nhận, theo đúng thứ tự hiển thị.
const medicalConditionLabels = {
  'diabetes': 'Tiểu đường',
  'heart_disease': 'Bệnh tim mạch',
  'hypertension': 'Huyết áp cao',
  'bleeding_disorder': 'Rối loạn đông máu',
  'asthma': 'Hen suyễn',
  'hepatitis': 'Viêm gan',
  'other': 'Khác',
};

/// Thông tin sức khỏe của bản thân hoặc người thân.
class HealthInfo {
  final String allergies;
  final List<String> medicalConditions;
  final String currentMedications;
  final bool isPregnant;
  final String healthNotes;

  const HealthInfo({
    this.allergies = '',
    this.medicalConditions = const [],
    this.currentMedications = '',
    this.isPregnant = false,
    this.healthNotes = '',
  });

  /// Chịu được trường thiếu, null hoặc sai kiểu. Bệnh nền lạ bị bỏ qua.
  factory HealthInfo.fromJson(Map<String, dynamic> json) => HealthInfo(
        allergies: readString(json['allergies']),
        medicalConditions: List.unmodifiable(
            readStringList(json['medicalConditions'])
                .where(medicalConditionLabels.containsKey)
                .toSet()),
        currentMedications: readString(json['currentMedications']),
        isPregnant: json['isPregnant'] == true,
        healthNotes: readString(json['healthNotes']),
      );

  Map<String, dynamic> toJson() => {
        'allergies': allergies,
        'medicalConditions': medicalConditions,
        'currentMedications': currentMedications,
        'isPregnant': isPregnant,
        'healthNotes': healthNotes,
      };

  /// Chỉ giữ "đang mang thai" khi giới tính là Nữ.
  HealthInfo forGender(String gender) => gender == 'female' || !isPregnant
      ? this
      : HealthInfo(
          allergies: allergies,
          medicalConditions: medicalConditions,
          currentMedications: currentMedications,
          healthNotes: healthNotes,
        );

  /// Có dị ứng hoặc bệnh nền: hiện nhãn "Có lưu ý sức khỏe".
  bool get hasWarning => allergies.isNotEmpty || medicalConditions.isNotEmpty;
}
