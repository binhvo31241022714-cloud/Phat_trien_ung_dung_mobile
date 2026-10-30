import 'dart:async';
import '../core/state/session_notifier.dart';

import '../data/api_client.dart';
import '../data/models/appointment.dart';
import '../data/services/booking_service.dart';

/// Quản lý danh sách lịch hẹn và lịch hẹn sắp tới lấy từ backend.
class AppointmentsProvider extends SessionNotifier {
  final BookingService _service;

  AppointmentsProvider({BookingService? service})
      : _service = service ?? BookingService();

  int _loadRequest = 0;

  List<Appointment> _appointments = const [];
  // Keep successful creates until a GET has observed their IDs. An older
  // in-flight list response must not remove a just-created appointment.
  final Set<String> _unobservedCreates = {};
  final Set<String> _confirmedCancellations = {};
  final Map<String, Future<String?>> _cancelJobs = {};
  bool isCancelling(String id) => _cancelJobs.containsKey(id);
  Future<AppointmentCancellationInfo> cancellationInfo(String id) =>
      _service.cancellationInfo(id);
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Lịch hẹn sắp tới gần nhất (chờ xác nhận hoặc đã xác nhận, còn ở tương lai).
  Appointment? get upcomingAppointment {
    final now = DateTime.now();
    final active = _appointments.where((a) {
      if (!a.status.isUpcomingStatus) return false;
      return a.hasValidScheduledAt && !a.scheduledAt.isBefore(now);
    }).toList();

    if (active.isEmpty) return null;
    active.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return active.first;
  }

  /// Danh sách lịch hẹn cho một người cụ thể (bản thân hoặc người thân).
  List<Appointment> appointmentsFor(String patientId) {
    return _appointments.where((a) => a.patientId == patientId).toList();
  }

  /// Tải lịch hẹn nếu chưa có (gọi khi vào trang chính hoặc danh sách lịch).
  Future<void> ensureLoaded() async {
    if (!_loaded && !_loading) await load();
  }

  Future<void> load() async {
    if (isDisposed) return;
    final session = sessionGeneration;
    final request = ++_loadRequest;
    bool current() => isSessionCurrent(session) && request == _loadRequest;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _service.getAppointments();
      if (!current()) return;
      // Sắp xếp lịch hẹn: lịch mới nhất lên đầu (theo ngày giờ khám).
      results.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      _confirmedCancellations.removeWhere((id) => results
          .any((a) => a.id == id && a.status == AppointmentStatus.cancelled));
      for (var i = 0; i < results.length; i++) {
        if (_confirmedCancellations.contains(results[i].id)) {
          results[i] = _cancelled(results[i]);
        }
      }
      final ids = results.map((a) => a.id).toSet();
      _unobservedCreates.removeWhere(ids.contains);
      _appointments = List.unmodifiable([
        ..._appointments.where((a) => _unobservedCreates.contains(a.id)),
        ...results
      ]);
      _loaded = true;
    } on ApiException catch (e) {
      if (!current()) return;
      _error = e.message;
    } catch (_) {
      if (!current()) return;
      _error = 'Không thể tải danh sách lịch hẹn. Vui lòng thử lại.';
    } finally {
      if (current()) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Đọc lại một lịch hẹn từ GET /api/appointments/:id và cập nhật vào danh sách.
  /// 403/404: bỏ lịch khỏi danh sách rồi ném lỗi để màn hình báo không còn khả dụng.
  Future<AppointmentCancellationInfo> refreshOne(String id) async {
    final session = sessionGeneration;
    try {
      final info = await cancellationInfo(id);
      if (isSessionCurrent(session)) {
        final fresh = _confirmedCancellations.contains(id)
            ? _cancelled(info.appointment)
            : info.appointment;
        _appointments = List.unmodifiable([
          for (final a in _appointments) a.id == id ? fresh : a,
          if (!_appointments.any((a) => a.id == id)) fresh,
        ]);
        notifyListeners();
      }
      return info;
    } on ApiException catch (e) {
      if (isSessionCurrent(session) &&
          (e.statusCode == 403 || e.statusCode == 404)) {
        _appointments = List.unmodifiable(_appointments.where((a) => a.id != id));
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Hủy một lịch hẹn chưa diễn ra trên máy chủ.
  /// Trả về null nếu thành công, ngược lại trả về chuỗi thông báo lỗi.
  Future<String?> cancel(String id, {Appointment? snapshot}) {
    if (isDisposed) return Future.value('Phiên đăng nhập đã kết thúc.');
    if (_cancelJobs.containsKey(id)) return _cancelJobs[id]!;
    final session = sessionGeneration;
    final done = Completer<String?>();
    _cancelJobs[id] = done.future;
    notifyListeners();
    () async {
      String? error;
      try {
        await _service.cancelAppointment(id);
        if (!isSessionCurrent(session)) {
          error = 'Phiên đăng nhập đã thay đổi.';
        } else {
          _confirmedCancellations.add(id);
          final target =
              _appointments.where((a) => a.id == id).firstOrNull ?? snapshot;
          if (target != null && target.id == id) {
            final cancelled = _cancelled(target);
            _appointments = [
              for (final a in _appointments) a.id == id ? cancelled : a
            ];
            if (!_appointments.any((a) => a.id == id)) {
              _appointments = [cancelled, ..._appointments];
            }
          }
        }
      } catch (e) {
        error = !isSessionCurrent(session)
            ? 'Phiên đăng nhập đã thay đổi.'
            : e is ApiException
                ? e.message
                : 'Lỗi khi hủy lịch hẹn. Vui lòng thử lại sau.';
      } finally {
        if (isSessionCurrent(session)) {
          _cancelJobs.remove(id);
          notifyListeners();
        }
        done.complete(error);
      }
    }();
    return done.future;
  }

  Appointment _cancelled(Appointment a) => Appointment(
      id: a.id,
      patientId: a.patientId,
      doctorId: a.doctorId,
      doctorName: a.doctorName,
      accountId: a.accountId,
      comboId: a.comboId,
      voucherCode: a.voucherCode,
      totalPrice: a.totalPrice,
      discount: a.discount,
      durationMinutes: a.durationMinutes,
      serviceIds: a.serviceIds,
      hasValidScheduledAt: a.hasValidScheduledAt,
      scheduledAt: a.scheduledAt,
      endAt: a.endAt,
      status: AppointmentStatus.cancelled,
      note: a.note,
      isDemo: false);

  /// Thêm lịch vừa tạo thành công vào đầu danh sách lịch hẹn.
  void addCreated(Appointment appointment, {int? generation}) {
    if (isDisposed || generation != null && !isSessionCurrent(generation)) {
      return;
    }
    _unobservedCreates.add(appointment.id);
    _appointments = [
      appointment,
      ..._appointments.where((a) => a.id != appointment.id)
    ];
    notifyListeners();
  }

  /// Xóa dữ liệu khi người dùng đăng xuất.
  void clear() {
    invalidateSession();
    _unobservedCreates.clear();
    _confirmedCancellations.clear();
    _cancelJobs.clear();
    _appointments = const [];
    _loading = false;
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
