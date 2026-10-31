import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/app/private_session.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/data/services/catalog_service.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/data/services/profile_service.dart';
import 'package:frontend/data/services/records_service.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'fake_auth_service.dart';

/// HTTP-only fixture: production providers/services and PrivateSession, no
/// provider subclasses or direct store assignments. No Firebase/network access.
class ApiAppFixture {
  static const email = 'api-fixture@example.com';
  static const owner = 'demo:$email';
  final requests = <http.Request>[];
  final unexpected = <String>[];
  final me = <String, dynamic>{
    'id': owner,
    'fullName': 'Tài khoản API',
    'email': email,
    'phone': '0901234567'
  };
  final family = <Map<String, dynamic>>[
    {'id': 'relative-api', 'fullName': 'Người thân API', 'relationship': 'Con'}
  ];
  final services = <Map<String, dynamic>>[
    {
      'id': 'service-api',
      'name': 'Dịch vụ API',
      'price': 125000,
      'durationMinutes': 30,
      'description': 'Mô tả API'
    },
  ];
  final doctors = <Map<String, dynamic>>[
    {
      'id': 'doctor-api',
      'name': 'Bác sĩ API',
      'serviceIds': ['service-api'],
      'specialty': 'Nha khoa'
    }
  ];
  final articles = <Map<String, dynamic>>[
    {
      'id': 'article-api',
      'title': 'Bài viết API',
      'summary': 'Tóm tắt API',
      'content': 'Nội dung API',
      'category': 'Kiểm thử',
      'publishedAt': '2026-10-01T00:00:00Z'
    }
  ];
  final favorites = <Map<String, dynamic>>[];
  final appointmentRows = <Map<String, dynamic>>[];
  final visits = <Map<String, dynamic>>[];
  final invoices = <Map<String, dynamic>>[];
  final prescriptions = <Map<String, dynamic>>[];
  final treatments = <Map<String, dynamic>>[];
  final sessions = <Map<String, dynamic>>[];
  final followups = <Map<String, dynamic>>[];
  final notices = <Map<String, dynamic>>[];
  int? articleFailure;
  late final client = ApiClient(
      baseUrl: 'http://fixture.invalid:3000', client: MockClient(_request));
  late final users = UserProvider(auth: FakeAuthService());
  late final records = PatientDataProvider(
      seedDemo: false, recordsService: RecordsService(client: client));
  late final profiles =
      ProfileProvider(service: ProfileService(client: client));
  late final catalog = CatalogProvider(service: CatalogService(client: client));
  late final appointments =
      AppointmentsProvider(service: BookingService(client: client));
  late final content = ContentProvider(service: ContentService(client: client));
  late final session = PrivateSession(
      users: users,
      patients: records,
      profiles: profiles,
      appointments: appointments,
      catalog: catalog,
      content: content,
      apiMode: true);

  ApiAppFixture({bool signedIn = true}) {
    if (signedIn) users.signInDemo(email);
    session; // Wire exactly the same session graph as main.dart before mounting.
    appointmentRows.add(appointment('appointment-api'));
    for (final patient in [owner, 'relative-api']) {
      final id = patient == owner ? 'visit-api' : 'visit-relative';
      visits.add({
        'id': id,
        'accountId': owner,
        'patientId': patient,
        'appointmentId': 'completed-$id',
        'visitedAt': '2026-10-01T02:00:00Z',
        'serviceIds': ['service-api'],
        'doctorId': 'doctor-api',
        'diagnosis': 'Chẩn đoán $id',
        'result': 'Kết quả $id',
        'note': 'Dặn dò $id'
      });
      prescriptions.add({
        'id': 'rx-$id',
        'patientId': patient,
        'visitId': id,
        'issuedAt': '2026-10-01T02:30:00Z',
        'items': [],
        'instructions': 'Dặn dò đơn thuốc'
      });
      invoices.add({
        'id': 'invoice-$id',
        'patientId': patient,
        'visitId': id,
        'appointmentId': 'completed-$id',
        'issuedAt': '2026-10-01T02:30:00Z',
        'totalAmount': 125000
      });
      treatments.add({
        'id': 'treatment-$id',
        'patientId': patient,
        'name': 'Liệu trình $id',
        'totalSessions': 2
      });
      sessions.add({
        'id': 'session-$id',
        'treatmentId': 'treatment-$id',
        'patientId': patient,
        'sessionNumber': 1,
        'status': 'completed',
        'visitId': id
      });
      followups.add({
        'id': 'followup-$id',
        'patientId': patient,
        'serviceId': 'service-api',
        'doctorId': 'doctor-api',
        'scheduledAt': '2099-01-03T02:00:00Z',
        'reason': 'Tái khám API'
      });
    }
    notices.addAll([
      {
        'id': 'notice-api',
        'title': 'Thông báo lịch API',
        'body': 'Lịch đã xác nhận',
        'type': 'appointment_confirmed',
        'refId': 'appointment-api',
        'isRead': false
      },
      {
        'id': 'system-api',
        'title': 'Thông báo hệ thống API',
        'body': 'Hệ thống API',
        'type': 'system',
        'refId': '',
        'isRead': false
      }
    ]);
  }

  Map<String, dynamic> appointment(String id, {String patient = owner}) => {
        'id': id,
        'accountId': owner,
        'patientId': patient,
        'doctorId': 'doctor-api',
        'serviceIds': ['service-api'],
        'date': '2099-01-02',
        'startTime': '09:00',
        'endTime': '09:30',
        'status': 'confirmed',
        'totalPrice': 125000,
      };

  http.Response _json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status,
          headers: {'content-type': 'application/json'});
  http.Response _detail(List<Map<String, dynamic>> rows, String id) {
    final row = rows.where((r) => r['id'] == id);
    return row.isEmpty
        ? _json({'message': 'Không tìm thấy'}, 404)
        : _json(row.first);
  }

  Future<http.Response> _request(http.Request request) async {
    requests.add(request);
    final p = request.url.pathSegments;
    final path = request.url.path;
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    if (path == '/api/users/me') {
      if (request.method == 'PATCH') me.addAll(body);
      return _json(me);
    }
    if (path == '/api/family-members') return _json(family);
    final catalogs = {
      'services': services,
      'doctors': doctors,
      'combos': <Map<String, dynamic>>[]
    };
    if (p.length >= 2 && catalogs.containsKey(p[1])) {
      return p.length == 2
          ? _json(catalogs[p[1]]!)
          : _detail(catalogs[p[1]]!, p[2]);
    }
    if (p.length >= 2 && p[1] == 'articles') {
      if (articleFailure != null) {
        return _json({'message': 'Bài viết tạm lỗi'}, articleFailure!);
      }
      return p.length == 2 ? _json(articles) : _detail(articles, p[2]);
    }
    if (path == '/api/favorites') {
      if (request.method == 'POST') {
        final id = '${body['type']}_${body['itemId']}';
        favorites.removeWhere((r) => r['id'] == id);
        favorites.add({'id': id, ...body});
        return _json({'id': id}, 201);
      }
      return _json(favorites);
    }
    if (p.length == 3 && p[1] == 'favorites' && request.method == 'DELETE') {
      favorites.removeWhere((r) => r['id'] == p[2]);
      return _json({'message': 'Đã xóa'});
    }
    if (path == '/api/home') {
      final active = appointmentRows
          .where((a) => ['booked', 'confirmed'].contains(a['status']))
          .toList();
      return _json({
        'featuredServices': services,
        'featuredDoctors': doctors,
        'latestArticles': articles,
        'upcomingAppointment': active.isEmpty ? null : active.first
      });
    }
    if (path == '/api/appointments') return _json(appointmentRows);
    if (p.length >= 3 && p[1] == 'appointments') {
      if (p.length == 4 && p[3] == 'cancel') {
        appointmentRows.firstWhere((r) => r['id'] == p[2])['status'] =
            'cancelled';
        return _json({'id': p[2], 'status': 'cancelled'});
      }
      return _detail(appointmentRows, p[2]);
    }
    if (path == '/api/notifications/unread-count') {
      return _json(
          {'count': notices.where((n) => n['isRead'] == false).length});
    }
    if (path == '/api/notifications') return _json(notices);
    if (path == '/api/notifications/read-all') {
      for (final row in notices) {
        row['isRead'] = true;
      }
      return _json({'message': 'Đã đọc'});
    }
    if (p.length == 4 && p[1] == 'notifications' && p[3] == 'read') {
      notices.firstWhere((r) => r['id'] == p[2])['isRead'] = true;
      return _json({'id': p[2], 'isRead': true});
    }
    if (p.length == 4 && p[1] == 'patients') {
      final tables = {
        'visits': visits,
        'invoices': invoices,
        'treatments': treatments,
        'follow-ups': followups
      };
      if (tables.containsKey(p[3])) {
        return _json(
            tables[p[3]]!.where((r) => r['patientId'] == p[2]).toList());
      }
    }
    if (p.length >= 3 && p[1] == 'visits') {
      if (p.length == 4 && p[3] == 'prescriptions') {
        return _json(prescriptions.where((r) => r['visitId'] == p[2]).toList());
      }
      return _detail(visits, p[2]);
    }
    if (p.length == 3 && p[1] == 'invoices') return _detail(invoices, p[2]);
    if (p.length >= 3 && p[1] == 'treatments') {
      if (p.length == 4 && p[3] == 'sessions') {
        return _json(sessions.where((r) => r['treatmentId'] == p[2]).toList());
      }
      if (p.length == 4 && p[3] == 'photos') return _json([]);
      return _detail(treatments, p[2]);
    }
    if (path == '/api/bookings/quote') {
      final ids = (body['serviceIds'] as List?) ?? [];
      final total = services
          .where((s) => ids.contains(s['id']))
          .fold<int>(0, (sum, s) => sum + (s['price'] as int));
      return _json({
        'subtotal': total,
        'totalPrice': total,
        'discount': 0,
        'durationMinutes': ids.length * 30
      });
    }
    if (path == '/api/availability') return _json({'slots': []});
    unexpected.add('${request.method} $path');
    throw StateError('Unexpected fixture route: ${request.method} $path');
  }

  Future<void> mount(WidgetTester t,
      {double width = 390,
      double height = 900,
      double scale = 1,
      bool app = false,
      Widget? home}) async {
    expect(AppConfig.current.dataSource, DataSource.api);
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: users),
          ChangeNotifierProvider.value(value: records),
          ChangeNotifierProvider.value(value: profiles),
          ChangeNotifierProvider.value(value: catalog),
          ChangeNotifierProvider.value(value: appointments),
          ChangeNotifierProvider.value(value: content),
        ],
        child: app
            ? Consumer<UserProvider>(
                builder: (_, user, __) => App(
                    key: ValueKey(user.sessionGeneration),
                    signedIn: user.isAuthenticated))
            : MaterialApp(
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: home ?? const MainShell())));
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      session.dispose();
      content.dispose();
      appointments.dispose();
      catalog.dispose();
      profiles.dispose();
      records.dispose();
      users.dispose();
      expect(unexpected, isEmpty);
    });
  }
}
