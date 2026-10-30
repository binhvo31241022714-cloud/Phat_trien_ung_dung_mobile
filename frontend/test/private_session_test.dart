import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/services/catalog_service.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/app/private_session.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/auth_service.dart';
import 'package:frontend/data/services/records_service.dart';
import 'package:frontend/data/services/profile_service.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'support/fake_auth_service.dart';
import 'support/fake_catalog_backend.dart';
import 'module4_test.dart' as fixture;

class IdentityAuth extends FakeAuthService implements AuthIdentitySource {
  final events = StreamController<String?>.broadcast(sync: true);
  String? identity;
  Completer<void>? signOutGate;
  @override
  String? get currentUid => identity;
  @override
  String? get currentEmail => 'same-email@example.test';
  @override
  Stream<String?> get uidChanges => events.stream;
  void emit(String? uid) {
    identity = uid;
    events.add(uid);
  }

  @override
  Future<void> signOut() async {
    await signOutGate?.future;
    emit(null);
  }
}

UserProfile profile(String id) =>
    UserProfile(id: id, email: 'test@example.test', fullName: id, phone: '');
Appointment appointment(String owner, [String id = 'appointment']) =>
    Appointment(
        id: id,
        patientId: owner,
        accountId: owner,
        serviceIds: ['svc_01'],
        scheduledAt: DateTime(2099),
        status: AppointmentStatus.pending,
        isDemo: false);

class DeferredRecords extends RecordsService {
  final pending = <Completer<List<dynamic>>>[];
  @override
  Future<List<dynamic>> visits(String id) {
    final c = Completer<List<dynamic>>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<List<dynamic>> invoices(String id) async => [];
  @override
  Future<List<dynamic>> treatments(String id) async => [];
  @override
  Future<List<dynamic>> followups(String id) async => [];
  @override
  Future<Map<String, dynamic>> visit(String id) async =>
      {'id': id, 'patientId': 'B'};
  @override
  Future<List<dynamic>> prescriptions(String id) async => [];
}

class DeferredProfile extends ProfileService {
  final pending = <Completer<UserProfile>>[];
  final writes = <Completer<void>>[];
  @override
  Future<List<FamilyMember>> getFamily() async => [];
  @override
  Future<UserProfile> getMe() {
    final c = Completer<UserProfile>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<void> updateMe(
      {required String fullName,
      required String phone,
      DateTime? birthday,
      String? gender,
      dynamic health}) {
    final c = Completer<void>();
    writes.add(c);
    return c.future;
  }
}

class DeferredBookings extends BookingService {
  final pending = <Completer<List<Appointment>>>[];
  @override
  Future<List<Appointment>> getAppointments() {
    final c = Completer<List<Appointment>>();
    pending.add(c);
    return c.future;
  }
}

class DeferredFavorites extends CatalogService {
  final reads = <Completer<List<Favorite>>>[];
  final write = Completer<void>();
  @override
  Future<List<Favorite>> getFavorites() {
    final c = Completer<List<Favorite>>();
    reads.add(c);
    return c.future;
  }

  @override
  Future<void> addFavorite(String type, String itemId) => write.future;
}

void main() {
  test(
      'UID events clear every private store immediately; public catalog survives',
      () async {
    final auth = IdentityAuth();
    final users = UserProvider(auth: auth);
    final records = PatientDataProvider(seedDemo: false);
    final profiles = ProfileProvider(service: DeferredProfile());
    final appointments = AppointmentsProvider(service: DeferredBookings());
    final catalog = FakeCatalogBackend().provider();
    await catalog.load();
    final content = fixture.Backend().provider();
    final session = PrivateSession(
        users: users,
        patients: records,
        profiles: profiles,
        appointments: appointments,
        catalog: catalog,
        content: content);
    auth.emit('A');
    records.syncPatients(profile('A'), []);
    records.replaceAppointments([appointment('A')]);
    appointments.addCreated(appointment('A'));
    await catalog.toggleFavorite('article', 'article_01');
    await content.loadNotifications();
    expect(content.notifications, isNotEmpty);
    auth.signOutGate = Completer<void>();
    final logout = users.logout();
    // Sign-out on Firebase is still pending, but private state is already empty.
    expect(records.patients, isEmpty);
    expect(records.appointments, isEmpty);
    expect(appointments.appointments, isEmpty);
    expect(catalog.favorites, isEmpty);
    expect(content.notifications, isEmpty);
    expect(content.home, isNull);
    expect(content.unreadCount, 0);
    expect(catalog.services, isNotEmpty);
    expect(catalog.loaded, isTrue);
    auth.signOutGate!.complete();
    await logout;
    auth.emit('A');
    records.syncPatients(profile('A'), []);
    auth.emit(
        'B'); // Same email, different UID must still be a different session.
    expect(users.uid, 'B');
    users.signInDemo('stale-A@example.test');
    expect(users.account.email, auth.currentEmail);
    expect(records.patients, isEmpty);
    expect(profiles.profile, isNull);
    session.dispose();
    content.dispose();
    catalog.dispose();
    appointments.dispose();
    profiles.dispose();
    records.dispose();
    users.dispose();
    await auth.events.close();
  });
  test('Mock sessions reset demo presentation without enabling content HTTP',
      () async {
    final auth = IdentityAuth();
    final users = UserProvider(auth: auth);
    final patients = PatientDataProvider();
    final profiles = ProfileProvider(service: DeferredProfile());
    final appointments = AppointmentsProvider(service: DeferredBookings());
    final catalog = FakeCatalogBackend().provider();
    final backend = fixture.Backend();
    final content = backend.provider();
    final session = PrivateSession(
        users: users,
        patients: patients,
        profiles: profiles,
        appointments: appointments,
        catalog: catalog,
        content: content,
        apiMode: false);
    auth.emit('A');
    patients.applyAccountProfile(
        name: 'Private A', phone: '', dateOfBirth: null);
    auth.emit('B');
    expect(patients.primaryPatient.fullName, isNot('Private A'));
    expect(patients.patients, isNotEmpty);
    expect(patients.appointments, isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(backend.requests, isEmpty);
    session.dispose();
    content.dispose();
    catalog.dispose();
    appointments.dispose();
    profiles.dispose();
    patients.dispose();
    users.dispose();
    auth.emit('C');
    await auth.events.close();
  });
  test('stale profile read and save cannot restore A after clear', () async {
    final service = DeferredProfile();
    final p = ProfileProvider(service: service);
    final old = p.loadProfile();
    p.clear();
    final fresh = p.loadProfile();
    service.pending[1].complete(profile('B'));
    await fresh;
    service.pending[0].complete(profile('A'));
    await old;
    expect(p.profile!.id, 'B');
    final save = p.saveProfile(fullName: 'old name', phone: '');
    p.clear();
    service.writes.single.complete();
    await save;
    expect(p.profile, isNull);
    p.dispose();
  });
  test('profile requests complete out of order; last-started request wins',
      () async {
    final service = DeferredProfile();
    final p = ProfileProvider(service: service);
    final old = p.loadProfile();
    final fresh = p.loadProfile();
    service.pending[1].complete(profile('new'));
    await fresh;
    service.pending[0].complete(profile('old'));
    await old;
    expect(p.profile!.id, 'new');
    p.dispose();
  });
  test('old profile errors cannot clear B loading or error state', () async {
    final service = DeferredProfile();
    final p = ProfileProvider(service: service);
    final old = p.loadProfile();
    p.clear();
    final fresh = p.loadProfile();
    service.pending[0].completeError(StateError('old'));
    await old;
    expect(p.profileLoading, isTrue);
    expect(p.profileError, isNull);
    service.pending[1].complete(profile('B'));
    await fresh;
    p.dispose();
  });
  test('late appointments and old sync callbacks are rejected', () async {
    final service = DeferredBookings();
    final p = AppointmentsProvider(service: service);
    final data = PatientDataProvider(seedDemo: false);
    final generation = data.sessionGeneration;
    final old = p.load();
    p.clear();
    data.clearPrivateState();
    final fresh = p.load();
    service.pending[1].complete([appointment('B')]);
    await fresh;
    service.pending[0].complete([appointment('A')]);
    await old;
    expect(p.appointments.single.accountId, 'B');
    data.replaceAppointments([appointment('A')], generation: generation);
    data.syncPatients(profile('A'), [], generation: generation);
    expect(data.appointments, isEmpty);
    expect(data.patients, isEmpty);
    p.dispose();
    data.dispose();
  });
  test('late reads after disposal do not mutate or notify', () async {
    final service = DeferredProfile();
    final p = ProfileProvider(service: service);
    var notifications = 0;
    p.addListener(() => notifications++);
    final job = p.loadProfile();
    p.dispose();
    final before = notifications;
    service.pending.single.complete(profile('A'));
    await job;
    expect(p.profile, isNull);
    expect(notifications, before);
    final bookings = DeferredBookings();
    final a = AppointmentsProvider(service: bookings);
    final load = a.load();
    a.dispose();
    bookings.pending.single.completeError(const ApiException('old'));
    await load;
    expect(a.appointments, isEmpty);
  });
  test('favorites late reads, failures and writes cannot cross generations',
      () async {
    final service = DeferredFavorites();
    final c = CatalogProvider(service: service);
    final old = c.loadFavorites();
    c.clear();
    final fresh = c.loadFavorites();
    service.reads[0].completeError(StateError('A failed'));
    await old;
    expect(c.favoritesLoading, isTrue);
    expect(c.favoritesError, isNull);
    service.reads[1].complete(
        [const Favorite(id: 'article_B', type: 'article', itemId: 'B')]);
    await fresh;
    final write = c.toggleFavorite('article', 'A');
    c.clear();
    service.write.complete();
    await write;
    expect(c.favorites, isEmpty);
    c.dispose();
  });
  test('favorites completion after dispose cannot notify or mutate', () async {
    final service = DeferredFavorites();
    final c = CatalogProvider(service: service);
    final old = c.loadFavorites();
    c.dispose();
    service.reads[0]
        .complete([const Favorite(id: 'A', type: 'article', itemId: 'A')]);
    await old;
    expect(c.favorites, isEmpty);
  });
  group('API medical state', () {
    test('A response after logout and B login cannot replace B records',
        () async {
      final service = DeferredRecords();
      final p = PatientDataProvider(recordsService: service, seedDemo: false);
      p.syncPatients(profile('A'), []);
      final old = p.loadRecords();
      p.clearPrivateState();
      p.syncPatients(profile('B'), []);
      final fresh = p.loadRecords();
      service.pending[1].complete([
        {'id': 'visit-B', 'patientId': 'B'}
      ]);
      await fresh;
      service.pending[0].complete([
        {'id': 'visit-A', 'patientId': 'A'}
      ]);
      await old;
      expect(p.visits.single.id, 'visit-B');
      expect(p.recordsError, isNull);
      p.dispose();
    });
    test('old failure leaves B loading unchanged, re-login A loads fresh data',
        () async {
      final service = DeferredRecords();
      final p = PatientDataProvider(recordsService: service, seedDemo: false);
      p.syncPatients(profile('A'), []);
      final old = p.loadRecords();
      p.clearPrivateState();
      p.syncPatients(profile('B'), []);
      final fresh = p.loadRecords();
      service.pending[0].completeError(StateError('old failure'));
      await old;
      expect(p.recordsLoading, isTrue);
      expect(p.recordsError, isNull);
      service.pending[1].complete([]);
      await fresh;
      p.clearPrivateState();
      p.syncPatients(profile('A'), []);
      final again = p.loadRecords();
      expect(p.visits, isEmpty);
      service.pending[2].complete([]);
      await again;
      expect(service.pending.length, 3);
      p.dispose();
    });
    test('medical requests out of order and disposal are safe', () async {
      final service = DeferredRecords();
      final p = PatientDataProvider(recordsService: service, seedDemo: false);
      p.syncPatients(profile('B'), []);
      final old = p.loadRecords();
      final fresh = p.loadRecords();
      service.pending[1].complete([
        {'id': 'new', 'patientId': 'B'}
      ]);
      await fresh;
      service.pending[0].complete([
        {'id': 'old', 'patientId': 'B'}
      ]);
      await old;
      expect(p.visits.single.id, 'new');
      final load = p.loadRecords();
      p.dispose();
      service.pending[2].completeError(const ApiException('after dispose'));
      await load;
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);
  testWidgets('API UI removes A snapshots while B profile is still loading',
      (tester) async {
    final auth = IdentityAuth();
    final users = UserProvider(auth: auth);
    auth.emit('A');
    final service = DeferredProfile();
    final profiles = ProfileProvider(service: service);
    final medical = DeferredRecords();
    final patients =
        PatientDataProvider(recordsService: medical, seedDemo: false);
    final booking = DeferredBookings();
    final appointments = AppointmentsProvider(service: booking);
    final catalog = FakeCatalogBackend().provider();
    final content = fixture.Backend().provider();
    final session = PrivateSession(
        users: users,
        patients: patients,
        profiles: profiles,
        appointments: appointments,
        catalog: catalog,
        content: content);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: users),
          ChangeNotifierProvider.value(value: profiles),
          ChangeNotifierProvider.value(value: patients),
          ChangeNotifierProvider.value(value: appointments),
          ChangeNotifierProvider.value(value: catalog),
          ChangeNotifierProvider.value(value: content),
        ],
        child: Consumer<UserProvider>(
            builder: (_, u, __) => App(
                key: ValueKey(u.sessionGeneration),
                signedIn: u.isAuthenticated))));
    await tester.pump();
    service.pending[0].complete(profile('A'));
    await tester.pump();
    medical.pending[0].complete([]);
    await tester.pump();
    booking.pending[0].complete([appointment('A')]);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsWidgets);
    auth.emit('B');
    expect(patients.patients, isEmpty);
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(patients.appointments, isEmpty);
    // Dispose with B's profile still in flight; its later failure must be harmless.
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    content.dispose();
    catalog.dispose();
    appointments.dispose();
    profiles.dispose();
    patients.dispose();
    users.dispose();
    service.pending.last.completeError(const ApiException('B after dispose'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await auth.events.close();
  }, skip: AppConfig.current.dataSource != DataSource.api);
}
