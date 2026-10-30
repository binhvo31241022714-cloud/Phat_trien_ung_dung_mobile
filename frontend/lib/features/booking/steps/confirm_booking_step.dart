import '../booking_doctor_name.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../booking_controller.dart';

class ConfirmBookingStep extends StatelessWidget {
  const ConfirmBookingStep({
    required this.controller,
    super.key,
  });

  final BookingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;

    // Tìm bệnh nhân an toàn trong dữ liệu mock.
    final localPatients =
        c.data.patients.where((patient) => patient.id == c.patientId).toList();

    // Tìm hồ sơ chính chủ và người thân từ API.
    final currentProfile = c.profile?.profile;

    final familyMembers = c.profile?.family
            .where((member) => member.id == c.patientId)
            .toList() ??
        [];

    final String patientName;

    if (currentProfile != null && currentProfile.id == c.patientId) {
      patientName = currentProfile.fullName.trim().isNotEmpty
          ? currentProfile.fullName
          : currentProfile.email;
    } else if (familyMembers.isNotEmpty) {
      patientName = familyMembers.first.fullName;
    } else if (localPatients.isNotEmpty) {
      patientName = localPatients.first.fullName;
    } else {
      patientName = 'Chưa xác định người khám';
    }

    // Lấy dịch vụ/combo từ cùng nguồn dữ liệu với BookingController.
    final selectedCombos = c.services
        .where(
          (service) => service.isCombo && service.id == c.comboId,
        )
        .toList();

    final includedServiceIds = selectedCombos.isEmpty
        ? <String>{}
        : selectedCombos.first.serviceIds.toSet();

    final selectedItems = c.services.where((service) {
      if (service.isCombo) {
        return service.id == c.comboId;
      }

      return c.serviceIds.contains(service.id) &&
          !includedServiceIds.contains(service.id);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Người khám
            Row(
              children: [
                const Text(
                  'Người khám',
                  style: TextStyle(
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    patientName,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            // Dịch vụ
            const Text(
              'Dịch vụ đã chọn',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            if (selectedItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Chưa có dịch vụ được chọn.',
                  style: TextStyle(
                    color: Color(0xFF666666),
                  ),
                ),
              )
            else
              for (final service in selectedItems)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(service.name),
                      ),
                      const SizedBox(width: 8),
                      Text(formatVnd(service.price)),
                    ],
                  ),
                ),

            const Divider(height: 24),

            // Bác sĩ, ngày và giờ
            BookingDoctorName(controller: c, doctorId: c.doctorId),
            const SizedBox(height: 12),

            Text(
              'Ngày khám: ${c.date == null ? "Chưa chọn" : formatVietnameseDate(c.date!)}',
            ),
            const SizedBox(height: 12),

            Text('Giờ khám: ${c.time ?? "Chưa chọn"}'),
            const SizedBox(height: 16),

            // Voucher
            const Text(
              'Mã ưu đãi',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('booking-voucher-input'),
                    initialValue: c.voucher,
                    onChanged: (value) {
                      c.voucher = value;
                    },
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enabled: !c.voucherLoading && !c.submitting,
                    decoration: const InputDecoration(
                      hintText: 'Nhập mã, ví dụ: DENTAL10',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: c.voucherLoading || c.submitting
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();

                          // Gọi API xác thực voucher qua controller.
                          await c.applyVoucher(c.voucher);
                        },
                  child: c.voucherLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          c.appliedVoucher == null ? 'Áp dụng' : 'Áp dụng lại',
                        ),
                ),
              ],
            ),

            if (c.voucherError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  c.voucherError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              )
            else if (c.appliedVoucher != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đã áp dụng mã ${c.appliedVoucher}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: c.submitting ? null : c.removeVoucher,
                      child: const Text('Gỡ mã'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Ghi chú
            const Text(
              'Ghi chú cho phòng khám',
              style: TextStyle(
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),

            TextFormField(
              key: const ValueKey('booking-note-input'),
              initialValue: c.note,
              onChanged: (value) {
                c.note = value;
              },
              minLines: 2,
              maxLines: 5,
              enabled: !c.submitting,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Tôi thường bị ê buốt răng...',
                border: OutlineInputBorder(),
              ),
            ),

            const Divider(height: 32),

            if (c.quoteLoading) const Text('Đang tải giá…'),
            if (c.quoteError != null) ...[
              Text(c.quoteError!),
              TextButton(
                  onPressed: c.quoteLoading ? null : c.refreshQuote,
                  child: const Text('Thử lại báo giá')),
            ],
            // Tạm tính
            Row(
              children: [
                const Expanded(
                  child: Text('Tạm tính'),
                ),
                Text(c.quoteReady ? formatVnd(c.subtotal) : 'Chưa có giá'),
              ],
            ),

            // Chỉ hiển thị giảm giá khi backend trả về số tiền giảm.
            if (c.discount > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text('Giảm giá'),
                  ),
                  Text(
                    '-${formatVnd(c.discount)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Tổng tiền sau giảm giá
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tổng cộng',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  c.quoteReady ? formatVnd(c.total) : 'Chưa có giá',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF247BF3),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
