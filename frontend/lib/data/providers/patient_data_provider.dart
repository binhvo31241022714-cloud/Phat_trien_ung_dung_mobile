import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../mock_data.dart';
import '../models/appointment.dart';
import '../models/article.dart';
import '../models/dental_service.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/patient_records.dart';
import '../models/family_member.dart';
import '../models/user_profile.dart';
import '../services/records_service.dart';
import '../../core/network/api_client.dart';

class PatientDataProvider extends ChangeNotifier {
  final RecordsService _recordsService;
  PatientDataProvider({RecordsService? recordsService})
      : _recordsService = recordsService ?? RecordsService();

  final List<Patient> _patients = List.of(MockData.patients);
  final List<Appointment> _appointments = List.of(MockData.appointments);
  final List<PatientNotification> _notifications =
      List.of(MockData.notifications);
  final Set<String> _savedArticleIds = {};
  String _selectedPatientId = MockData.patients.first.id;
  List<Visit> _apiVisits = const [];
  List<Prescription> _apiPrescriptions = const [];
  List<Receipt> _apiReceipts = const [];
  List<TreatmentPlan> _apiTreatmentPlans = const [];
  List<Followup> _apiFollowups = const [];
  bool _recordsLoading = false;
  String? _recordsError;

  UnmodifiableListView<Patient> get patients => UnmodifiableListView(_patients);
  List<Patient> get familyMembers => patients;
  List<DentalService> get services => MockData.services;
  List<Doctor> get doctors => MockData.doctors;
  List<Article> get articles => MockData.articles;
  UnmodifiableListView<Appointment> get appointments =>
      UnmodifiableListView(_appointments);
  List<Visit> get visits => AppConfig.current.dataSource == DataSource.api
      ? _apiVisits
      : MockData.visits;
  List<Prescription> get prescriptions =>
      AppConfig.current.dataSource == DataSource.api
          ? _apiPrescriptions
          : MockData.prescriptions;
  List<Receipt> get receipts => AppConfig.current.dataSource == DataSource.api
      ? _apiReceipts
      : MockData.receipts;
  List<TreatmentPlan> get treatmentPlans =>
      AppConfig.current.dataSource == DataSource.api
          ? _apiTreatmentPlans
          : MockData.treatmentPlans;
  List<Followup> get followups => AppConfig.current.dataSource == DataSource.api
      ? _apiFollowups
      : MockData.followups;
  bool get recordsLoading => _recordsLoading;
  String? get recordsError => _recordsError;
  UnmodifiableListView<PatientNotification> get notifications =>
      UnmodifiableListView(_notifications);
  UnmodifiableSetView<String> get savedArticleIds =>
      UnmodifiableSetView(_savedArticleIds);
  List<Article> get savedArticles => List.unmodifiable(
        articles.where((article) => _savedArticleIds.contains(article.id)),
      );
  bool get recordsAreDemoAndReadOnly =>
      AppConfig.current.dataSource == DataSource.mock;
  int notificationsOpenVersion = 0;
  void requestNotifications() {
    notificationsOpenVersion++;
    notifyListeners();
  }

  String? _appointmentPatientId;
  String get appointmentPatientId =>
      _appointmentPatientId ?? _selectedPatientId;
  int recordsFocusVersion = 0;
  bool recordsShowAppointments = false;
  String? recordsAppointmentId;
  void focusAppointmentsFor(String patientId,
      {bool showAppointments = false, String? appointmentId}) {
    if (!patients.any((p) => p.id == patientId)) return;
    _appointmentPatientId = patientId;
    recordsFocusVersion++;
    recordsShowAppointments = showAppointments;
    recordsAppointmentId = appointmentId;
    notifyListeners();
    unawaited(loadRecords(patientId: patientId));
  }

  String get selectedPatientId => _selectedPatientId;

  Patient get selectedPatient =>
      patients.firstWhere((patient) => patient.id == _selectedPatientId);

  void syncPatients(UserProfile profile, List<FamilyMember> family) {
    final patients = <Patient>[
      Patient(
        id: profile.id,
        fullName: profile.fullName,
        phone: profile.phone,
        dateOfBirth: profile.birthday ?? DateTime(1970),
        relationship: 'Tôi',
        isPrimary: true,
      ),
      for (final member in family)
        Patient(
          id: member.id,
          fullName: member.fullName,
          phone: member.phone,
          dateOfBirth: member.birthday ?? DateTime(1970),
          relationship: member.relationship,
        ),
    ];
    if (patients.isEmpty) return;
    _patients
      ..clear()
      ..addAll(patients);
    if (!_patients.any((patient) => patient.id == _selectedPatientId)) {
      _selectedPatientId = profile.id;
    }
    notifyListeners();
  }

  Future<void> loadRecords({String? patientId}) async {
    if (AppConfig.current.dataSource != DataSource.api) {
      return;
    }

    final id = patientId ?? _selectedPatientId;
    if (!_patients.any((patient) => patient.id == id) && patientId != null) {
      return;
    }

    _recordsLoading = true;
    _recordsError = null;
    notifyListeners();
    try {
      final visitRows = await _recordsService.visits(id);
      final invoiceRows = await _recordsService.invoices(id);
      final treatmentRows = await _recordsService.treatments(id);
      final followupRows = await _recordsService.followups(id);
      final visits = <Visit>[];
      final prescriptions = <Prescription>[];
      for (final row in visitRows.whereType<Map<String, dynamic>>()) {
        final visit = Visit.fromJson(row);
        final detail = await _recordsService.visit(visit.id);
        visits.add(Visit.fromJson(detail));
        final prescriptionRows = await _recordsService.prescriptions(visit.id);
        prescriptions.addAll(prescriptionRows
            .whereType<Map<String, dynamic>>()
            .map(Prescription.fromJson));
      }
      final receipts = <Receipt>[];
      for (final row in invoiceRows.whereType<Map<String, dynamic>>()) {
        final invoice = await _recordsService.invoice(row['id'].toString());
        receipts.add(Receipt.fromJson(invoice));
      }
      final plans = <TreatmentPlan>[];
      for (final row in treatmentRows.whereType<Map<String, dynamic>>()) {
        final treatmentId = row['id'].toString();
        final detail = await _recordsService.treatment(treatmentId);
        final sessionRows = await _recordsService.sessions(treatmentId);
        final sessions = sessionRows
            .whereType<Map<String, dynamic>>()
            .map(TreatmentSession.fromJson)
            .toList();
        plans.add(TreatmentPlan.fromJson(detail, sessions: sessions));
      }
      if (id == _selectedPatientId) {
        _apiVisits = visits;
        _apiPrescriptions = prescriptions;
        _apiReceipts = receipts;
        _apiTreatmentPlans = plans;
        _apiFollowups = followupRows
            .whereType<Map<String, dynamic>>()
            .map(Followup.fromJson)
            .toList();
      }
    } on ApiException catch (error) {
      _recordsError = error.message;
    } finally {
      _recordsLoading = false;
      notifyListeners();
    }
  }

  Future<void> linkVisitToTreatment({
    required String treatmentId,
    required String visitId,
    required String sessionId,
  }) async {
    if (AppConfig.current.dataSource != DataSource.api) {
      throw const ApiException('Dữ liệu demo chỉ được xem.');
    }
    await _recordsService.linkVisitToTreatment(treatmentId, visitId, sessionId);
    await loadRecords();
  }

  void selectPatient(String patientId) {
    if (!_patients.any((patient) => patient.id == patientId)) {
      throw ArgumentError.value(
          patientId, 'patientId', 'Không tìm thấy bệnh nhân');
    }

    if (_selectedPatientId == patientId) return;
    _selectedPatientId = patientId;
    _appointmentPatientId = null;
    notifyListeners();
    unawaited(loadRecords(patientId: patientId));
  }

  void addFamilyMember(Patient patient) {
    if (_patients.any((item) => item.id == patient.id)) {
      throw ArgumentError.value(
        patient.id,
        'patient.id',
        'Mã bệnh nhân đã tồn tại',
      );
    }
    _patients.add(patient);
    notifyListeners();
  }

  Patient get primaryPatient => patients.firstWhere((p) => p.isPrimary);

  /// Đổi tên, SĐT, ngày sinh của "Bản thân" theo hồ sơ thật từ API.
  /// Giữ nguyên id để lịch hẹn, hồ sơ khám mock vẫn trỏ đúng.
  void applyAccountProfile(
      {required String name, required String phone, DateTime? dateOfBirth}) {
    final p = primaryPatient;
    final newName = name.trim().isEmpty ? p.fullName : name.trim();
    final newDob = dateOfBirth ?? p.dateOfBirth;
    if (newName == p.fullName && phone == p.phone && newDob == p.dateOfBirth) {
      return;
    }
    updatePatient(Patient(
        id: p.id,
        fullName: newName,
        phone: phone,
        dateOfBirth: newDob,
        relationship: p.relationship,
        isPrimary: true,
        avatarAsset: p.avatarAsset));
  }

  int _familySequence = 0;
  Patient addRelative(
      {required String name,
      required String relationship,
      required DateTime dateOfBirth,
      String phone = ''}) {
    final patient = Patient(
        id: 'family-${DateTime.now().microsecondsSinceEpoch}-${_familySequence++}',
        fullName: name.trim(),
        phone: phone.trim(),
        dateOfBirth: dateOfBirth,
        relationship: relationship);
    addFamilyMember(patient);
    return patient;
  }

  void updatePatient(Patient patient) {
    final index = _patients.indexWhere((p) => p.id == patient.id);
    if (index < 0 || patient.isPrimary != _patients[index].isPrimary) {
      throw ArgumentError('Hồ sơ bệnh nhân không hợp lệ');
    }
    _patients[index] = patient;
    notifyListeners();
  }

  String? familyRemovalBlockReason(String id) {
    final matches = patients.where((p) => p.id == id);
    if (matches.isEmpty) return 'Không tìm thấy người thân.';
    if (matches.first.isPrimary) return 'Không thể xóa hồ sơ bản thân.';
    if (appointments.any((a) => a.patientId == id) ||
        visits.any((v) => v.patientId == id) ||
        treatmentPlans.any((p) => p.patientId == id) ||
        followups.any((f) => f.patientId == id)) {
      return 'Người thân có lịch hẹn hoặc hồ sơ nha khoa liên kết nên chưa thể xóa trong bản demo.';
    }
    return null;
  }

  String? removeFamilyMember(String id) {
    final reason = familyRemovalBlockReason(id);
    if (reason != null) return reason;
    _patients.removeWhere((p) => p.id == id);
    if (_selectedPatientId == id) _selectedPatientId = primaryPatient.id;
    if (_appointmentPatientId == id) {
      _appointmentPatientId = primaryPatient.id;
      recordsFocusVersion++;
      recordsShowAppointments = false;
      recordsAppointmentId = null;
    }
    if (_bookingPatientRequest == id) {
      _bookingPatientRequest = primaryPatient.id;
    }
    notifyListeners();
    return null;
  }

  void toggleSavedArticle(String articleId) {
    if (!articles.any((article) => article.id == articleId)) {
      throw ArgumentError.value(
        articleId,
        'articleId',
        'Không tìm thấy bài viết',
      );
    }
    if (!_savedArticleIds.add(articleId)) {
      _savedArticleIds.remove(articleId);
    }
    notifyListeners();
  }

  final Set<String> savedServiceIds = {};
  final Set<String> savedDoctorIds = {};

  void toggleSavedService(String id) {
    if (!savedServiceIds.add(id)) savedServiceIds.remove(id);
    notifyListeners();
  }

  void toggleSavedDoctor(String id) {
    if (!savedDoctorIds.add(id)) savedDoctorIds.remove(id);
    notifyListeners();
  }

  void markNotificationRead(String notificationId) {
    final index =
        _notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0) {
      throw ArgumentError.value(
        notificationId,
        'notificationId',
        'Không tìm thấy thông báo',
      );
    }
    final current = _notifications[index];
    if (current.isRead) return;
    _notifications[index] = PatientNotification(
      id: current.id,
      title: current.title,
      message: current.message,
      createdAt: current.createdAt,
      isRead: true,
      category: current.category,
      appointmentId: current.appointmentId,
    );
    notifyListeners();
  }

  Patient get recordsPatient =>
      patients.firstWhere((p) => p.id == appointmentPatientId);

  List<Appointment> appointmentsFor(String patientId, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final result = appointments.where((a) => a.patientId == patientId).toList();
    bool upcoming(Appointment a) =>
        a.scheduledAt.isAfter(current) &&
        (a.status == AppointmentStatus.pending ||
            a.status == AppointmentStatus.confirmed);
    result.sort((a, b) {
      if (upcoming(a) != upcoming(b)) {
        return upcoming(a) ? -1 : 1;
      }
      final byTime = upcoming(a)
          ? a.scheduledAt.compareTo(b.scheduledAt)
          : b.scheduledAt.compareTo(a.scheduledAt);
      return byTime == 0 ? a.id.compareTo(b.id) : byTime;
    });
    return result;
  }

  List<Visit> visitsFor(String patientId) =>
      visits.where((v) => v.patientId == patientId).toList()
        ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
  List<TreatmentPlan> treatmentsFor(String patientId) =>
      treatmentPlans.where((p) => p.patientId == patientId).toList();
  List<Followup> followupsFor(String patientId) =>
      followups.where((f) => f.patientId == patientId).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  bool canCancelAppointment(Appointment a, {DateTime? now}) =>
      a.isDemo &&
      a.scheduledAt.isAfter(now ?? DateTime.now()) &&
      (a.status == AppointmentStatus.pending ||
          a.status == AppointmentStatus.confirmed);
  bool cancelAppointment(String id, {DateTime? now}) {
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index < 0 || !canCancelAppointment(_appointments[index], now: now)) {
      return false;
    }
    final a = _appointments[index];
    _appointments[index] = Appointment(
        id: a.id,
        patientId: a.patientId,
        doctorId: a.doctorId,
        totalPrice: a.totalPrice,
        serviceIds: a.serviceIds,
        scheduledAt: a.scheduledAt,
        status: AppointmentStatus.cancelled,
        note: a.note,
        isDemo: a.isDemo);
    notifyListeners();
    return true;
  }

  String? _bookingPatientRequest;
  String? takeBookingPatientRequest() {
    final id = _bookingPatientRequest;
    _bookingPatientRequest = null;
    return id;
  }

  void requestBookingFor(String patientId) {
    if (!patients.any((p) => p.id == patientId)) return;
    _bookingPatientRequest = patientId;
    notifyListeners();
  }

  void addAppointment(Appointment appointment) {
    if (_appointments.any((item) => item.id == appointment.id)) {
      throw ArgumentError.value(
        appointment.id,
        'appointment.id',
        'Mã lịch hẹn đã tồn tại',
      );
    }
    if (!patients.any((patient) => patient.id == appointment.patientId)) {
      throw ArgumentError.value(
        appointment.patientId,
        'appointment.patientId',
        'Không tìm thấy bệnh nhân',
      );
    }
    if (appointment.doctorId != null &&
        !doctors.any((doctor) => doctor.id == appointment.doctorId)) {
      throw ArgumentError.value(
        appointment.doctorId,
        'appointment.doctorId',
        'Không tìm thấy bác sĩ',
      );
    }
    if (appointment.serviceIds.isEmpty ||
        !appointment.serviceIds.every(
          (id) => services.any((service) => service.id == id),
        )) {
      throw ArgumentError.value(
        appointment.serviceIds,
        'appointment.serviceIds',
        'Dịch vụ không hợp lệ',
      );
    }
    _appointments.add(appointment);
    notifyListeners();
  }

  void replaceAppointments(List<Appointment> appointments) {
    _appointments
      ..clear()
      ..addAll(appointments);
    notifyListeners();
  }
}
