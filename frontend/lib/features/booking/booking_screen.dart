import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/patient_navigation.dart';
import '../../data/providers/patient_data_provider.dart';
import '../services/service_detail_screen.dart';
import '../doctors/doctor_detail_screen.dart';
import 'booking_controller.dart';
import 'booking_success_screen.dart';
import 'steps/select_services_step.dart';
import 'steps/select_doctor_step.dart';
import 'steps/select_datetime_step.dart';
import 'steps/confirm_booking_step.dart';
import 'widgets/booking_stepper.dart';
import 'widgets/booking_price_summary.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  BookingController? _controller;
  final _scrollController = ScrollController();
  int _lastStep = 0;
  Widget? detail;
  String? detailTitle;
  BookingController get c => _controller!;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = context.watch<PatientDataProvider>();
    _controller ??= BookingController(data)..addListener(_changed);
    final requestedPatient =
        c.submitting ? null : data.takeBookingPatientRequest();
    if (!c.submitting && !data.patients.any((p) => p.id == c.patientId)) {
      c.patientId = data.primaryPatient.id;
    }
    if (requestedPatient != null) {
      // A follow-up opens a draft for the requested patient; it never submits it.
      if (c.created != null) {
        c.removeListener(_changed);
        c.dispose();
        _controller = BookingController(data)..addListener(_changed);
      }
      c.patientId = requestedPatient;
    }
  }

  void _changed() {
    if (mounted) {
      if (!c.submitting && !c.data.patients.any((p) => p.id == c.patientId)) {
        c.patientId = c.data.primaryPatient.id;
      }
      if (_lastStep != c.step) {
        _lastStep = c.step;
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void openDetail(String title, Widget child) => setState(() {
        detail = child;
        detailTitle = title;
      });
  void leave(int tab) {
    c.data
        .focusAppointmentsFor(c.created!.patientId, showAppointments: tab == 2);
    final data = c.data;
    c.removeListener(_changed);
    c.dispose();
    setState(() {
      _controller = BookingController(data)..addListener(_changed);
      detail = null;
    });
    PatientNavigation.selectTab(context, tab);
  }

  Future<void> next() async {
    if (c.submitting || c.created != null) return;
    if (c.step != 3) {
      c.next();
      return;
    }
    try {
      final result = await c.submit();
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Vui lòng kiểm tra lựa chọn và chọn giờ khám trong tương lai.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa thể tạo lịch. Vui lòng thử lại.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final success = c.created != null;
    final titles = [
      'Chọn dịch vụ nha khoa',
      'Chọn bác sĩ',
      'Chọn ngày và giờ khám',
      'Kiểm tra thông tin đặt lịch'
    ];
    return Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context)
              .textTheme
              .apply(bodyColor: Colors.black, displayColor: Colors.black),
          cardTheme: CardThemeData(
              color: const Color(0xFFF7F7F7),
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFD8D8D8)))),
        ),
        child: PopScope(
            canPop: MainShellScope.maybeOf(context) != null &&
                MainShellScope.maybeOf(context)!.selectedIndex != 1,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop ||
                  (MainShellScope.maybeOf(context) != null &&
                      MainShellScope.maybeOf(context)!.selectedIndex != 1)) {
                return;
              }
              if (detail != null) {
                setState(() => detail = null);
              } else if (success) {
                leave(0);
              } else if (c.step > 0) {
                c.back();
              } else {
                PatientNavigation.selectTab(context, 0);
              }
            },
            child: ColoredBox(
                color: const Color(0xFFF1F5FB),
                child: SafeArea(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(children: [
                            if (detail != null || success)
                              IconButton(
                                  onPressed: () {
                                    if (success) {
                                      leave(0);
                                    } else {
                                      setState(() => detail = null);
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_back, size: 20)),
                            Expanded(
                                child: Text(
                                    detail != null
                                        ? detailTitle!
                                        : success
                                            ? 'Đặt lịch thành công'
                                            : 'Đặt lịch khám',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold))),
                          ])),
                      Expanded(
                          child: detail ??
                              (success
                                  ? BookingSuccessScreen(
                                      controller: c,
                                      onRecords: () => leave(2),
                                      onHome: () => leave(0))
                                  : SingleChildScrollView(
                                      controller: _scrollController,
                                      key: const PageStorageKey(
                                          'booking-scroll'),
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 16),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Card(
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Row(children: [
                                                            Icon(
                                                                Icons
                                                                    .person_outline,
                                                                size: 20,
                                                                color: Color(
                                                                    0xFF247BF3)),
                                                            SizedBox(width: 8),
                                                            Expanded(
                                                                child: Text(
                                                                    'Người được khám',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            18,
                                                                        fontWeight:
                                                                            FontWeight.w600)))
                                                          ]),
                                                          const SizedBox(
                                                              height: 8),
                                                          DropdownButtonFormField<
                                                                  String>(
                                                              key: ValueKey(
                                                                  c.patientId),
                                                              initialValue: data
                                                                      .patients
                                                                      .any((p) =>
                                                                          p.id ==
                                                                          c
                                                                              .patientId)
                                                                  ? c.patientId
                                                                  : data
                                                                      .selectedPatientId,
                                                              isExpanded: true,
                                                              decoration: InputDecoration(
                                                                  contentPadding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          16,
                                                                      vertical:
                                                                          8),
                                                                  border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              30))),
                                                              items: [
                                                                for (final p
                                                                    in data
                                                                        .patients)
                                                                  DropdownMenuItem(
                                                                      value:
                                                                          p.id,
                                                                      child: Text(
                                                                          '${p.fullName} (${p.isPrimary ? "Bản thân" : p.relationship})',
                                                                          overflow:
                                                                              TextOverflow.ellipsis))
                                                              ],
                                                              onChanged:
                                                                  c.submitting
                                                                      ? null
                                                                      : (v) {
                                                                          if (v !=
                                                                              null) {
                                                                            c.selectPatient(v);
                                                                          }
                                                                        }),
                                                        ]))),
                                            const SizedBox(height: 16),
                                            BookingStepper(step: c.step),
                                            const SizedBox(height: 16),
                                            Text(titles[c.step],
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(height: 14),
                                            switch (c.step) {
                                              0 => SelectServicesStep(
                                                  controller: c,
                                                  onDetail: (s) => openDetail(
                                                      'Chi tiết dịch vụ',
                                                      ServiceDetailScreen(
                                                          service: s))),
                                              1 => SelectDoctorStep(
                                                  controller: c,
                                                  onDetail: (d) => openDetail(
                                                      'Chi tiết bác sĩ',
                                                      DoctorDetailScreen(
                                                          doctor: d))),
                                              2 => SelectDatetimeStep(
                                                  controller: c),
                                              _ => ConfirmBookingStep(
                                                  controller: c),
                                            },
                                            const SizedBox(height: 12),
                                            BookingPriceSummary(
                                                controller: c, onNext: next),
                                          ]),
                                    ))),
                    ])))));
  }
}
