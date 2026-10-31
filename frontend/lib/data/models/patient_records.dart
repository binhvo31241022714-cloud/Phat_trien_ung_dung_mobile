abstract class DemoReadOnlyRecord {
  const DemoReadOnlyRecord();

  bool get isDemo => true;
  bool get isReadOnly => true;
}

class Visit extends DemoReadOnlyRecord {
  @override
  final bool isDemo;
  final String id;
  final String patientId;
  final DateTime? visitedAt;
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

  /// Giá trị gốc từ backend ("completed"...); null khi dữ liệu không có.
  final String? status;

  const Visit({
    this.isDemo = true,
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
    this.status,
  });

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        isDemo: json['isDemo'] == true,
        id: _string(json['id']),
        patientId: _string(json['patientId']),
        visitedAt: _dateOrNull(
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
        status: _nullableString(json['status']),
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
  final DateTime? issuedAt;
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
        issuedAt: _dateOrNull(json['issuedAt']),
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
  final String? appointmentId;
  final String? visitId;
  final DateTime? issuedAt;
  final int amount;
  final String paymentMethod;
  final List<ReceiptItem> items;
  final int? subtotal;
  final int? discount;
  final String? paymentStatus;
  final String patientId;

  const Receipt({
    required this.id,
    this.appointmentId,
    this.visitId,
    required this.issuedAt,
    required this.amount,
    required this.paymentMethod,
    this.items = const [],
    this.subtotal,
    this.discount,
    this.paymentStatus,
    this.patientId = '',
  });

  bool belongsToVisit(Visit visit) {
    if (patientId.isNotEmpty && patientId != visit.patientId) return false;
    if (visitId != null) {
      return visitId == visit.id &&
          (appointmentId == null || appointmentId == visit.appointmentId);
    }
    return appointmentId != null && appointmentId == visit.appointmentId;
  }

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        id: _string(json['id']),
        appointmentId: _id(json['appointmentId']),
        visitId: _id(json['visitId']),
        issuedAt: _dateOrNull(json['issuedAt']),
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
  final String? status;
  const TreatmentSession(
      {this.id = '',
      required this.title,
      required this.completed,
      this.scheduledAt,
      this.notes = '',
      this.appointmentId,
      this.visitId,
      this.status});

  factory TreatmentSession.fromJson(Map<String, dynamic> json) =>
      TreatmentSession(
        id: _string(json['id']),
        title: 'Buổi ${json['sessionNumber'] ?? ''}'.trim(),
        completed: _string(json['status']).toLowerCase() == 'completed',
        scheduledAt: _dateOrNull(json['scheduledAt']),
        notes: _string(json['notes']),
        appointmentId: _nullableString(json['appointmentId']),
        visitId: _nullableString(json['visitId']),
        status: _nullableString(json['status']),
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
  final String? status;
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
    this.status,
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
      status: _nullableString(json['status']),
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
  final DateTime? scheduledAt;
  final String note;

  /// "suggested" (mới), "scheduled" (dữ liệu cũ), "booked"...
  final String? status;

  /// Lịch hẹn đã đặt từ đề xuất này (A08), có khi status là "booked".
  final String? appointmentId;

  const Followup({
    required this.id,
    this.serviceId,
    this.doctorName,
    required this.patientId,
    required this.doctorId,
    required this.scheduledAt,
    required this.note,
    this.status,
    this.appointmentId,
  });

  /// Còn đặt lịch được: chưa có trạng thái (dữ liệu mẫu), "suggested" hoặc "scheduled" cũ.
  bool get isOpen {
    final value = status?.trim().toLowerCase();
    return value == null || value.isEmpty || value == 'suggested' || value == 'scheduled';
  }

  factory Followup.fromJson(Map<String, dynamic> json) => Followup(
        id: _string(json['id']),
        serviceId: _displayName(json['serviceId']),
        doctorName: _displayName(json['doctorName']),
        patientId: _string(json['patientId']),
        doctorId: _string(json['doctorId']),
        scheduledAt: _dateOrNull(json['scheduledAt']),
        note: _string(json['reason'] ?? json['notes'] ?? json['note']),
        status: _nullableString(json['status']),
        appointmentId: _nullableString(json['appointmentId']),
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
String? _id(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

/// Hồ sơ nha khoa không có ngày trước năm 2000: giá trị như vậy (thường là
/// timestamp 0 = 01/01/1970) được coi là thiếu ngày (A16).
DateTime? _dateOrNull(dynamic value) {
  final date = _parseDate(value);
  return date == null || date.toUtc().year < 2000 ? null : date;
}

DateTime? _parseDate(dynamic value) {
  try {
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      final nanos = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
      if (seconds is! num ||
          !seconds.isFinite ||
          seconds != seconds.round() ||
          nanos is! num ||
          !nanos.isFinite ||
          nanos < 0 ||
          nanos >= 1000000000) {
        return null;
      }
      return DateTime.fromMicrosecondsSinceEpoch(
          (seconds * 1000000 + nanos / 1000).round(),
          isUtc: true);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) {
      final match =
          RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|T)').firstMatch(value);
      if (match == null) return null;
      final time = RegExp(r'T(\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(value);
      if (value.contains('T') &&
          (time == null ||
              int.parse(time[1]!) > 23 ||
              int.parse(time[2]!) > 59 ||
              int.parse(time[3] ?? '0') > 59)) {
        return null;
      }
      final parsed = DateTime.tryParse(value);
      final day = DateTime.utc(
          int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
      if (day.year != int.parse(match[1]!) ||
          day.month != int.parse(match[2]!) ||
          day.day != int.parse(match[3]!)) {
        return null;
      }
      return parsed;
    }
  } catch (_) {/* Malformed or out of range: no clinical date supplied. */}
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
