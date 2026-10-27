import 'package:frontend/providers/appointments_provider.dart';

/// Provider giả dùng trong widget test, không gọi API thật.
class FakeAppointmentsProvider extends AppointmentsProvider {
  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}
}
