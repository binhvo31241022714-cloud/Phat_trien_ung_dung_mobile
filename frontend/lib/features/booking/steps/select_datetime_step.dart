import 'package:flutter/material.dart';

import '../../../data/models/availability_slot.dart';
import '../booking_controller.dart';

class SelectDatetimeStep extends StatelessWidget {
  const SelectDatetimeStep({
    required this.controller,
    super.key,
  });

  final BookingController controller;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = controller.now();
    final today = DateTime(now.year, now.month, now.day);

    final selectedDate = controller.date;
    final initialDate = selectedDate != null && !selectedDate.isBefore(today)
        ? selectedDate
        : today;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
    );

    if (date != null) {
      controller.chooseDate(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = controller.date;
    final selectedTime = controller.time;
    final slots = controller.availabilitySlots;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton(
              onPressed: controller.submitting || controller.created != null
                  ? null
                  : () => _pickDate(context),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? 'Chọn ngày khám'
                          : _formatDate(selectedDate),
                    ),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
            const Divider(height: 32),
            const Text(
              'Khung giờ khám còn trống',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (!controller.hasSelectedItems)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Vui lòng chọn ít nhất một dịch vụ hoặc combo trước.',
                  style: TextStyle(color: Color(0xFF666666)),
                ),
              )
            else if (selectedDate == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Chọn ngày khám để xem những khung giờ còn trống.',
                  style: TextStyle(color: Color(0xFF666666)),
                ),
              )
            else if (controller.availabilityLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Đang kiểm tra lịch khám...'),
                    ],
                  ),
                ),
              )
            else if (controller.availabilityError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 36,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.availabilityError!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: controller.submitting
                            ? null
                            : controller.loadAvailability,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            else if (slots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Ngày này chưa có khung giờ phù hợp. '
                  'Bạn hãy thử chọn ngày khác.',
                  style: TextStyle(color: Color(0xFF666666)),
                ),
              )
            else ...[
              const Text(
                'Chọn một khung giờ phù hợp với bạn.',
                style: TextStyle(color: Color(0xFF666666)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in slots)
                    _slotChip(
                      slot,
                      selected: selectedTime == slot.startTime &&
                          controller.doctorId == slot.doctorId,
                    ),
                ],
              ),
            ],
            if (selectedTime != null && controller.validTime) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Đã chọn: $selectedTime'
                  '${controller.doctorId != null ? '\nBác sĩ: ${_doctorNameForSelection(slots)}' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF245DA8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _doctorNameForSelection(List<AvailabilitySlot> slots) {
    for (final slot in slots) {
      if (slot.startTime == controller.time &&
          slot.doctorId == controller.doctorId) {
        return slot.doctorName.isNotEmpty ? slot.doctorName : 'Bác sĩ đã chọn';
      }
    }

    return 'Bác sĩ đã chọn';
  }

  Widget _slotChip(
    AvailabilitySlot slot, {
    required bool selected,
  }) {
    return ChoiceChip(
      selected: selected,
      onSelected: controller.submitting || controller.created != null
          ? null
          : (value) {
              if (value) {
                controller.chooseAvailabilitySlot(slot);
              }
            },
      label: SizedBox(
        width: 135,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${slot.startTime} – ${slot.endTime}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (slot.doctorName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                slot.doctorName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
