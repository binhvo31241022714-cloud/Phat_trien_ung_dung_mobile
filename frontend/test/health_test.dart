import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/models/health_info.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';

import 'me_test.dart' show demoUsers, openMe, pumpMe, setBirthday;
import 'support/fake_profile_backend.dart';

/// Mở ô "Giới tính" rồi chọn [label] (Nam / Nữ / Khác).
Future<void> chooseGender(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final field = find.ancestor(
      of: find.text('Giới tính'),
      matching: find.byType(DropdownButtonFormField<String>));
  await Scrollable.ensureVisible(tester.element(field), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  test('HealthInfo.fromJson tolerates missing, null and unknown values', () {
    final h = HealthInfo.fromJson({
      'allergies': ' Penicillin ',
      'medicalConditions': ['diabetes', 'cam_cum', 3, 'diabetes'],
      'currentMedications': null,
      'isPregnant': 'true',
    });
    expect(h.allergies, 'Penicillin');
    expect(h.medicalConditions, ['diabetes']);
    expect(h.currentMedications, '');
    expect(h.isPregnant, isFalse);
    expect(h.hasWarning, isTrue);
    expect(HealthInfo.fromJson({}).hasWarning, isFalse);

    final p = UserProfile.fromJson({'gender': 'nam', 'allergies': 'Aspirin'});
    expect(p.gender, '');
    expect(p.health.allergies, 'Aspirin');
  });

  test('isPregnant is only kept for female', () {
    const h = HealthInfo(isPregnant: true, allergies: 'A');
    expect(h.forGender('female').isPregnant, isTrue);
    expect(h.forGender('male').isPregnant, isFalse);
    expect(h.forGender('').isPregnant, isFalse);
    expect(h.forGender('male').allergies, 'A');
    final json =
        const FamilyMember(id: 'f', gender: 'male', health: h).toJson();
    expect(json['gender'], 'male');
    expect(json['isPregnant'], isFalse);
  });

  testWidgets(
      'profile saves gender and health, pregnancy switch follows gender',
      (tester) async {
    final u = demoUsers(), d = PatientDataProvider();
    final backend = FakeProfileBackend(me: {
      'id': 'uid-test',
      'email': 'patient@example.com',
      'fullName': 'Trần Thị Test',
      'birthday': '1995-03-04',
    });
    await pumpMe(tester, u, d, profile: backend.provider());
    expect(find.text('⚠ Có lưu ý sức khỏe'), findsNothing);
    await openMe(tester, 'Thông tin cá nhân');
    expect(find.text('Thông tin sức khỏe'), findsOneWidget);
    expect(
        find.text(
            'Thông tin này giúp bác sĩ chuẩn bị an toàn trước khi điều trị.'),
        findsOneWidget);
    // Chưa chọn giới tính: không có công tắc mang thai.
    expect(find.text('Đang mang thai'), findsNothing);

    await chooseGender(tester, 'Nữ');
    expect(find.text('Đang mang thai'), findsOneWidget);
    await openMe(tester, 'Đang mang thai');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Dị ứng thuốc'), 'Penicillin');
    await openMe(tester, 'Tiểu đường');
    await openMe(tester, 'Hen suyễn');
    await openMe(tester, 'Lưu thay đổi');
    expect(backend.me['gender'], 'female');
    expect(backend.me['allergies'], 'Penicillin');
    expect(backend.me['medicalConditions'], ['diabetes', 'asthma']);
    expect(backend.me['isPregnant'], isTrue);
    // Quay về tab "Tôi": hiện nhãn lưu ý sức khỏe.
    expect(find.text('⚠ Có lưu ý sức khỏe'), findsOneWidget);

    // Đổi sang Nam: công tắc biến mất, lưu thì isPregnant về false.
    await openMe(tester, 'Thông tin cá nhân');
    await chooseGender(tester, 'Nam');
    expect(find.text('Đang mang thai'), findsNothing);
    await openMe(tester, 'Lưu thay đổi');
    expect(backend.me['gender'], 'male');
    expect(backend.me['isPregnant'], isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('family member saves gender and health and shows the badge',
      (tester) async {
    final u = demoUsers(), d = PatientDataProvider();
    final backend = FakeProfileBackend(family: [
      {'id': 'fam-old', 'fullName': 'Bé Na', 'relationship': 'Con'}
    ]);
    await pumpMe(tester, u, d, profile: backend.provider());
    await openMe(tester, 'Quản lý người thân');
    expect(find.text('⚠ Có lưu ý sức khỏe'), findsNothing);

    await openMe(tester, 'Thêm người thân');
    await tester.enterText(find.byType(TextFormField).first, 'Ông Nội');
    await setBirthday(tester);
    await chooseGender(tester, 'Nam');
    await openMe(tester, 'Huyết áp cao');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Thuốc đang dùng'), 'Amlodipine');
    await openMe(tester, 'Lưu người thân');
    final saved = backend.family.firstWhere((m) => m['fullName'] == 'Ông Nội');
    expect(saved['gender'], 'male');
    expect(saved['medicalConditions'], ['hypertension']);
    expect(saved['currentMedications'], 'Amlodipine');
    expect(saved['isPregnant'], isFalse);
    expect(find.text('⚠ Có lưu ý sức khỏe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
