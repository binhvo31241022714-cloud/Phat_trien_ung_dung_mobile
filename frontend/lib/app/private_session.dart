import 'package:flutter/foundation.dart';

import '../data/providers/patient_data_provider.dart';
import '../providers/appointments_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/content_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/user_provider.dart';

/// Owns the boundary between authenticated accounts, including restored sessions.
/// Clear synchronously, before the UI can request data for the next account.
class PrivateSession {
  final UserProvider users;
  final bool apiMode;
  final PatientDataProvider patients;
  final ProfileProvider profiles;
  final AppointmentsProvider appointments;
  final CatalogProvider catalog;
  final ContentProvider content;
  int? _generation;

  PrivateSession({
    required this.users,
    this.apiMode = true,
    required this.patients,
    required this.profiles,
    required this.appointments,
    required this.catalog,
    required this.content,
  }) {
    users.addListener(_onIdentityChanged);
    _onIdentityChanged();
  }

  void _onIdentityChanged() {
    if (_generation == users.sessionGeneration) return;
    _generation = users.sessionGeneration;
    patients.clearPrivateState();
    profiles.setAccount(apiMode ? users.uid : null);
    appointments.clear();
    catalog.clear();
    content.setAccount(apiMode ? users.uid : null);
    if (!apiMode && users.isAuthenticated) patients.resetDemoSession();
    assert(() {
      debugPrint('[session] authenticatedUid=${users.uid} '
          'generation=$_generation profileId=${profiles.profile?.id} '
          'selectedPatientId=${patients.selectedPatientId}; '
          'identity storage=FirebaseAuth (no local patient ID)');
      return true;
    }());
  }

  void dispose() => users.removeListener(_onIdentityChanged);
}
