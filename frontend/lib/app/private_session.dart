import '../data/providers/patient_data_provider.dart';
import '../providers/appointments_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/content_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/user_provider.dart';
class PrivateSession {
  final UserProvider users;
  final bool apiMode;
  final PatientDataProvider patients;
  final ProfileProvider profiles;
  final AppointmentsProvider appointments;
  final CatalogProvider catalog;
  final ContentProvider content;
  PrivateSession({required this.users, required this.apiMode, required this.patients, required this.profiles, required this.appointments, required this.catalog, required this.content});
  void dispose() {}
}
