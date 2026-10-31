import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../data/models/patient_records.dart';
import 'records_widgets.dart';

/// Nhãn trạng thái hồ sơ theo đúng giá trị backend trả về (A21).
/// Không có trạng thái thì nói rõ là chưa cập nhật, không đoán.
typedef RecordStatusLabel = ({String label, Color color});

const _missing = (label: 'Trạng thái chưa cập nhật', color: Colors.grey);
const _unknown = (label: 'Không xác định', color: Colors.blueGrey);

/// Dữ liệu mẫu (mock) không có trường status; chỉ ở chế độ này mới suy ra.
bool get _mock => AppConfig.current.dataSource == DataSource.mock;

String? _normalized(String? status) {
  final value = status?.trim().toLowerCase();
  return value == null || value.isEmpty ? null : value;
}

RecordStatusLabel visitStatusLabel(Visit visit) {
  final status = _normalized(visit.status) ?? (_mock ? 'completed' : null);
  return switch (status) {
    null => _missing,
    'completed' => (label: 'Đã hoàn thành', color: Colors.green),
    'pending' || 'in_progress' => (label: 'Đang xử lý', color: Colors.deepOrange),
    'cancelled' => (label: 'Đã hủy', color: Colors.grey),
    _ => _unknown,
  };
}

bool visitIsCompleted(Visit visit) =>
    (_normalized(visit.status) ?? (_mock ? 'completed' : null)) ==
    'completed';

RecordStatusLabel treatmentStatusLabel(TreatmentPlan plan) {
  final status = _normalized(plan.status) ??
      (_mock
          ? plan.totalVisits > 0 && plan.completedVisits >= plan.totalVisits
              ? 'completed'
              : 'in_progress'
          : null);
  return switch (status) {
    null => _missing,
    'planned' => (label: 'Dự kiến', color: recordsBlue),
    'in_progress' => (label: 'Đang điều trị', color: Colors.deepOrange),
    'completed' => (label: 'Đã hoàn thành', color: Colors.green),
    'cancelled' => (label: 'Đã hủy', color: Colors.grey),
    _ => _unknown,
  };
}

RecordStatusLabel sessionStatusLabel(TreatmentSession session) {
  if (session.completed) {
    return (label: 'Đã hoàn thành', color: Colors.green);
  }
  return switch (_normalized(session.status)) {
    'planned' || 'pending' || null => (label: 'Dự kiến', color: Colors.grey),
    'cancelled' => (label: 'Đã hủy', color: Colors.grey),
    _ => _unknown,
  };
}

/// "scheduled" là giá trị cũ trên Firestore, hiểu như "suggested".
RecordStatusLabel? followupStatusLabel(Followup followup) =>
    switch (_normalized(followup.status)) {
      null => null,
      'suggested' || 'scheduled' => (label: 'Đã đề xuất', color: Colors.deepOrange),
      'booked' => (label: 'Đã đặt lịch', color: recordsBlue),
      'completed' => (label: 'Đã tái khám', color: Colors.green),
      'cancelled' => (label: 'Đã hủy', color: Colors.grey),
      _ => _unknown,
    };

String? paymentStatusText(String? status) => switch (_normalized(status)) {
      null => null,
      'paid' => 'Đã thanh toán',
      'unpaid' || 'pending' => 'Chưa thanh toán',
      'refunded' => 'Đã hoàn tiền',
      _ => status,
    };

String? paymentMethodText(String method) => switch (_normalized(method)) {
      null => null,
      'cash' => 'Tiền mặt',
      'bank_transfer' || 'transfer' => 'Chuyển khoản',
      'card' => 'Thẻ',
      'e_wallet' => 'Ví điện tử',
      _ => method,
    };

Widget recordStatusBadge(RecordStatusLabel status) =>
    RecordBadge(status.label, color: status.color);
