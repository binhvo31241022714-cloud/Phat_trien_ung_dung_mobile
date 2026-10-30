import 'package:flutter/material.dart';
import 'booking_controller.dart';

/// Booking views share the same API-only name resolution and reactive catalog.
class BookingDoctorName extends StatelessWidget {
  const BookingDoctorName(
      {required this.controller, this.doctorId, this.payloadName, super.key});
  final BookingController controller;
  final String? doctorId;
  final String? payloadName;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller.catalog ?? controller,
        builder: (context, _) {
          final c = controller;
          final id = doctorId;
          String? name = payloadName?.trim();
          if (name?.isEmpty == true) name = null;
          if (name == null && c.apiMode) {
            final slots = c.availabilitySlots.where((s) =>
                s.doctorId == id &&
                s.startTime == c.time &&
                s.doctorName.trim().isNotEmpty);
            if (slots.isNotEmpty) name = slots.first.doctorName.trim();
          }
          final catalog = c.catalog;
          if (name == null) {
            final doctors = c.apiMode
                ? catalog?.doctors
                : [...?catalog?.doctors, ...c.data.doctors];
            final matches = doctors?.where((d) =>
                d.id == id &&
                d.fullName.trim().isNotEmpty &&
                (!c.apiMode || d.fromApi));
            if (matches?.isNotEmpty == true) {
              name = matches!.first.fullName.trim();
            }
          }
          name ??= id == null || id.trim().isEmpty
              ? 'Chờ phân công'
              : c.apiMode &&
                      catalog != null &&
                      catalog.error == null &&
                      (!catalog.loaded || catalog.loading)
                  ? 'Đang tải bác sĩ…'
                  : 'Chưa có thông tin bác sĩ';
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bác sĩ: $name'),
                if (c.apiMode && catalog?.error != null)
                  Row(children: [
                    Expanded(child: Text(catalog!.error!)),
                    TextButton(
                        onPressed: catalog.loading ? null : catalog.load,
                        child: const Text('Thử lại danh mục')),
                  ]),
              ]);
        },
      );
}
