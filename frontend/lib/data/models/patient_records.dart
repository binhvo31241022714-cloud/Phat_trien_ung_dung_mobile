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
  final String? doctorName;
  final String? serviceName;
  final List<String> serviceNames;
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
    this.doctorName,
    this.serviceName,
    this.serviceNames = const [],
    this.serviceIds = const [],
    this.treatment,
    this.result,
    this.professionalNote,
    required this.diagnosis,
    required this.note,
  });

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: _string(json['id']),
        patientId: _string(json['patientId']),
        visitedAt: _date(
            json['scheduledAt'] ?? json['visitedAt'] ?? json['createdAt']),
        clinic: _string(json['clinic']),
        appointmentId: _nullableString(json['appointmentId']),
        doctorId: _nullableString(json['doctorId']),
        doctorName: _displayName(json['doctorName']),
        serviceName: _displayName(json['serviceName']),
        serviceNames: json['serviceNames'] is List &&
                (json['serviceNames'] as List).every((value) => value is String)
            ? (json['serviceNames'] as List).cast<String>().toList()
            : const [],
        serviceIds: _strings(json['serviceIds']),
        treatment: _nullableString(json['treatment']),
        result: _nullableString(json['result']),
        professionalNote:
            _nullableString(json['doctorNote'] ?? json['professionalNote']),
        diagnosis: _string(json['diagnosis']),
        note: _string(json['note'] ?? json['doctorNote']),
      );
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

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) =>
      PrescriptionItem(
        name: _string(json['name'] ?? json['medicineName']),
        dosage: _string(json['dosage']),
        frequency: _string(json['frequency']),
        duration:
            '${json['durationDays'] ?? json['duration'] ?? ''}${json['durationDays'] == null ? '' : ' ngày'}',
      );
}

class Prescription extends DemoReadOnlyRecord {
  final String id;
  final String? doctorName;
  final String? doctorId;
  final String visitId;
  final String patientId;
  final DateTime issuedAt;
  final List<PrescriptionItem> items;
  final String instructions;

  Prescription({
    required this.id,
    this.doctorName,
    this.doctorId,
    required this.visitId,
    this.patientId = '',
    required this.issuedAt,
    required List<PrescriptionItem> items,
    required this.instructions,
  }) : items = List.unmodifiable(items);

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: _string(json['id']),
        doctorName: _displayName(json['doctorName']),
        doctorId: _nullableString(json['doctorId']),
        visitId: _string(json['visitId']),
        patientId: _string(json['patientId']),
        issuedAt: _date(json['issuedAt']),
        items: _list(json['items'])
            .map((item) => PrescriptionItem.fromJson(item))
            .toList(),
        instructions: _string(json['note'] ?? json['instructions']),
      );
}

class ReceiptItem {
  final String name;
  final int price;
  const ReceiptItem({required this.name, required this.price});

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        name: _string(json['name']),
        price: _int(json['amount'] ?? json['unitPrice'] ?? json['price']),
      );
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
  final String patientId;

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
    this.patientId = '',
  });

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        id: _string(json['id']),
        appointmentId: _string(json['visitId'] ?? json['appointmentId']),
        issuedAt: _date(json['issuedAt']),
        amount: _int(json['totalAmount'] ?? json['amount']),
        paymentMethod: _string(json['paymentMethod']),
        subtotal: _intOrNull(json['subtotal']),
        discount: _intOrNull(json['discountAmount'] ?? json['discount']),
        paymentStatus: _nullableString(json['paymentStatus']),
        patientId: _string(json['patientId']),
        items: _list(json['items'])
            .map((item) => ReceiptItem.fromJson(item))
            .toList(),
      );
}

class TreatmentSession {
  final String id;
  final String title;
  final bool completed;
  final DateTime? scheduledAt;
  final String notes;
  final String? appointmentId;
  final String? visitId;
  const TreatmentSession(
      {this.id = '',
      required this.title,
      required this.completed,
      this.scheduledAt,
      this.notes = '',
      this.appointmentId,
      this.visitId});

  factory TreatmentSession.fromJson(Map<String, dynamic> json) =>
      TreatmentSession(
        id: _string(json['id']),
        title: 'Buổi ${json['sessionNumber'] ?? ''}'.trim(),
        completed: _string(json['status']).toLowerCase() == 'completed',
        scheduledAt: _dateOrNull(json['scheduledAt']),
        notes: _string(json['notes']),
        appointmentId: _nullableString(json['appointmentId']),
        visitId: _nullableString(json['visitId']),
      );
}

class TreatmentPlan extends DemoReadOnlyRecord {
  final String id;
  final String? doctorName;
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
    this.doctorName,
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

  factory TreatmentPlan.fromJson(Map<String, dynamic> json,
      {List<TreatmentSession> sessions = const []}) {
    final total = _int(json['totalSessions']);
    return TreatmentPlan(
      id: _string(json['id']),
      doctorName: _displayName(json['doctorName']),
      patientId: _string(json['patientId']),
      title: _string(json['name'] ?? json['title']),
      description: _string(json['diagnosis'] ?? json['description']),
      completedVisits: sessions.where((session) => session.completed).length,
      totalVisits: total == 0 ? sessions.length : total,
      doctorId: _nullableString(json['doctorId']),
      sessions: sessions,
    );
  }
}

class Followup extends DemoReadOnlyRecord {
  final String id;

  /// Explicit follow-up service; previous visit services are not a prescription.
  final String? serviceId;
  final String? doctorName;
  final String patientId;
  final String doctorId;
  final DateTime scheduledAt;
  final String note;

  const Followup({
    required this.id,
    this.serviceId,
    this.doctorName,
    required this.patientId,
    required this.doctorId,
    required this.scheduledAt,
    required this.note,
  });

  factory Followup.fromJson(Map<String, dynamic> json) => Followup(
        id: _string(json['id']),
        serviceId: _displayName(json['serviceId']),
        doctorName: _displayName(json['doctorName']),
        patientId: _string(json['patientId']),
        doctorId: _string(json['doctorId']),
        scheduledAt: _date(json['scheduledAt']),
        note: _string(json['reason'] ?? json['notes'] ?? json['note']),
      );
}

String _string(dynamic value) => value?.toString() ?? '';
String? _nullableString(dynamic value) {
  final result = _string(value);
  return result.isEmpty ? null : result;
}

int _int(dynamic value) => int.tryParse(_string(value)) ?? 0;
int? _intOrNull(dynamic value) => value == null ? null : _int(value);
List<dynamic> _list(dynamic value) => value is List ? value : const [];
List<String> _strings(dynamic value) =>
    _list(value).map(_string).where((value) => value.isNotEmpty).toList();
DateTime _date(dynamic value) =>
    _dateOrNull(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
DateTime? _dateOrNull(dynamic value) {
  if (value is Map && value['_seconds'] != null) {
    return DateTime.fromMillisecondsSinceEpoch(_int(value['_seconds']) * 1000);
  }
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
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

String? _displayName(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
