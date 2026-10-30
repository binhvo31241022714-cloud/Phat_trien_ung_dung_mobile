import 'package:frontend/data/services/booking_service.dart'
    show AppointmentCancellationInfo;
import 'package:frontend/providers/appointments_provider.dart';

/// Provider giả dùng trong widget test, không gọi API thật.
class FakeAppointmentsProvider extends AppointmentsProvider {
  @override
  Future<AppointmentCancellationInfo> cancellationInfo(String id) async =>
      AppointmentCancellationInfo({'id': id, 'status': 'completed'});
  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}
}
