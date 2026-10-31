import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/availability_slot.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/availability_service.dart';
import 'support/fake_catalog_backend.dart';
import 'package:frontend/data/services/booking_service.dart'
    hide AvailabilitySlot;
import 'package:frontend/features/booking/booking_controller.dart';
import 'support/data_source_scope.dart';

class PricingServer {
  final validations = <Completer<http.Response>>[];
  final quotes = <Completer<http.Response>>[];
  bool delayQuotes = false;
  int creates = 0;
  http.Response response(Object value) => http.Response(jsonEncode(value), 200,
      headers: {'content-type': 'application/json'});
  Map<String, dynamic> quote(int amount, {String? code}) => {
        'subtotal': amount,
        'discount': code == null ? 0 : 10,
        'totalPrice': amount - (code == null ? 0 : 10),
        'durationMinutes': 30,
        'voucherCode': code,
      };
  http.Response validated(String code) => response({
        'valid': true,
        'code': code,
        'subtotal': 100,
        'discount': 10,
        'totalPrice': 90,
      });
  late final client = ApiClient(client: MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.url.path == '/api/vouchers/validate') {
      final pending = Completer<http.Response>();
      validations.add(pending);
      return pending.future;
    }
    if (request.url.path == '/api/bookings/quote') {
      if (delayQuotes) {
        final pending = Completer<http.Response>();
        quotes.add(pending);
        return pending.future;
      }
      return response(quote(
          (body['serviceIds'] as List).contains('B') ? 200 : 100,
          code: body['voucherCode'] as String?));
    }
    creates++;
    throw StateError('A pending/stale quote must never submit');
  }));
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late PricingServer server;
  late PatientDataProvider data;
  late BookingController controller;
  setUp(() {
    useDataSourceForTest(DataSource.api);
    server = PricingServer();
    data = PatientDataProvider(seedDemo: false)
      ..syncPatients(
          const UserProfile(id: 'A', email: '', fullName: 'A', phone: ''), []);
    controller = BookingController(data,
        bookingService: BookingService(client: server.client));
    controller.serviceIds.add('A');
    controller.doctorChosen = true;
    controller.doctorId = 'doctor';
    controller.date = DateTime(2099, 1, 1);
    controller.time = '09:00';
    controller.step = 3;
    controller.availabilitySlots = [
      const AvailabilitySlot(
          doctorId: 'doctor',
          doctorName: '',
          date: '2099-01-01',
          startTime: '09:00',
          endTime: '09:30',
          durationMinutes: 30)
    ];
  });
  tearDown(() {
    controller.dispose();
    data.dispose();
    server.client.close();
  });

  test('late voucher for A cannot overwrite newer selection B', () async {
    await controller.refreshQuote();
    final old = controller.applyVoucher('OLD');
    await flush();
    controller.toggleService('B');
    await flush();
    expect(controller.total, 200);
    server.validations.single.complete(server.validated('OLD'));
    expect(await old, isFalse);
    expect(controller.total, 200);
    expect(controller.appliedVoucher, isNull);
    expect(controller.voucherLoading, isFalse);
  });

  test('latest voucher wins even when validations finish out of order',
      () async {
    await controller.refreshQuote();
    final old = controller.applyVoucher('OLD');
    await flush();
    final latest = controller.applyVoucher('NEW');
    await flush();
    server.validations[1].complete(server.validated('NEW'));
    expect(await latest, isTrue);
    server.validations[0].complete(server.validated('OLD'));
    expect(await old, isFalse);
    expect(controller.appliedVoucher, 'NEW');
    expect(controller.total, 90);
    expect(controller.quoteReady, isTrue);
  });

  test('old quote cannot overwrite a newer validated voucher quote', () async {
    server.delayQuotes = true;
    final old = controller.refreshQuote();
    await flush();
    final apply = controller.applyVoucher('NEW');
    await flush();
    server.validations.single.complete(server.validated('NEW'));
    await flush();
    server.quotes[1].complete(server.response(server.quote(100, code: 'NEW')));
    expect(await apply, isTrue);
    server.quotes[0].complete(server.response(server.quote(100)));
    await old;
    expect(controller.appliedVoucher, 'NEW');
    expect(controller.total, 90);
  });

  test('validation and final quote both block confirm and direct submit',
      () async {
    await controller.refreshQuote();
    final apply = controller.applyVoucher('NEW');
    await flush();
    expect(controller.quoteReady, isFalse);
    expect(controller.canContinue, isFalse);
    expect(await controller.submit(), isNull);
    server.delayQuotes = true;
    server.validations.single.complete(server.validated('NEW'));
    await flush();
    expect(controller.canContinue, isFalse);
    expect(await controller.submit(), isNull);
    server.quotes.single
        .complete(server.response(server.quote(100, code: 'NEW')));
    expect(await apply, isTrue);
    expect(controller.canContinue, isTrue);
    expect(server.creates, 0);
  });

  test('remove voucher invalidates pending validation', () async {
    final apply = controller.applyVoucher('OLD');
    await flush();
    controller.removeVoucher();
    await flush();
    server.validations.single.complete(server.validated('OLD'));
    expect(await apply, isFalse);
    expect(controller.appliedVoucher, isNull);
    expect(controller.total, 100);
  });

  test('logout ignores late validation and clears private draft', () async {
    final apply = controller.applyVoucher('OLD');
    await flush();
    data.clearPrivateState();
    data.syncPatients(
        const UserProfile(id: 'B', email: '', fullName: 'B', phone: ''), []);
    server.validations.single.complete(server.validated('OLD'));
    expect(await apply, isFalse);
    expect(controller.appliedVoucher, isNull);
    expect(controller.voucherLoading, isFalse);
    expect(controller.time, isNull);
    expect(controller.quoteReady, isFalse);
  });

  test(
      'invalid voucher response cannot publish a price and retry quote recovers',
      () async {
    final apply = controller.applyVoucher('BAD');
    await flush();
    server.validations.single
        .complete(server.response({'valid': false, 'code': 'BAD'}));
    expect(await apply, isFalse);
    expect(controller.voucherError, isNotNull);
    expect(controller.appliedVoucher, isNull);
    await controller.refreshQuote();
    expect(controller.quoteReady, isTrue);
    expect(controller.total, 100);
  });
  test('changing services removes an already applied voucher and reloads price',
      () async {
    final apply = controller.applyVoucher('OLD');
    await flush();
    server.validations.single.complete(server.validated('OLD'));
    expect(await apply, isTrue);
    controller.toggleService('B');
    await flush();
    expect(controller.appliedVoucher, isNull);
    expect(controller.discount, 0);
    expect(controller.total, 200);
  });

  test('new validation failure cannot be undone by old validation success',
      () async {
    final old = controller.applyVoucher('OLD');
    await flush();
    final latest = controller.applyVoucher('NEW');
    await flush();
    server.validations[1].complete(http.Response('{"message":"Expired"}', 400));
    expect(await latest, isFalse);
    server.validations[0].complete(server.validated('OLD'));
    expect(await old, isFalse);
    expect(controller.voucherError, 'Expired');
    expect(controller.appliedVoucher, isNull);
    expect(controller.quoteReady, isFalse);
  });

  test('valid voucher with failed final quote does not enable confirm',
      () async {
    server.delayQuotes = true;
    final apply = controller.applyVoucher('NEW');
    await flush();
    server.validations.single.complete(server.validated('NEW'));
    await flush();
    server.quotes.single.complete(http.Response('{}', 500));
    expect(await apply, isFalse);
    expect(controller.voucherLoading, isFalse);
    expect(controller.canContinue, isFalse);
    expect(controller.appliedVoucher, isNull);
    server.delayQuotes = false;
    await controller.refreshQuote();
    expect(controller.canContinue, isTrue);
  });

  test('inconsistent server quote never becomes a confirmed price', () async {
    server.delayQuotes = true;
    final load = controller.refreshQuote();
    await flush();
    server.quotes.single.complete(server.response({
      'subtotal': 100,
      'discount': 10,
      'totalPrice': 100,
      'durationMinutes': 30,
    }));
    await load;
    expect(controller.quoteReady, isFalse);
    expect(controller.quoteError, isNotNull);
  });

  test('adding a service unsupported by the selected doctor clears that doctor',
      () async {
    final catalog = FakeCatalogBackend().provider();
    await catalog.load();
    final draft = BookingController(data,
        catalog: catalog,
        bookingService: BookingService(client: server.client));
    addTearDown(draft.dispose);
    addTearDown(catalog.dispose);
    draft.serviceIds.add('svc_01');
    draft.chooseDoctor('doc_01');
    expect(draft.doctorChosen, isTrue);
    draft.toggleService('svc_02');
    await flush();
    expect(draft.doctorChosen, isFalse);
    expect(draft.preferredDoctorId, isNull);
    expect(draft.time, isNull);
  });

  test(
      'availability from the previous session cannot restore slots after logout',
      () async {
    final pending = Completer<http.Response>();
    final client = ApiClient(client: MockClient((_) => pending.future));
    final draft = BookingController(data,
        bookingService: BookingService(client: server.client),
        availabilityService: AvailabilityService(client: client));
    addTearDown(draft.dispose);
    draft.serviceIds.add('A');
    draft.date = DateTime(2099, 1, 1);
    final load = draft.loadAvailability();
    await flush();
    data.clearPrivateState();
    pending.complete(server.response({
      'slots': [
        {
          'doctorId': 'doctor',
          'doctorName': '',
          'date': '2099-01-01',
          'startTime': '09:00',
          'endTime': '09:30',
          'durationMinutes': 30,
        }
      ]
    }));
    await load;
    expect(draft.availabilitySlots, isEmpty);
    expect(draft.availabilityLoading, isFalse);
    client.close();
  });
  test(
      'catalog refresh cannot change the frozen doctor of an uncertain request',
      () async {
    final backend = FakeCatalogBackend();
    final catalog = backend.provider();
    await catalog.load();
    final draft = BookingController(data,
        catalog: catalog,
        bookingService: BookingService(client: server.client));
    addTearDown(draft.dispose);
    addTearDown(catalog.dispose);
    draft.serviceIds.add('svc_01');
    draft.chooseDoctor('doc_01');
    draft.awaitingRetry = true;
    backend.doctors.clear();
    await catalog.load();
    expect(draft.preferredDoctorId, 'doc_01');
    expect(draft.doctorChosen, isTrue);
    expect(draft.awaitingRetry, isTrue);
  });
}
