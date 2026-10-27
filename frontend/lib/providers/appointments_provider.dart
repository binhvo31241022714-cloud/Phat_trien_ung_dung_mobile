import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/models/appointment.dart';
import '../data/services/booking_service.dart';

/// Quản lý danh sách lịch hẹn và lịch hẹn sắp tới lấy từ backend.
class AppointmentsProvider extends ChangeNotifier {
  final BookingService _service;

  AppointmentsProvider({BookingService? service})
      : _service = service ?? BookingService();

  int _session = 0;

  List<Appointment> _appointments = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Lịch hẹn sắp tới gần nhất (chưa hoàn tất, chưa hủy, còn ở tương lai).
  Appointment? get upcomingAppointment {
    final now = DateTime.now();
    final active = _appointments.where((a) {
      if (a.status == AppointmentStatus.cancelled ||
          a.status == AppointmentStatus.completed) {
        return false;
      }
      return !a.scheduledAt.isBefore(now);
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
    final session = _session;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _service.getAppointments();
      if (session != _session) return;
      // Sắp xếp lịch hẹn: lịch mới nhất lên đầu (theo ngày giờ khám).
      results.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      _appointments = List.unmodifiable(results);
      _loaded = true;
    } on ApiException catch (e) {
      if (session != _session) return;
      _error = e.message;
    } catch (_) {
      if (session != _session) return;
      _error = 'Không thể tải danh sách lịch hẹn. Vui lòng thử lại.';
    } finally {
      if (session == _session) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Hủy một lịch hẹn chưa diễn ra trên máy chủ.
  /// Trả về null nếu thành công, ngược lại trả về chuỗi thông báo lỗi.
  Future<String?> cancel(String id) async {
    try {
      await _service.cancelAppointment(id);
      // Cập nhật trạng thái cục bộ ngay lập tức để UI phản hồi mượt mà.
      _appointments = _appointments.map((a) {
        if (a.id == id) {
          return Appointment(
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
            scheduledAt: a.scheduledAt,
            endAt: a.endAt,
            status: AppointmentStatus.cancelled,
            note: a.note,
            isDemo: false,
          );
        }
        return a;
      }).toList();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Lỗi khi hủy lịch hẹn. Vui lòng thử lại sau.';
    }
  }

  /// Thêm lịch vừa tạo thành công vào đầu danh sách lịch hẹn.
  void addCreated(Appointment appointment) {
    _appointments = [appointment, ..._appointments];
    notifyListeners();
  }

  /// Xóa dữ liệu khi người dùng đăng xuất.
  void clear() {
    _session++;
    _appointments = const [];
    _loading = false;
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
