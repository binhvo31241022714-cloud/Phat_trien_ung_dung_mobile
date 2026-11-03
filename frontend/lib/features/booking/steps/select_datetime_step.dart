import '../../../core/utils/clinic_time.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/network_image_or_icon.dart';
import '../../../data/models/availability_slot.dart';
import '../../../data/models/doctor.dart';
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
    final now = controller.apiMode
        ? clinicWallTime(controller.now())
        : controller.now();
    final today = DateTime(now.year, now.month, now.day);

    final selectedDate = controller.date;
    final initialDate = selectedDate != null && !selectedDate.isBefore(today)
        ? selectedDate
        : today;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
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

    final selectedDoctor = _selectedDoctor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedDoctor != null) ...[
              _doctorProfile(selectedDoctor),
              const SizedBox(height: 14),
            ],
            OutlinedButton(
              onPressed: controller.submitting || controller.created != null
                  ? null
                  : () => _pickDate(context),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? 'Chọn ngày khám'
                          : _formatDate(selectedDate),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 20),
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C000675),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
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

  Doctor? _selectedDoctor() {
    final id = controller.doctorId;
    if (id == null) return null;
    final doctors = controller.catalog == null
        ? controller.data.doctors
        : controller.catalog!.doctors;
    for (final doctor in doctors) {
      if (doctor.id == id) return doctor;
    }
    return null;
  }

  Widget _doctorProfile(Doctor doctor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.glassPurpleStrong, Color(0xB8FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000675),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 50,
              height: 50,
              color: const Color(0x66D9CCFF),
              child: NetworkImageOrIcon(
                url: doctor.avatarUrl,
                icon: Icons.person_rounded,
                iconSize: 28,
                color: AppColors.primary,
                width: 50,
                height: 50,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bác sĩ đã chọn',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(doctor.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(doctor.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 20),
        ],
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
      key: ValueKey('slot-${slot.date}-${slot.doctorId}-${slot.startTime}'),
      label: Text(slot.startTime,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      elevation: selected ? 1.5 : 0.5,
      shadowColor: const Color(0x14000675),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}
