import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import 'record_status.dart';
import 'records_widgets.dart';

class PaymentReceiptScreen extends StatelessWidget {
  const PaymentReceiptScreen({required this.receipt, super.key});
  final Receipt receipt;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final appointments =
        data.appointments.where((a) => a.id == receipt.appointmentId);
    final patientIds = receipt.patientId.isNotEmpty
        ? {receipt.patientId}
        : <String>{
            ...appointments.map((a) => a.patientId),
            ...data.visits
                .where((v) => v.id == receipt.visitId)
                .map((v) => v.patientId),
          };
    final patients = data.patients
        .where((p) => patientIds.length == 1 && patientIds.contains(p.id));
    return RecordsPage(title: 'Phiếu thanh toán', children: [
      RecordCard(children: [
        RecordLine('Mã hóa đơn', receipt.id),
        RecordLine('Ngày lập', recordDate(receipt.issuedAt)),
        RecordLine(
            'Bệnh nhân', patients.isEmpty ? null : patients.first.fullName),
        const Divider(height: 28),
        const RecordHeading('Dịch vụ và đơn giá'),
        if (receipt.items.isEmpty) const Text(missingRecordInfo),
        for (final item in receipt.items)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(child: Text(item.name)),
                const SizedBox(width: 8),
                Text(formatVnd(item.price))
              ])),
        const Divider(height: 28),
        if (receipt.subtotal != null)
          RecordLine('Tạm tính', formatVnd(receipt.subtotal!)),
        if (receipt.discount != null)
          RecordLine('Giảm giá', formatVnd(receipt.discount!)),
        Text('Tổng tiền: ${formatVnd(receipt.amount)}',
            style: const TextStyle(
                color: recordsBlue, fontWeight: FontWeight.w600, fontSize: 18)),
        const SizedBox(height: 12),
        RecordLine('Hình thức', paymentMethodText(receipt.paymentMethod)),
        if (receipt.paymentStatus != null)
          RecordLine('Trạng thái', paymentStatusText(receipt.paymentStatus)),
        if (data.recordsAreDemoAndReadOnly)
          const Text('Phiếu minh họa · Chỉ xem thông tin đã ghi nhận',
              style: TextStyle(color: Color(0xFF666666))),
      ])
    ]);
  }
}
