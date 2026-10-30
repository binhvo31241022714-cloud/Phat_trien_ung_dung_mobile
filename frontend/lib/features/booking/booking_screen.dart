import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/patient_navigation.dart';
import '../../core/config/app_config.dart';
import '../../data/api_client.dart';
import '../../data/providers/patient_data_provider.dart';
import '../records/appointment_api_status.dart';
import '../../providers/appointments_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/profile_provider.dart';
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
  final String? initialDoctorId;
  final List<String>? initialServiceIds;
  final bool restrictToServiceIds;
  final String? initialComboId;
  final String? initialPatientId;

  const BookingScreen({
    super.key,
    this.initialDoctorId,
    this.initialServiceIds,
    this.restrictToServiceIds = false,
    this.initialComboId,
    this.initialPatientId,
  });

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
    final catalog = context.read<CatalogProvider>();
    final profile = context.read<ProfileProvider>();
    final apiMode = AppConfig.current.dataSource == DataSource.api;

    _controller ??= BookingController(
      data,
      catalog: catalog,
      profile: profile,
      initialDoctorId: widget.initialDoctorId,
      initialServiceIds: widget.initialServiceIds,
      restrictToServiceIds: widget.restrictToServiceIds,
      initialComboId: widget.initialComboId,
      initialPatientId: widget.initialPatientId,
    )..addListener(_changed);

    // Tải dịch vụ, combo và bác sĩ.
    if (!catalog.loaded && !catalog.loading && catalog.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            catalog.loaded ||
            catalog.loading ||
            catalog.error != null) {
          return;
        }

        catalog.load();
      });
    }

    // Chỉ tải hồ sơ tài khoản thật khi dùng backend API.
    if (apiMode &&
        profile.profile == null &&
        !profile.profileLoading &&
        profile.profileError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            profile.profile != null ||
            profile.profileLoading ||
            profile.profileError != null) {
          return;
        }

        profile.ensureLoaded();
      });
    }

    // Tải danh sách người thân.
    if (!profile.familyLoaded &&
        !profile.familyLoading &&
        profile.familyError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            profile.familyLoaded ||
            profile.familyLoading ||
            profile.familyError != null) {
          return;
        }

        profile.loadFamily();
      });
    }

    // Áp dụng yêu cầu mở đặt lịch từ màn hình khác.
    final pending = PatientNavigation.pendingBookingRequest;

    if (pending != null && !c.locked) {
      // A follow-up starts a fresh draft after a previous successful booking.
      if (pending.replaceSelection && c.created != null) {
        c.removeListener(_changed);
        c.dispose();
        _controller =
            BookingController(data, catalog: catalog, profile: profile)
              ..addListener(_changed);
      }
      PatientNavigation.pendingBookingRequest = null;

      c.applyInitialValues(
        replaceSelection: pending.replaceSelection,
        suggestedDate: pending.suggestedDate,
        doctorId: pending.doctorId,
        serviceIds: pending.serviceIds,
        restrictToServiceIds: pending.restrictToServiceIds,
        comboId: pending.comboId,
        patientId: pending.patientId,
      );
    }

    final requestedPatient =
        c.locked ? null : data.takeBookingPatientRequest();

    if (requestedPatient != null) {
      if (c.created != null) {
        c.removeListener(_changed);
        c.dispose();

        _controller = BookingController(
          data,
          catalog: catalog,
          profile: profile,
        )..addListener(_changed);
      }

      c.selectPatient(requestedPatient);
    }
  }

  void _changed() {
    if (!mounted) return;

    // Không tự đổi patientId về hồ sơ mẫu.
    // Đồng bộ ID API được xử lý khi hồ sơ tài khoản đã tải xong.

    if (_lastStep != c.step) {
      _lastStep = c.step;

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void openDetail(String title, Widget child) {
    setState(() {
      detail = child;
      detailTitle = title;
    });
  }

  void leave(int tab, {String? appointmentId}) {
    if (c.created == null) return;

    c.data.focusAppointmentsFor(
      c.created!.patientId,
      showAppointments: tab == 2,
      appointmentId: appointmentId,
    );

    final data = c.data;
    final catalog = context.read<CatalogProvider>();
    final profile = context.read<ProfileProvider>();

    c.removeListener(_changed);
    c.dispose();

    setState(() {
      _controller = BookingController(
        data,
        catalog: catalog,
        profile: profile,
      )..addListener(_changed);

      detail = null;
      detailTitle = null;
      _lastStep = 0;
    });

    PatientNavigation.selectTab(context, tab);
  }

  Future<void> next() async {
    if (c.submitting || c.created != null) return;

    if (c.step != 3) {
      c.next();
      return;
    }

    // Khi dùng API, chỉ cho gửi hồ sơ chính chủ hoặc người thân
    // nằm trong danh sách của tài khoản đang đăng nhập.
    if (AppConfig.current.dataSource == DataSource.api) {
      final profile = context.read<ProfileProvider>();
      final accountId = profile.profile?.id.trim();

      if (accountId == null || accountId.isEmpty) {
        final message = profile.profileError ??
            'Chưa tải được hồ sơ tài khoản. Vui lòng thử lại.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }

      final validPatientIds = <String>{
        accountId,
        ...profile.family
            .map((member) => member.id.trim())
            .where((id) => id.isNotEmpty),
      };

      if (!validPatientIds.contains(c.patientId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Người khám chưa được xác minh. Vui lòng chọn lại hồ sơ trong danh sách.',
            ),
          ),
        );
        return;
      }
    }

    try {
      final appointmentsProvider = context.read<AppointmentsProvider>();

      final result = await c.submit(
        appointmentsProvider: appointmentsProvider,
      );

      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vui lòng kiểm tra lựa chọn và chọn giờ khám trong tương lai.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Nếu controller đã có lịch được tạo, không báo thất bại
      // chỉ vì một bước cập nhật dữ liệu cục bộ bị lỗi.
      if (c.created != null) {
        return;
      }

      final message = e is ApiException
          ? e.message
          : 'Chưa thể tạo lịch. Vui lòng thử lại.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          // Mất kết nối: "Thử lại" gửi lại với đúng Idempotency-Key cũ.
          action: c.awaitingRetry
              ? SnackBarAction(label: 'Thử lại', onPressed: next)
              : null,
        ),
      );
    }
  }

  /// "Chọn lại" sau lỗi mạng: tải lại lịch của tài khoản. Đã có lịch khớp lần
  /// gửi (cùng người khám, ngày, giờ) thì coi như đặt thành công và mở lịch đó;
  /// chưa có thì mở khóa, lần gửi sau dùng key mới.
  Future<void> reselect() async {
    final sent = c.lastSent;
    if (!c.awaitingRetry || c.submitting || sent == null) return;
    final controller = c;
    final appointments = context.read<AppointmentsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await reloadAppointments(context);
    if (!mounted || !identical(controller, c) || !c.awaitingRetry) return;
    if (appointments.error != null) {
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Chưa kiểm tra được lịch đã đặt: ${appointments.error} Vui lòng thử lại.')));
      return;
    }
    final match = c.matchLastSent(appointments.appointments);
    if (match == null) {
      c.unlockForNewRequest();
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Chưa có lịch nào được tạo. Bạn có thể sửa lựa chọn và gửi lại.')));
      return;
    }
    c.adoptCreated(match);
    messenger.showSnackBar(const SnackBar(
        content: Text('Lịch hẹn đã được đặt thành công trước đó.')));
    leave(2, appointmentId: match.id);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final profile = context.watch<ProfileProvider>();
    final success = c.created != null;
    final apiMode = AppConfig.current.dataSource == DataSource.api;

    final titles = [
      'Chọn dịch vụ nha khoa',
      'Chọn bác sĩ',
      'Chọn ngày và giờ khám',
      'Kiểm tra thông tin đặt lịch',
    ];

    final loadedProfile = profile.profile;
    final accountProfile =
        loadedProfile != null && loadedProfile.id.trim().isNotEmpty
            ? loadedProfile
            : null;

    // API mode chỉ sử dụng dữ liệu người khám từ API.
    // Mock mode tiếp tục sử dụng PatientDataProvider.
    final useApiPatients = apiMode && accountProfile != null;

    final patientItems = <DropdownMenuItem<String>>[];
    final patientIds = <String>{};

    if (useApiPatients) {
      final account = accountProfile;

      // Chính chủ: ID phải là UID tài khoản từ API.
      if (patientIds.add(account.id)) {
        final displayName = account.fullName.trim().isNotEmpty
            ? account.fullName
            : account.email;

        patientItems.add(
          DropdownMenuItem<String>(
            value: account.id,
            child: Text(
              '$displayName (Bản thân)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }

      // Người thân: dùng ID tài liệu thật từ /api/family-members.
      for (final member in profile.family) {
        final memberId = member.id.trim();

        if (memberId.isEmpty || !patientIds.add(memberId)) {
          continue;
        }

        final relationship = member.relationship.trim().isEmpty
            ? 'Người thân'
            : member.relationship;

        patientItems.add(
          DropdownMenuItem<String>(
            value: memberId,
            child: Text(
              '${member.fullName} ($relationship)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } else if (!apiMode) {
      // Giữ nguyên dữ liệu mock cho widget test và chế độ mock.
      for (final patient in data.patients) {
        if (patient.id.trim().isEmpty || !patientIds.add(patient.id)) {
          continue;
        }

        patientItems.add(
          DropdownMenuItem<String>(
            value: patient.id,
            child: Text(
              '${patient.fullName} '
              '(${patient.isPrimary ? "Bản thân" : patient.relationship})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    String? selectedPatientId;

    if (patientIds.contains(c.patientId)) {
      selectedPatientId = c.patientId;
    } else if (useApiPatients) {
      selectedPatientId = accountProfile.id;
    } else if (!apiMode && patientIds.contains(data.selectedPatientId)) {
      selectedPatientId = data.selectedPatientId;
    } else if (!apiMode && patientIds.contains(data.primaryPatient.id)) {
      selectedPatientId = data.primaryPatient.id;
    }

    // Đồng bộ ID mẫu sang UID thật.
    // Nếu ID chưa được nhận diện nhưng danh sách người thân còn tải,
    // đợi tải xong trước khi quyết định có cần đổi về chính chủ không.
    final currentController = c;
    final isCurrentIdMock = data.patients.any(
      (patient) => patient.id == c.patientId,
    );
    final familyLoadResolved =
        profile.familyLoaded || profile.familyError != null;

    if (useApiPatients &&
        !patientIds.contains(c.patientId) &&
        (isCurrentIdMock || familyLoadResolved) &&
        !c.submitting &&
        c.created == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !identical(_controller, currentController) ||
            currentController.submitting ||
            currentController.created != null) {
          return;
        }

        final latestProfile = context.read<ProfileProvider>();
        final latestAccountId = latestProfile.profile?.id.trim();

        if (latestAccountId == null || latestAccountId.isEmpty) {
          return;
        }

        final validIds = <String>{
          latestAccountId,
          ...latestProfile.family
              .map((member) => member.id.trim())
              .where((id) => id.isNotEmpty),
        };

        // Nếu ID vừa được xác nhận là người thân hợp lệ, giữ nguyên.
        if (validIds.contains(currentController.patientId)) {
          return;
        }

        final stillMockId = data.patients.any(
          (patient) => patient.id == currentController.patientId,
        );
        final latestFamilyResolved =
            latestProfile.familyLoaded || latestProfile.familyError != null;

        if (stillMockId || latestFamilyResolved) {
          currentController.selectPatient(latestAccountId);
        }
      });
    }

    final shell = MainShellScope.maybeOf(context);
    final canPop = shell != null && shell.selectedIndex != 1;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
        cardTheme: CardThemeData(
          color: const Color(0xFFF7F7F7),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFFD8D8D8),
            ),
          ),
        ),
      ),
      child: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          final currentShell = MainShellScope.maybeOf(context);

          if (currentShell != null && currentShell.selectedIndex != 1) {
            return;
          }

          if (detail != null) {
            setState(() {
              detail = null;
              detailTitle = null;
            });
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
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    12,
                  ),
                  child: Row(
                    children: [
                      if (detail != null || success)
                        IconButton(
                          onPressed: () {
                            if (success) {
                              leave(0);
                            } else {
                              setState(() {
                                detail = null;
                                detailTitle = null;
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 20,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          detail != null
                              ? detailTitle ?? ''
                              : success
                                  ? 'Đặt lịch thành công'
                                  : 'Đặt lịch khám',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: detail ??
                      (success
                          ? BookingSuccessScreen(
                              controller: c,
                              onRecords: () => leave(2),
                              onHome: () => leave(0),
                            )
                          : SingleChildScrollView(
                              controller: _scrollController,
                              key: const PageStorageKey(
                                'booking-scroll',
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(
                                                Icons.person_outline,
                                                size: 20,
                                                color: Color(
                                                  0xFF247BF3,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Người được khám',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            key: ValueKey(
                                              '${c.patientId}-${patientItems.length}',
                                            ),
                                            initialValue: patientIds.contains(
                                              selectedPatientId,
                                            )
                                                ? selectedPatientId
                                                : null,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                            ),
                                            items: patientItems,
                                            onChanged: c.locked
                                                ? null
                                                : (value) {
                                                    if (value != null) {
                                                      c.selectPatient(
                                                        value,
                                                      );
                                                    }
                                                  },
                                          ),
                                          if (apiMode && profile.profileLoading)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                'Đang tải hồ sơ tài khoản...',
                                                style: TextStyle(
                                                  color: Color(
                                                    0xFF666666,
                                                  ),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          if (apiMode &&
                                              profile.profileError != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                'Không tải được hồ sơ tài khoản: ${profile.profileError}',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          if (useApiPatients &&
                                              !profile.familyLoaded &&
                                              profile.familyLoading)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                'Đang tải danh sách người thân...',
                                                style: TextStyle(
                                                  color: Color(
                                                    0xFF666666,
                                                  ),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          if (apiMode &&
                                              profile.familyError != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                'Không tải được danh sách người thân: ${profile.familyError}',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  BookingStepper(step: c.step),
                                  const SizedBox(height: 16),
                                  Text(
                                    titles[c.step],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  switch (c.step) {
                                    0 => SelectServicesStep(
                                        controller: c,
                                        onDetail: (service) {
                                          openDetail(
                                            'Chi tiết dịch vụ',
                                            ServiceDetailScreen(
                                              service: service,
                                            ),
                                          );
                                        },
                                      ),
                                    1 => SelectDoctorStep(
                                        controller: c,
                                        onDetail: (doctor) {
                                          openDetail(
                                            'Chi tiết bác sĩ',
                                            DoctorDetailScreen(
                                              doctor: doctor,
                                            ),
                                          );
                                        },
                                      ),
                                    2 => SelectDatetimeStep(
                                        controller: c,
                                      ),
                                    _ => ConfirmBookingStep(
                                        controller: c,
                                      ),
                                  },
                                  const SizedBox(height: 12),
                                  BookingPriceSummary(
                                    controller: c,
                                    onNext: next,
                                    onReselect: reselect,
                                  ),
                                ],
                              ),
                            )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
