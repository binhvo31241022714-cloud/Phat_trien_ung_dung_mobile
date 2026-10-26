import 'dart:async';
import '../../core/config/app_config.dart';
import 'package:flutter/foundation.dart';

import '../../data/api_client.dart';
import '../../data/models/appointment.dart';
import '../../data/models/availability_slot.dart';
import '../../data/models/dental_service.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../data/services/availability_service.dart';
import '../../data/services/booking_service.dart' hide AvailabilitySlot;
import '../../providers/appointments_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/profile_provider.dart';

class BookingController extends ChangeNotifier {
  BookingController(
    this.data, {
    this.catalog,
    this.profile,
    BookingService? bookingService,
    AvailabilityService? availabilityService,
    DateTime Function()? clock,
    String? initialDoctorId,
    List<String>? initialServiceIds,
    String? initialComboId,
    String? initialPatientId,
  })  : now = clock ?? DateTime.now,
        bookingService = bookingService ?? BookingService(),
        availabilityService =
            availabilityService ?? AvailabilityService(),
        patientId = initialPatientId ??
            profile?.profile?.id ??
            data.selectedPatientId {
    catalog?.addListener(_onCatalogChanged);
    profile?.addListener(_onProfileChanged);

    if (initialServiceIds != null && initialServiceIds.isNotEmpty) {
      serviceIds.addAll(initialServiceIds);
    }
    if (initialComboId != null && initialComboId.isNotEmpty) {
      comboId = initialComboId;
    }
    if (initialDoctorId != null && initialDoctorId.isNotEmpty) {
      _preferredDoctorId = initialDoctorId;
      doctorId = initialDoctorId;
      doctorChosen = true;
    }

    _verifyDoctorForCurrentCombo();

    if (hasSelectedItems) {
      _reloadIfPossible();
      unawaited(refreshQuote());
      step = doctorChosen ? 2 : 1;
    }
  }

  final PatientDataProvider data;
  final CatalogProvider? catalog;
  final ProfileProvider? profile;
  final BookingService bookingService;
  final AvailabilityService availabilityService;
  final DateTime Function() now;

  String patientId;
  int step = 0;

  /// IDs của các dịch vụ lẻ đã chọn.
  final Set<String> serviceIds = <String>{};

  /// ID combo được gửi riêng cho API.
  String? comboId;

  /// Bác sĩ được ưu tiên chọn. Null nghĩa là để Backend chọn bác sĩ phù hợp.
  String? _preferredDoctorId;

  /// Bác sĩ thực tế của khung giờ đã chọn.
  String? doctorId;

  String? get preferredDoctorId => _preferredDoctorId;

  bool doctorChosen = false;

  DateTime? date;
  String? time;

  String voucher = '';
  String? appliedVoucher;
  String? voucherError;
  bool voucherLoading = false;

  int? _apiSubtotal;
  int _apiDiscount = 0;
  int? _apiTotal;
  int _durationMinutes = 30;
  bool quoteLoading = false;

  String note = '';

  bool submitting = false;
  Appointment? created;

  /// Danh sách chỉ chứa slot hợp lệ, không chứa null.
  List<AvailabilitySlot> availabilitySlots = <AvailabilitySlot>[];
  bool availabilityLoading = false;
  String? availabilityError;

  bool _disposed = false;
  int _availabilityRequestId = 0;
  int _quoteRequestId = 0;

  void _onCatalogChanged() {
    if (_disposed) return;
    _verifyDoctorForCurrentCombo();
    notifyListeners();
  }

 void _onProfileChanged() {
  if (_disposed ||
      AppConfig.current.dataSource != DataSource.api) {
    return;
  }

  final realId = profile?.profile?.id;
  if (realId == null || realId.isEmpty) return;

  final isMockPatient = data.patients.any(
    (patient) => patient.id == patientId,
  );

  final isFamilyMember = profile!.family.any(
    (member) => member.id == patientId,
  );

  // Chỉ đổi ID mẫu sang UID tài khoản khi chạy API.
  // Không ghi đè ID người thân đã được xác định.
  if (patientId != realId &&
      isMockPatient &&
      !isFamilyMember) {
    patientId = realId;
    notifyListeners();
  }
}

  @override
  void dispose() {
    _disposed = true;
    _availabilityRequestId++;
    _quoteRequestId++;
    catalog?.removeListener(_onCatalogChanged);
    profile?.removeListener(_onProfileChanged);
    super.dispose();
  }

  /// Dịch vụ và combo lấy từ CatalogProvider; dùng dữ liệu cũ làm fallback.
  List<DentalService> get services {
    final source = catalog;
    if (source == null) return data.services;
    return <DentalService>[...source.services, ...source.combos];
  }

  bool get hasSelectedItems => serviceIds.isNotEmpty || comboId != null;

  bool isSelected(DentalService item) {
    if (item.isCombo) return comboId == item.id;
    return serviceIds.contains(item.id);
  }

  DentalService? _findCombo(String? id) {
    if (id == null || catalog == null) return null;
    for (final item in catalog!.combos) {
      if (item.id == id) return item;
    }
    return null;
  }

  void toggleCatalogItem(DentalService item) {
    if (_disposed || submitting || created != null) return;

    if (item.isCombo) {
      comboId = comboId == item.id ? null : item.id;
      _verifyDoctorForCurrentCombo();
    } else {
      if (!serviceIds.add(item.id)) serviceIds.remove(item.id);
    }

    _resetAvailability();
    unawaited(refreshQuote());
    notifyListeners();
    _reloadIfPossible();
  }

  /// Giữ lại phương thức cũ để tương thích với các màn hình đang dùng.
  void toggleService(String id) {
    if (_disposed || submitting || created != null) return;

    if (!serviceIds.add(id)) serviceIds.remove(id);

    _resetAvailability();
    unawaited(refreshQuote());
    notifyListeners();
    _reloadIfPossible();
  }

  int get localSubtotal {
    final selectedCombos = services
        .where((service) => service.isCombo && service.id == comboId)
        .toList();

    final includedServiceIds = selectedCombos.isEmpty
        ? <String>{}
        : selectedCombos.first.serviceIds.toSet();

    return services.where((service) {
      if (service.isCombo) return service.id == comboId;
      return serviceIds.contains(service.id) &&
          !includedServiceIds.contains(service.id);
    }).fold<int>(0, (sum, service) => sum + service.price);
  }

  int get subtotal => _apiSubtotal ?? localSubtotal;
  int get discount => _apiDiscount;
  int get total =>
      _apiTotal ?? (subtotal - discount).clamp(0, double.infinity).toInt();
  int get durationMinutes => _durationMinutes;

  /// Gọi POST /api/bookings/quote để lấy giá và thời lượng chuẩn.
  Future<void> refreshQuote() async {
    if (_disposed) return;

    if (!hasSelectedItems) {
      _quoteRequestId++;
      _apiSubtotal = null;
      _apiDiscount = 0;
      _apiTotal = null;
      _durationMinutes = 30;
      quoteLoading = false;
      notifyListeners();
      return;
    }

    final requestId = ++_quoteRequestId;
    quoteLoading = true;
    notifyListeners();

    try {
      final quote = await bookingService.quote(
        serviceIds: serviceIds.toList(),
        comboId: comboId,
        voucherCode: appliedVoucher,
      );

      if (_disposed || requestId != _quoteRequestId) return;

      _apiSubtotal = quote.subtotal;
      _apiDiscount = quote.discount;
      _apiTotal = quote.totalPrice;
      _durationMinutes = quote.durationMinutes;
    } catch (_) {
      if (_disposed || requestId != _quoteRequestId) return;
      // Giữ giá tạm tính cục bộ khi API chưa kết nối được.
      _apiSubtotal = null;
      _apiDiscount = 0;
      _apiTotal = null;
    } finally {
      if (!_disposed && requestId == _quoteRequestId) {
        quoteLoading = false;
        notifyListeners();
      }
    }
  }

  /// Gọi POST /api/vouchers/validate để kiểm tra voucher.
  Future<bool> applyVoucher(String code) async {
    if (_disposed) return false;

    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      voucherError = 'Vui lòng nhập mã ưu đãi';
      notifyListeners();
      return false;
    }
    if (!hasSelectedItems) {
      voucherError = 'Vui lòng chọn dịch vụ trước';
      notifyListeners();
      return false;
    }

    voucherLoading = true;
    voucherError = null;
    notifyListeners();

    try {
      final result = await bookingService.validateVoucher(
        code: trimmed,
        serviceIds: serviceIds.toList(),
        comboId: comboId,
      );

      if (_disposed) return false;

      appliedVoucher = result.code;
      voucher = result.code;
      _apiSubtotal = result.subtotal;
      _apiDiscount = result.discount;
      _apiTotal = result.totalPrice;
      voucherError = null;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (_disposed) return false;

      voucherError = error.message;
      appliedVoucher = null;
      _apiDiscount = 0;
      _apiTotal = null;
      notifyListeners();
      return false;
    } catch (_) {
      if (_disposed) return false;

      voucherError = 'Không thể kiểm tra mã ưu đãi. Vui lòng thử lại.';
      appliedVoucher = null;
      _apiDiscount = 0;
      _apiTotal = null;
      notifyListeners();
      return false;
    } finally {
      if (!_disposed) {
        voucherLoading = false;
        notifyListeners();
      }
    }
  }

  void removeVoucher() {
    if (_disposed) return;

    appliedVoucher = null;
    voucher = '';
    voucherError = null;
    _apiDiscount = 0;
    _apiTotal = null;
    unawaited(refreshQuote());
    notifyListeners();
  }

  /// Bác sĩ của combo phải thực hiện được toàn bộ dịch vụ trong combo.
  void _verifyDoctorForCurrentCombo() {
    if (comboId == null || catalog == null || _preferredDoctorId == null) {
      return;
    }

    final combo = _findCombo(comboId);
    // Catalog có thể chưa tải xong; không tự loại bác sĩ khi chưa có dữ liệu.
    if (combo == null) return;

    final eligibleDoctors = catalog!.doctorsFor(combo);
    final isEligible = eligibleDoctors.any(
      (doctor) => doctor.id == _preferredDoctorId,
    );

    if (!isEligible) {
      _preferredDoctorId = null;
      doctorId = null;
      doctorChosen = false;
      _resetAvailability();
    }
  }

  void _resetAvailability() {
    _availabilityRequestId++;
    availabilitySlots = <AvailabilitySlot>[];
    availabilityLoading = false;
    availabilityError = null;
    time = null;
    doctorId = _preferredDoctorId;
  }

  void _reloadIfPossible() {
    if (date != null && hasSelectedItems) {
      unawaited(loadAvailability());
    }
  }

  /// Tải khung giờ còn trống từ GET /api/availability.
  Future<void> loadAvailability() async {
    if (_disposed) return;

    final selectedDate = date;
    if (selectedDate == null || !hasSelectedItems) {
      availabilitySlots = <AvailabilitySlot>[];
      availabilityLoading = false;
      availabilityError = null;
      notifyListeners();
      return;
    }

    final requestId = ++_availabilityRequestId;
    availabilityLoading = true;
    availabilityError = null;
    availabilitySlots = <AvailabilitySlot>[];
    time = null;
    doctorId = _preferredDoctorId;
    notifyListeners();

    try {
      final result = await availabilityService.getSlots(
        date: selectedDate,
        serviceIds: serviceIds.toList(),
        comboId: comboId,
        doctorId: _preferredDoctorId,
      );

      if (_disposed || requestId != _availabilityRequestId) return;

      // Loại phần tử null nếu service/model trả về danh sách có phần tử nullable.
      availabilitySlots = result.whereType<AvailabilitySlot>().toList();
    } catch (error) {
      if (_disposed || requestId != _availabilityRequestId) return;

      availabilityError = error is ApiException
          ? error.message
          : error.toString();
      availabilitySlots = <AvailabilitySlot>[];
    } finally {
      if (!_disposed && requestId == _availabilityRequestId) {
        availabilityLoading = false;
        notifyListeners();
      }
    }
  }

  DateTime? at(String? slot) {
    if (date == null || slot == null) return null;

    final parts = slot.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return DateTime(date!.year, date!.month, date!.day, hour, minute);
  }

  bool validSlot(String slot) =>
      availabilitySlots.whereType<AvailabilitySlot>().any(
        (item) =>
            item.startTime == slot &&
            (doctorId == null || item.doctorId == doctorId),
      );

  bool get validTime =>
      time != null &&
      doctorId != null &&
      availabilitySlots.whereType<AvailabilitySlot>().any(
        (item) =>
            item.startTime == time && item.doctorId == doctorId,
      );

  bool get canContinue => switch (step) {
        0 => hasSelectedItems,
        1 => doctorChosen,
        _ => validTime,
      };

  void selectPatient(String id) {
    if (_disposed || submitting || created != null) return;
    patientId = id;
    notifyListeners();
  }

  /// Truyền null để yêu cầu Backend tự chọn bác sĩ còn trống.
  void chooseDoctor(String? id) {
    if (_disposed || submitting || created != null) return;

    if (id != null && comboId != null && catalog != null) {
      final combo = _findCombo(comboId);
      if (combo != null) {
        final eligibleDoctors = catalog!.doctorsFor(combo);
        if (!eligibleDoctors.any((doctor) => doctor.id == id)) return;
      }
    }

    _preferredDoctorId = id;
    doctorId = id;
    doctorChosen = true;
    _resetAvailability();
    notifyListeners();
    _reloadIfPossible();
  }

  void chooseDate(DateTime value) {
    if (_disposed || submitting || created != null) return;

    final today = now();
    final selectedDay = DateTime(value.year, value.month, value.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (selectedDay.isBefore(todayOnly)) return;

    date = value;
    _resetAvailability();
    notifyListeners();
    _reloadIfPossible();
  }

  /// Chọn một slot tồn tại trong kết quả availability hiện tại.
  void chooseAvailabilitySlot(AvailabilitySlot slot) {
    if (_disposed || submitting || created != null) return;

    final available =
        availabilitySlots.whereType<AvailabilitySlot>().any(
              (item) =>
                  item.doctorId == slot.doctorId &&
                  item.startTime == slot.startTime,
            );
    if (!available) return;

    time = slot.startTime;
    doctorId = slot.doctorId;
    notifyListeners();
  }

  /// Giữ phương thức cũ để tương thích với nơi gọi chooseTime.
  void chooseTime(String value) {
    if (_disposed || submitting || created != null) return;

    for (final slot in availabilitySlots.whereType<AvailabilitySlot>()) {
      if (slot.startTime == value &&
          (_preferredDoctorId == null ||
              slot.doctorId == _preferredDoctorId)) {
        chooseAvailabilitySlot(slot);
        return;
      }
    }
  }

  void next() {
    if (_disposed ||
        submitting ||
        created != null ||
        !canContinue ||
        step >= 3) {
      return;
    }

    step++;
    notifyListeners();
  }

  void back() {
    if (_disposed || submitting || created != null) return;
    if (step > 0) {
      step--;
      notifyListeners();
    }
  }

  /// Áp dụng giá trị chọn sẵn khi mở đặt lịch từ dịch vụ/combo/bác sĩ.
  void applyInitialValues({
    String? doctorId,
    List<String>? serviceIds,
    String? comboId,
    String? patientId,
  }) {
    if (_disposed || submitting || created != null) return;

    if (patientId != null && patientId.isNotEmpty) {
      this.patientId = patientId;
    }
    if (comboId != null && comboId.isNotEmpty) {
      this.comboId = comboId;
    }
    if (serviceIds != null && serviceIds.isNotEmpty) {
      this.serviceIds.addAll(serviceIds);
    }
    if (doctorId != null && doctorId.isNotEmpty) {
      _preferredDoctorId = doctorId;
      this.doctorId = doctorId;
      doctorChosen = true;
    }

    _verifyDoctorForCurrentCombo();
    _resetAvailability();
    unawaited(refreshQuote());

    if (hasSelectedItems && doctorChosen) {
      step = 2;
    } else if (hasSelectedItems) {
      step = 1;
    } else {
      step = 0;
    }

    notifyListeners();
    _reloadIfPossible();
  }

  /// Tạo lịch hẹn qua POST /api/appointments.
  Future<Appointment?> submit({
    AppointmentsProvider? appointmentsProvider,
  }) async {
    if (_disposed) return null;
    if (submitting || created != null) return created;

    if (!hasSelectedItems ||
        !doctorChosen ||
        !validTime ||
        date == null ||
        time == null) {
      return null;
    }

    submitting = true;
    notifyListeners();

    try {
      final appointment = await bookingService.createAppointment(
        patientId: patientId,
        date: date!,
        startTime: time!,
        doctorId: doctorId,
        serviceIds: serviceIds.toList(),
        comboId: comboId,
        voucherCode: appliedVoucher,
      );

      if (_disposed) return appointment;

      created = appointment;
      appointmentsProvider?.addCreated(appointment);
      // Giữ bản sao để tương thích với màn hình cũ.
      data.addAppointment(appointment);
      return appointment;
    } finally {
      submitting = false;
      if (!_disposed) notifyListeners();
    }
  }
}
