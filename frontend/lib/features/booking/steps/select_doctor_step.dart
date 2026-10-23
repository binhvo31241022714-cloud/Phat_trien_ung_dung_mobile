import 'package:flutter/material.dart';
import '../../../data/models/doctor.dart';
import '../booking_controller.dart';

class SelectDoctorStep extends StatelessWidget {
  const SelectDoctorStep(
      {required this.controller, required this.onDetail, super.key});
  final BookingController controller;
  final ValueChanged<Doctor> onDetail;
  Widget indicator(bool selected) =>
      Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? const Color(0xFF247BF3) : Colors.grey);
  @override
  Widget build(BuildContext context) => Column(children: [
        Card(
            child: ListTile(
                onTap: () => controller.chooseDoctor(null),
                leading: const Icon(Icons.shuffle, color: Color(0xFF247BF3)),
                title: const Text('Để hệ thống chọn bác sĩ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Dành cho người chưa có bác sĩ ưu tiên'),
                trailing: indicator(
                    controller.doctorChosen && controller.doctorId == null))),
        for (final d in controller.data.doctors)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                  child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => controller.chooseDoctor(d.id),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(children: [
                        const CircleAvatar(
                            backgroundColor: Color(0xFFDFE8F6),
                            child: Icon(Icons.person_outline,
                                color: Color(0xFF247BF3))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(d.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(d.specialty,
                                  style:
                                      const TextStyle(color: Color(0xFF666666)))
                            ])),
                        indicator(controller.doctorChosen &&
                            controller.doctorId == d.id)
                      ]),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: () => onDetail(d),
                              child: const Text('Xem thông tin chi tiết ›',
                                  style: TextStyle(color: Colors.black)))),
                    ])),
              ))),
      ]);
}
