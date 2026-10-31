import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/models/home_appointment.dart';
import 'package:frontend/core/utils/clinic_time.dart';
import 'package:frontend/core/utils/formatters.dart';

void main() {
  test('A06: receipt keeps independent optional IDs; rejects non-string IDs',
      () {
    for (final entry in [
      ({'visitId': 'visit-1', 'appointmentId': 'appt-9'}, 'visit-1', 'appt-9'),
      ({'visitId': 'visit-1'}, 'visit-1', null),
      ({'appointmentId': 'appt-9'}, null, 'appt-9'),
      (<String, dynamic>{}, null, null),
      ({'visitId': 5, 'appointmentId': <String>[]}, null, null),
      ({'visitId': ' ', 'appointmentId': <String, dynamic>{}}, null, null),
    ]) {
      final receipt = Receipt.fromJson(entry.$1);
      expect(receipt.visitId, entry.$2);
      expect(receipt.appointmentId, entry.$3);
    }
  });
  test(
      'A06: visit lookup rejects wrong patient, conflicting IDs and missing linkage',
      () {
    final visit =
        Visit.fromJson({'id': 'v', 'patientId': 'p', 'appointmentId': 'a'});
    expect(Receipt.fromJson({'visitId': 'v'}).belongsToVisit(visit), isTrue);
    expect(
        Receipt.fromJson({'appointmentId': 'a'}).belongsToVisit(visit), isTrue);
    for (final row in [
      {'visitId': 'other', 'appointmentId': 'a'},
      {'visitId': 'v', 'appointmentId': 'other'},
      {'visitId': 'v', 'patientId': 'other'},
      <String, dynamic>{},
    ]) {
      expect(Receipt.fromJson(row).belongsToVisit(visit), isFalse);
    }
  });
  test(
      'A16: absent, empty, malformed and impossible clinical dates stay absent',
      () {
    for (final value in [
      null,
      '',
      'bad',
      '2026-02-30',
      '2026-13-01',
      '2026-10-31T25:00:00Z',
      {'_seconds': 'invalid'},
      {'_seconds': double.infinity},
      {'_seconds': 1e100}
    ]) {
      expect(Visit.fromJson({'visitedAt': value}).visitedAt, isNull);
      expect(Receipt.fromJson({'issuedAt': value}).issuedAt, isNull);
      expect(Prescription.fromJson({'issuedAt': value}).issuedAt, isNull);
      expect(Followup.fromJson({'scheduledAt': value}).scheduledAt, isNull);
      expect(TreatmentSession.fromJson({'scheduledAt': value}).scheduledAt,
          isNull);
    }
    expect(formatVietnameseDate(null), 'Chưa cập nhật');
  });
  test(
      'A16: valid ISO and Firestore dates remain available including real epoch',
      () {
    expect(Visit.fromJson({'visitedAt': '2026-10-31'}).visitedAt?.year, 2026);
    expect(
        Receipt.fromJson({
          'issuedAt': {'_seconds': 0}
        }).issuedAt,
        DateTime.utc(1970));
  });
  test('A15: booking selected clinic slot remains an instant in API mode', () {
    final previous = AppConfig.current;
    AppConfig.current = AppConfig.fromValues(
        source: 'api', baseUrl: 'http://fake.invalid:3000');
    addTearDown(() => AppConfig.current = previous);
    final data = PatientDataProvider(seedDemo: false);
    final controller = BookingController(data)..date = DateTime(2026, 11, 1);
    expect(controller.at('00:15'), DateTime.utc(2026, 10, 31, 17, 15));
    controller.dispose();
    data.dispose();
  });
  test('A15: split clinic time and UTC timestamp refer to identical instant',
      () {
    final split = Appointment.fromJson(
        {'date': '2026-11-01', 'startTime': '00:15', 'endTime': '00:45'});
    final stamp = Appointment.fromJson({'scheduledAt': '2026-10-31T17:15:00Z'});
    expect(split.scheduledAt, DateTime.utc(2026, 10, 31, 17, 15));
    expect(stamp.scheduledAt, split.scheduledAt);
    expect(split.displayScheduledAt.day, 1);
    expect(split.displayScheduledAt.hour, 0);
    expect(split.endAt!.difference(split.scheduledAt).inMinutes, 30);
    expect(
        HomeAppointment.read({'date': '2026-11-01', 'startTime': '00:15'})!
            .scheduledAt,
        split.scheduledAt);
    for (final offset in [0, 7, 9]) {
      final sameInstant = DateTime.parse(
          '2026-11-01T${offset.toString().padLeft(2, '0')}:15:00+${offset.toString().padLeft(2, '0')}:00');
      expect(clinicWallTime(sameInstant), DateTime.utc(2026, 11, 1, 7, 15));
    }
  });
}
