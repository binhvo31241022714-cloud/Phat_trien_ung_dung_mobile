import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/models/user_profile.dart';

void main() {
  test('UserProfile.fromJson tolerates missing, null and wrong-typed fields',
      () {
    final p = UserProfile.fromJson({
      'id': 'uid-1',
      'email': 'a@example.com',
      'fullName': null,
      'phone': 123,
      'createdAt': {'_seconds': 1792732331, '_nanoseconds': 0},
    });
    expect(p.id, 'uid-1');
    expect(p.fullName, '');
    expect(p.phone, '');
    expect(p.birthday, isNull);
    expect(p.gender, '');

    final empty = UserProfile.fromJson({});
    expect(empty.id, '');
    expect(empty.email, '');
  });

  test('birthday reads yyyy-MM-dd and treats empty or bad text as null', () {
    expect(UserProfile.fromJson({'birthday': '2000-05-31'}).birthday,
        DateTime(2000, 5, 31));
    expect(UserProfile.fromJson({'birthday': ''}).birthday, isNull);
    expect(
        UserProfile.fromJson({'birthday': 'không phải ngày'}).birthday, isNull);
    expect(writeDate(DateTime(2001, 2, 3)), '2001-02-03');
  });

  test('FamilyMember round-trips the backend body', () {
    final m = FamilyMember.fromJson({
      'id': 'f1',
      'fullName': ' Nguyễn Thị Mẹ ',
      'relationship': 'Mẹ',
      'birthday': '',
      'phone': '0911111111',
    });
    expect(m.fullName, 'Nguyễn Thị Mẹ');
    expect(m.birthday, isNull);
    expect(m.toJson(), {
      'fullName': 'Nguyễn Thị Mẹ',
      'relationship': 'Mẹ',
      'birthday': '',
      'phone': '0911111111',
    });
    expect(FamilyMember.fromJson({'id': 'f2'}).relationship, '');
  });
}
