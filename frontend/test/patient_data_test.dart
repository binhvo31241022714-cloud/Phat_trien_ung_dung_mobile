import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/formatters.dart';
import 'package:frontend/data/mock_data.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/shared/article_card.dart';
import 'package:frontend/features/shared/doctor_card.dart';
import 'package:frontend/features/shared/service_card.dart';

void main() {
  group('Định dạng hiển thị tiếng Việt', () {
    test('định dạng tiền VND có phân cách hàng nghìn', () {
      expect(formatVnd(150000), '150.000 ₫');
    });

    test('định dạng ngày và giờ', () {
      final date = DateTime(2026, 10, 24, 9, 5);
      expect(formatVietnameseDate(date), '24/10/2026');
      expect(formatVietnameseTime(date), '09:05');
      expect(formatVietnameseDateTime(date), '24/10/2026 lúc 09:05');
    });
  });

  group('Dữ liệu mẫu bệnh nhân', () {
    test('combo là một dịch vụ thông thường trong danh sách', () {
      final combos = MockData.services.where((service) => service.isCombo);
      expect(combos, hasLength(1));
      expect(MockData.services, contains(combos.single));
    });

    test('lịch hẹn liên kết tới bệnh nhân, bác sĩ và dịch vụ có thật', () {
      for (final appointment in MockData.appointments) {
        expect(
          MockData.patients
              .any((patient) => patient.id == appointment.patientId),
          isTrue,
        );
        expect(
          MockData.doctors.any((doctor) => doctor.id == appointment.doctorId),
          isTrue,
        );
        expect(
          appointment.serviceIds.every(
            (id) => MockData.services.any((service) => service.id == id),
          ),
          isTrue,
        );
      }
    });

    test('hồ sơ liên kết tới lịch hẹn, lần khám và bác sĩ có thật', () {
      for (final visit in MockData.visits) {
        expect(
          MockData.patients.any((patient) => patient.id == visit.patientId),
          isTrue,
        );
      }
      for (final prescription in MockData.prescriptions) {
        expect(
          MockData.visits.any((visit) => visit.id == prescription.visitId),
          isTrue,
        );
      }
      for (final receipt in MockData.receipts) {
        expect(
          MockData.appointments
              .any((appointment) => appointment.id == receipt.appointmentId),
          isTrue,
        );
      }
      for (final followup in MockData.followups) {
        expect(
          MockData.patients.any((patient) => patient.id == followup.patientId),
          isTrue,
        );
        expect(
          MockData.doctors.any((doctor) => doctor.id == followup.doctorId),
          isTrue,
        );
      }
    });

    test('hồ sơ khám được đánh dấu demo và chỉ đọc', () {
      final records = <DemoReadOnlyRecord>[
        ...MockData.visits,
        ...MockData.prescriptions,
        ...MockData.receipts,
        ...MockData.treatmentPlans,
        ...MockData.followups,
        ...MockData.notifications,
      ];

      expect(records, isNotEmpty);
      expect(records.every((record) => record.isDemo), isTrue);
      expect(records.every((record) => record.isReadOnly), isTrue);
    });
  });

  test('provider chia sẻ dữ liệu và phát thông báo khi đổi bệnh nhân', () {
    final provider = PatientDataProvider();
    var notified = false;
    provider.addListener(() => notified = true);

    expect(provider.selectedPatient.id, 'patient-001');
    provider.selectPatient('patient-002');

    expect(provider.selectedPatient.fullName, 'Nguyễn Hải Nam');
    expect(notified, isTrue);
    expect(provider.recordsAreDemoAndReadOnly, isTrue);
    expect(
      () => provider.selectPatient('patient-missing'),
      throwsArgumentError,
    );
  });

  test('provider cập nhật lịch hẹn chung cho các màn hình đang nghe', () {
    final provider = PatientDataProvider();
    var notified = false;
    provider.addListener(() => notified = true);
    final appointment = Appointment(
      id: 'appointment-new',
      patientId: 'patient-001',
      doctorId: 'doctor-lan',
      serviceIds: ['service-combo-family'],
      scheduledAt: DateTime(2026, 11, 2, 9),
      status: AppointmentStatus.pending,
    );

    provider.addAppointment(appointment);

    expect(provider.appointments, contains(appointment));
    expect(notified, isTrue);
    expect(() => provider.appointments.clear(), throwsUnsupportedError);
    expect(
      () => provider.addAppointment(appointment),
      throwsArgumentError,
    );
  });

  test('provider chia sẻ bệnh nhân, thông báo và bài viết đã lưu', () {
    final provider = PatientDataProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.selectPatient('patient-002');
    provider.toggleSavedArticle('article-brushing');
    provider.markNotificationRead('notification-appointment');

    expect(provider.selectedPatient.id, 'patient-002');
    expect(provider.familyMembers, hasLength(2));
    expect(provider.savedArticles.single.id, 'article-brushing');
    expect(
      provider.notifications
          .firstWhere((item) => item.id == 'notification-appointment')
          .isRead,
      isTrue,
    );
    expect(notifications, 3);
  });

  test('danh sách provider và palette theme sẵn sàng dùng chung', () {
    final provider = PatientDataProvider();
    expect(() => provider.patients.clear(), throwsUnsupportedError);
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.colorScheme.primary.toARGB32(), 0xFF1677DA);
  });

  testWidgets('thẻ dùng chung vừa màn hình mobile hẹp', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cards = <Widget>[
      ServiceCard(service: MockData.services[2]),
      DoctorCard(doctor: MockData.doctors.first),
      ArticleCard(article: MockData.articles.first),
    ];
    for (final card in cards) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: card,
            ),
          ),
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '${card.runtimeType} should fit a narrow mobile viewport',
      );
    }
    expect(AppColors.background, const Color(0xFFF8FBFF));
  });
}
