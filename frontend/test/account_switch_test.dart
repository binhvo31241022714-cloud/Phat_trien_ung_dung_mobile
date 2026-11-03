import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/features/booking/booking_screen.dart';
import 'support/api_app_fixture.dart';
import 'support/data_source_scope.dart';
import 'support/fake_auth_service.dart';

void main() {
  setUp(() => useDataSourceForTest(DataSource.api));

  testWidgets(
      'A -> logout -> register B -> login B -> logout -> A uses owned IDs',
      (t) async {
    final f = ApiAppFixture(signedIn: false);
    f.family.clear();
    f.appointmentRows.clear();
    void backend(String email, String name) {
      f.me.addAll({'id': 'demo:$email', 'email': email, 'fullName': name});
    }

    backend('a@example.com', 'Account A');
    await f.users.login('a@example.com', 'secret123');
    await f.mount(t, app: true);
    expect(f.profiles.profile?.fullName, 'Account A');
    expect(f.records.primaryPatient.id, 'demo:a@example.com');
    expect(find.textContaining('Account A'), findsWidgets);

    await f.users.logout();
    expect(f.profiles.profile, isNull);
    expect(f.records.patients, isEmpty);
    expect(f.records.appointments, isEmpty);
    expect(f.appointments.appointments, isEmpty);
    await t.pumpAndSettle();
    backend('b@example.com', 'Account B');
    await f.users.register('Account B', 'b@example.com', 'secret123');
    await t.pumpAndSettle();
    await f.users.logout();
    await t.pumpAndSettle();
    final startB = f.requests.length;
    await f.users.login('b@example.com', 'secret123');
    await t.pumpAndSettle();
    expect(f.profiles.profile?.fullName, 'Account B');
    expect(f.records.selectedPatientId, 'demo:b@example.com');
    expect(find.textContaining('Account A'), findsNothing);
    expect(find.textContaining('Account B'), findsWidgets);
    final patientRequests = f.requests
        .skip(startB)
        .where((r) => r.url.path.startsWith('/api/patients/'));
    expect(patientRequests, isNotEmpty);
    expect(
        patientRequests
            .every((r) => r.url.pathSegments[2] == 'demo:b@example.com'),
        isTrue);
    // Booking is mounted in MainShell's IndexedStack and uses that same profile.
    expect(find.byType(BookingScreen, skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Account B (Bản thân)', skipOffstage: false),
        findsWidgets);
    await f.users.logout();
    await t.pumpAndSettle();
    backend('a@example.com', 'Account A');
    await f.users.login('a@example.com', 'secret123');
    await t.pumpAndSettle();
    expect(f.profiles.profile?.fullName, 'Account A');
    expect(f.records.selectedPatientId, 'demo:a@example.com');
    expect(find.textContaining('Account B', skipOffstage: false), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('restart restores B from auth storage; expired session clears B',
      (t) async {
    // New provider graph; only the auth SDK's persisted identity survives.
    final auth = FakeAuthService(email: 'b@example.com');
    final f = ApiAppFixture(signedIn: false, authOverride: auth);
    f.family.clear();
    f.appointmentRows.clear();
    f.me.addAll({
      'id': 'demo:b@example.com',
      'email': 'b@example.com',
      'fullName': 'Account B'
    });
    await f.users.restoreSession();
    await f.mount(t, app: true);
    expect(f.records.selectedPatientId, 'demo:b@example.com');
    expect(f.profiles.profile?.fullName, 'Account B');
    await f.users.handleSessionExpired();
    expect(auth.email, isNull);
    expect(f.users.currentUser, isNull);
    expect(f.profiles.profile, isNull);
    expect(f.records.patients, isEmpty);
    expect(f.content.home, isNull);
    await t.pumpAndSettle();
    expect(find.textContaining('Account B', skipOffstage: false), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('missing profile never falls back to another patient', (t) async {
    final f = ApiAppFixture();
    f.profileMissing = true;
    await f.mount(t, app: true);
    expect(f.profiles.profile, isNull);
    expect(f.records.patients, isEmpty);
    expect(find.text('Chưa có hồ sơ người khám'), findsOneWidget);
    expect(find.byType(BookingScreen, skipOffstage: false), findsNothing);
    expect(f.requests.where((r) => r.url.path.startsWith('/api/patients/')),
        isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('/me with a different owner is rejected before patient requests',
      (t) async {
    final f = ApiAppFixture();
    f.me['id'] = 'other-account';
    await f.mount(t, app: true);
    expect(f.profiles.profile, isNull);
    expect(f.records.patients, isEmpty);
    expect(find.text('Hồ sơ không thuộc tài khoản hiện tại.'), findsOneWidget);
    expect(f.requests.where((r) => r.url.path.startsWith('/api/patients/')),
        isEmpty);
    expect(t.takeException(), isNull);
  });
}
