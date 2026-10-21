import 'package:flutter/foundation.dart';
import '../../data/models/appointment.dart';
import '../../data/providers/patient_data_provider.dart';

class BookingController extends ChangeNotifier {
  BookingController(this.data, {DateTime Function()? clock})
      : now = clock ?? DateTime.now,
        patientId = data.selectedPatientId;
  final PatientDataProvider data;
  final DateTime Function() now;
  String patientId;
  int step = 0;
  final Set<String> serviceIds = {};
  String? doctorId;
  bool doctorChosen = false;
  DateTime? date;
  String? time;
  String voucher = '';
  String note = '';
  bool submitting = false;
  Appointment? created;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static final slots = [
    for (var h = 8; h <= 17; h++)
      if (h != 12) ...[
        '${h.toString().padLeft(2, '0')}:00',
        if (h != 17) '${h.toString().padLeft(2, '0')}:30'
      ],
  ];
  int get total => data.services
      .where((s) => serviceIds.contains(s.id))
      .fold(0, (sum, s) => sum + s.price);
  DateTime? at(String? slot) {
    if (date == null || slot == null || !slots.contains(slot)) return null;
    final parts = slot.split(':');
    return DateTime(date!.year, date!.month, date!.day, int.parse(parts[0]),
        int.parse(parts[1]));
  }

  bool validSlot(String slot) => at(slot)?.isAfter(now()) ?? false;
  bool get validTime => time != null && validSlot(time!);
  bool get canContinue => switch (step) {
        0 => serviceIds.isNotEmpty,
        1 => doctorChosen,
        _ => validTime,
      };
  void selectPatient(String id) {
    if (_disposed || submitting || created != null) return;
    patientId = id;
    notifyListeners();
  }

  void toggleService(String id) {
    if (_disposed || submitting || created != null) return;
    if (!serviceIds.add(id)) serviceIds.remove(id);
    notifyListeners();
  }

  void chooseDoctor(String? id) {
    if (_disposed || submitting || created != null) return;
    doctorId = id;
    doctorChosen = true;
    notifyListeners();
  }

  void chooseDate(DateTime value) {
    if (_disposed || submitting || created != null) return;
    final today = now();
    if (DateTime(value.year, value.month, value.day)
        .isBefore(DateTime(today.year, today.month, today.day))) {
      return;
    }
    date = value;
    if (!validTime) time = null;
    notifyListeners();
  }

  void chooseTime(String value) {
    if (_disposed || submitting || created != null) return;
    if (!validSlot(value)) return;
    time = value;
    notifyListeners();
  }

  void next() {
    if (!_disposed &&
        !submitting &&
        created == null &&
        canContinue &&
        step < 3) {
      step++;
      notifyListeners();
    }
  }

  void back() {
    if (_disposed || submitting || created != null) return;
    if (step > 0) {
      step--;
      notifyListeners();
    }
  }

  Future<Appointment?> submit() async {
    if (_disposed) return null;
    if (submitting || created != null) return created;
    if (serviceIds.isEmpty ||
        !doctorChosen ||
        !validTime ||
        !data.patients.any((p) => p.id == patientId)) {
      return null;
    }
    submitting = true;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (_disposed || !validTime) return null;
      final appointment = Appointment(
        id: 'booking-${DateTime.now().microsecondsSinceEpoch}',
        patientId: patientId,
        doctorId: doctorId,
        serviceIds: serviceIds.toList(),
        scheduledAt: at(time)!,
        status: AppointmentStatus.pending,
        note: note,
        totalPrice: total,
      );
      data.addAppointment(appointment);
      created = appointment;
      return appointment;
    } finally {
      submitting = false;
      if (!_disposed) notifyListeners();
    }
  }
}
