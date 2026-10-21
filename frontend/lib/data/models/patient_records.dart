abstract class DemoReadOnlyRecord {
  const DemoReadOnlyRecord();

  bool get isDemo => true;
  bool get isReadOnly => true;
}

class Visit extends DemoReadOnlyRecord {
  final String id;
  final String patientId;
  final DateTime visitedAt;
  final String clinic;
  final String? appointmentId;
  final String? doctorId;
  final List<String> serviceIds;
  final String? treatment;
  final String? result;
  final String? professionalNote;
  final String diagnosis;
  final String note;

  const Visit({
    required this.id,
    required this.patientId,
    required this.visitedAt,
    required this.clinic,
    this.appointmentId,
    this.doctorId,
    this.serviceIds = const [],
    this.treatment,
    this.result,
    this.professionalNote,
    required this.diagnosis,
    required this.note,
  });
}

class PrescriptionItem {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;

  const PrescriptionItem({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
  });
}

class Prescription extends DemoReadOnlyRecord {
  final String id;
  final String visitId;
  final DateTime issuedAt;
  final List<PrescriptionItem> items;
  final String instructions;

  Prescription({
    required this.id,
    required this.visitId,
    required this.issuedAt,
    required List<PrescriptionItem> items,
    required this.instructions,
  }) : items = List.unmodifiable(items);
}

class ReceiptItem {
  final String name;
  final int price;
  const ReceiptItem({required this.name, required this.price});
}

class Receipt extends DemoReadOnlyRecord {
  final String id;
  final String appointmentId;
  final DateTime issuedAt;
  final int amount;
  final String paymentMethod;
  final List<ReceiptItem> items;
  final int? subtotal;
  final int? discount;
  final String? paymentStatus;

  const Receipt({
    required this.id,
    required this.appointmentId,
    required this.issuedAt,
    required this.amount,
    required this.paymentMethod,
    this.items = const [],
    this.subtotal,
    this.discount,
    this.paymentStatus,
  });
}

class TreatmentSession {
  final String title;
  final bool completed;
  const TreatmentSession({required this.title, required this.completed});
}

class TreatmentPlan extends DemoReadOnlyRecord {
  final String id;
  final String patientId;
  final String title;
  final String description;
  final int completedVisits;
  final int totalVisits;
  final String? doctorId;
  final List<TreatmentSession> sessions;
  final String? beforeImage;
  final String? afterImage;
  double get progress =>
      totalVisits <= 0 ? 0 : (completedVisits / totalVisits).clamp(0.0, 1.0);

  const TreatmentPlan({
    required this.id,
    required this.patientId,
    required this.title,
    required this.description,
    required this.completedVisits,
    required this.totalVisits,
    this.doctorId,
    this.sessions = const [],
    this.beforeImage,
    this.afterImage,
  });
}

class Followup extends DemoReadOnlyRecord {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime scheduledAt;
  final String note;

  const Followup({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.scheduledAt,
    required this.note,
  });
}

enum NotificationCategory { appointment, offer, system }

class PatientNotification extends DemoReadOnlyRecord {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final NotificationCategory category;
  final String? appointmentId;

  const PatientNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.category = NotificationCategory.system,
    this.appointmentId,
  });
}
