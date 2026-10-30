import '../data/providers/patient_data_provider.dart';
import '../providers/user_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/appointments_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/content_provider.dart';
import 'patient_navigation.dart';

/// Resets private stores synchronously on UID/session changes, before UI rebuilds.
class PrivateSession {
  final UserProvider users;
  final PatientDataProvider patients;
  final ProfileProvider profiles;
  final AppointmentsProvider appointments;
  final CatalogProvider catalog;
  final ContentProvider content;
  final bool apiMode;
  int? _generation;
  PrivateSession(
      {required this.users,
      required this.patients,
      required this.profiles,
      required this.appointments,
      required this.catalog,
      required this.content,
      this.apiMode = true}) {
    users.addListener(_changed);
    appointments.addListener(_appointmentsChanged);
    _changed();
  }
  void _changed() {
    if (_generation == users.sessionGeneration) return;
    _generation = users.sessionGeneration;
    if (apiMode) {
      patients.clearPrivateState();
    } else {
      patients.resetDemoSession();
    }
    profiles.clear();
    appointments.clear();
    catalog.clear(); // Retains public services, combos and doctors.
    PatientNavigation.pendingBookingRequest = null;
    content.setAccount(apiMode && users.isAuthenticated ? users.uid : null);
  }

  void _appointmentsChanged() {
    content.appointmentsChanged(appointments.appointments
        .map((a) => '${a.id}:${a.status}:${a.scheduledAt}')
        .join('|'));
  }

  void dispose() {
    users.removeListener(_changed);
    appointments.removeListener(_appointmentsChanged);
  }
}
