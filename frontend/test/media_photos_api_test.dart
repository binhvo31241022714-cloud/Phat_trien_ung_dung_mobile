import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/media/image_compress.dart';
import 'package:frontend/core/media/photo_picker.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/media_service.dart';
import 'package:frontend/data/services/profile_service.dart';
import 'package:frontend/data/services/records_service.dart';
import 'package:frontend/features/me/edit_profile_screen.dart';
import 'package:frontend/features/me/family_form_screen.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/features/records/records_home_screen.dart';
import 'package:frontend/features/records/treatment_photos_screen.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'support/fake_catalog_backend.dart';
import 'package:frontend/features/shared/media_image.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'support/fake_auth_service.dart';

final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Uint8List jpegOf(int size) =>
    Uint8List(size)..setAll(0, [0xff, 0xd8, 0xff, 0xe0]);

/// Chọn ảnh giả: trả ảnh cho trước, ghi lại nguồn đã chọn.
class FakePicker implements PhotoPicker {
  FakePicker(this.result);
  PickedImage? result;
  Object? error;
  final sources = <PhotoSource>[];

  /// Đặt [gate] để giữ lại ở bước "nén" (sau khi chọn xong).
  Completer<void>? gate;
  bool onSelectedCalled = false;
  @override
  Future<PickedImage?> pick(PhotoSource source,
      {void Function()? onSelected}) async {
    sources.add(source);
    if (result != null || error != null) {
      onSelectedCalled = onSelected != null;
      onSelected?.call();
    }
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return result;
  }
}

/// Backend giả cho hồ sơ, ảnh đại diện, media và ảnh liệu trình.
class MediaServer {
  final requests = <http.Request>[];
  Map<String, dynamic> me = {
    'id': 'A',
    'email': 'a@example.com',
    'fullName': 'Chủ tài khoản',
    'phone': '0900000000',
  };
  final family = <Map<String, dynamic>>[
    {'id': 'kid', 'fullName': 'Bé Na', 'relationship': 'Con'}
  ];
  final photos = <Map<String, dynamic>>[];
  int mediaCalls = 0, nextId = 1;
  int? uploadCode;

  http.Response json(Object value, [int code = 200]) =>
      http.Response(jsonEncode(value), code,
          headers: {'content-type': 'application/json; charset=utf-8'});

  late final client = ApiClient(
      baseUrl: 'http://fake.invalid:3000',
      tokenProvider: () => 'token-A',
      client: MockClient((r) async {
        requests.add(r);
        final path = r.url.path;
        if (path == '/api/users/me') return json(me);
        if (path == '/api/family-members') return json(family);
        // Hồ sơ khám, lịch hẹn: trống (tab Hồ sơ tải lại khi đổi người khám).
        if (path.startsWith('/api/patients/') || path == '/api/appointments') {
          return json([]);
        }
        if (path.endsWith('/avatar')) {
          final id = r.method == 'PUT' ? 'm${nextId++}' : null;
          if (path == '/api/users/me/avatar') {
            me = {...me, 'avatarMediaId': id};
          } else {
            final memberId = path.split('/')[3];
            final i = family.indexWhere((m) => m['id'] == memberId);
            family[i] = {...family[i], 'avatarMediaId': id};
          }
          return json({'avatarMediaId': id, 'avatarUrl': id == null ? null : '/api/media/$id'});
        }
        if (path.startsWith('/api/media/')) {
          mediaCalls++;
          if (r.headers['Authorization'] != 'Bearer token-A') {
            return json({'message': 'Chưa đăng nhập'}, 401);
          }
          if (path.endsWith('/missing')) return json({'message': 'Không tìm thấy ảnh'}, 404);
          return http.Response.bytes(png, 200, headers: {'content-type': 'image/png'});
        }
        if (path == '/api/treatments/t1/photos') {
          if (r.method == 'POST') {
            if (uploadCode != null) {
              return json({'message': 'Liệu trình đã đủ 30 ảnh, hãy xóa bớt ảnh cũ'}, uploadCode!);
            }
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            final photo = {
              'id': 'p${nextId++}',
              'phase': body['phase'],
              'type': body['phase'],
              'mediaId': 'pm$nextId',
              'imageUrl': '/api/media/pm$nextId',
              'note': body['note'],
              'canDelete': true,
            };
            photos.add(photo);
            return json(photo, 201);
          }
          return json(photos);
        }
        if (path.startsWith('/api/treatments/t1/photos/') && r.method == 'DELETE') {
          photos.removeWhere((p) => p['id'] == path.split('/').last);
          return json({'message': 'Đã xóa ảnh'});
        }
        return json({'message': 'API không tồn tại'}, 404);
      }));

  MediaService media() => MediaService(client: client);
  ProfileProvider profile() =>
      ProfileProvider(service: ProfileService(client: client), media: media());
  Iterable<http.Request> calls(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path);
}

void main() {
  late AppConfig previousConfig;
  late PhotoPicker previousPicker;
  late MediaService previousMedia;
  late MediaServer server;
  late FakePicker picker;

  setUp(() {
    previousConfig = AppConfig.current;
    previousPicker = PhotoPicker.instance;
    previousMedia = MediaService.shared;
    AppConfig.current = AppConfig.fromValues(
        source: 'api', baseUrl: 'http://fake.invalid:3000');
    server = MediaServer();
    picker = FakePicker(PickedImage.fromBytes(png));
    PhotoPicker.instance = picker;
    MediaService.shared = server.media();
    MediaCache.clear();
  });
  tearDown(() {
    AppConfig.current = previousConfig;
    PhotoPicker.instance = previousPicker;
    MediaService.shared = previousMedia;
    MediaCache.clear();
  });

  Future<ProfileProvider> mountProfile(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(420, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final profile = server.profile();
    await profile.loadProfile();
    await profile.loadFamily();
    await t.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider(
          create: (_) => UserProvider(auth: FakeAuthService())
            ..signInDemo('a@example.com')),
    ], child: MaterialApp(home: page)));
    await t.pumpAndSettle();
    return profile;
  }

  group('PickedImage', () {
    test('nhận PNG và JPEG, gửi base64 kèm mimeType', () {
      expect(PickedImage.fromBytes(png).mimeType, 'image/png');
      final jpeg = PickedImage.fromBytes(jpegOf(100));
      expect(jpeg.mimeType, 'image/jpeg');
      expect(jpeg.toJson()['image'], base64Encode(jpegOf(100)));
    });
    test('từ chối GIF và ảnh quá 700 KB', () {
      expect(() => PickedImage.fromBytes(Uint8List.fromList(utf8.encode('GIF89a....'))),
          throwsA(isA<PhotoPickException>()));
      expect(PickedImage.fromBytes(jpegOf(maxImageBytes)).bytes.length, maxImageBytes);
      expect(() => PickedImage.fromBytes(jpegOf(maxImageBytes + 1)),
          throwsA(isA<PhotoPickException>().having(
              (e) => e.message, 'message', contains('700 KB'))));
    });
  });

  testWidgets('MediaImage tải ảnh kèm token, dùng cache, lỗi thì hiện biểu tượng', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Column(children: [
      SizedBox.square(dimension: 50, child: MediaImage('m1')),
      SizedBox.square(dimension: 50, child: MediaImage('m1')),
      SizedBox.square(dimension: 50, child: MediaImage('missing')),
    ])));
    await t.pumpAndSettle();
    expect(server.mediaCalls, 2); // m1 chỉ tải 1 lần
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('Thông tin cá nhân: Thay ảnh chọn thư viện, PUT ảnh, hiện ảnh mới; Gỡ ảnh gọi DELETE',
      (t) async {
    final profile = await mountProfile(t, const EditProfileScreen());
    expect(find.text('Thay ảnh (demo)'), findsNothing);
    await t.tap(find.byKey(const ValueKey('change-avatar')));
    await t.pumpAndSettle();
    expect(find.text('Gỡ ảnh'), findsNothing); // chưa có ảnh thì không gỡ
    await t.tap(find.text('Chọn từ thư viện'));
    await t.pumpAndSettle();

    expect(picker.sources, [PhotoSource.gallery]);
    final put = server.calls('PUT', '/api/users/me/avatar').single;
    expect(jsonDecode(put.body), {'image': base64Encode(png), 'mimeType': 'image/png'});
    expect(profile.profile?.avatarMediaId, 'm1');
    expect(find.text('Đã cập nhật ảnh đại diện.'), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-m1')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('change-avatar')));
    await t.pumpAndSettle();
    await t.tap(find.text('Gỡ ảnh'));
    await t.pumpAndSettle();
    expect(server.calls('DELETE', '/api/users/me/avatar'), hasLength(1));
    expect(profile.profile?.avatarMediaId, isNull);
    expect(find.text('Đã gỡ ảnh đại diện.'), findsOneWidget);
  });

  testWidgets('ảnh không hợp lệ: báo lỗi, không gọi API', (t) async {
    await mountProfile(t, const EditProfileScreen());
    picker.error = const PhotoPickException('Ảnh quá lớn (tối đa 700 KB), vui lòng chọn ảnh khác.');
    await t.tap(find.byKey(const ValueKey('change-avatar')));
    await t.pumpAndSettle();
    await t.tap(find.text('Chụp ảnh'));
    await t.pumpAndSettle();
    expect(picker.sources, [PhotoSource.camera]);
    expect(find.textContaining('Ảnh quá lớn'), findsOneWidget);
    expect(server.calls('PUT', '/api/users/me/avatar'), isEmpty);
  });

  testWidgets('Sửa người thân: Thay ảnh gọi PUT /api/family-members/:id/avatar', (t) async {
    final profile = await mountProfile(
        t, FamilyFormScreen(member: FamilyMember.fromJson(server.family.first)));
    await t.tap(find.byKey(const ValueKey('change-family-avatar')));
    await t.pumpAndSettle();
    await t.tap(find.text('Chụp ảnh'));
    await t.pumpAndSettle();
    expect(server.calls('PUT', '/api/family-members/kid/avatar'), hasLength(1));
    expect(profile.familyAvatar('kid'), 'm1');
    // Người khám trong Hồ sơ/Đặt lịch nhận ảnh mới khi đồng bộ.
    final data = PatientDataProvider(seedDemo: false)
      ..syncPatients(profile.profile!, profile.family);
    expect(data.patients.firstWhere((p) => p.id == 'kid').avatarMediaId, 'm1');
  });

  group('nén ảnh trước khi gửi', () {
    Uint8List noisyPng(int w, int h) {
      final image = img.Image(width: w, height: h, numChannels: 4);
      for (final p in image) {
        p
          ..r = (p.x * 31 + p.y * 17) % 256
          ..g = (p.x * p.y) % 256
          ..b = (p.y * 13) % 256
          ..a = p.x < 10 ? 0 : 255; // có vùng trong suốt
      }
      return img.encodePng(image);
    }

    test('tệp PNG lớn: thu nhỏ cạnh dài 1024px, chuyển JPEG, dưới 700 KB', () async {
      final big = noisyPng(2400, 1200);
      final picked = await preparePickedBytes(big, alwaysCompress: true);
      expect(picked.mimeType, 'image/jpeg');
      expect(picked.bytes.length, lessThan(maxImageBytes));
      final decoded = img.decodeJpg(picked.bytes)!;
      expect([decoded.width, decoded.height], [maxImageSide, 512]);
      // Vùng trong suốt thành nền trắng, không bị đen.
      expect(decoded.getPixel(1, 300).r, greaterThan(200));
    });

    test('tệp JPEG dọc lớn: cạnh dài (chiều cao) về 1024px', () async {
      final tall = Uint8List.fromList(img.encodeJpg(
          img.Image(width: 1500, height: 3000)..clear(img.ColorRgb8(10, 120, 200)),
          quality: 95));
      final picked = await preparePickedBytes(tall, alwaysCompress: true);
      final decoded = img.decodeJpg(picked.bytes)!;
      expect([decoded.width, decoded.height], [512, maxImageSide]);
    });

    test('ảnh JPEG nhỏ từ camera/thư viện giữ nguyên; PNG thì chuyển JPEG', () async {
      final small = Uint8List.fromList(
          img.encodeJpg(img.Image(width: 200, height: 100), quality: 70));
      expect((await preparePickedBytes(small)).bytes, small);
      expect((await preparePickedBytes(noisyPng(300, 200))).mimeType, 'image/jpeg');
    });

    test('không phải ảnh hoặc ảnh hỏng thì báo lỗi dễ hiểu', () async {
      await expectLater(preparePickedBytes(Uint8List.fromList(utf8.encode('xin chao'))),
          throwsA(isA<PhotoPickException>()));
      final broken = Uint8List.fromList([...png.take(16), 1, 2, 3]);
      await expectLater(preparePickedBytes(broken, alwaysCompress: true),
          throwsA(isA<PhotoPickException>().having(
              (e) => e.message, 'message', contains('Không đọc được ảnh'))));
    });
  });

  testWidgets('bảng chọn ảnh có "Chọn tệp ảnh", dùng trình chọn tệp và gửi ảnh', (t) async {
    final profile = await mountProfile(t, const EditProfileScreen());
    await t.tap(find.byKey(const ValueKey('change-avatar')));
    await t.pumpAndSettle();
    expect(find.text('Chọn tệp ảnh'), findsOneWidget);
    picker.gate = Completer<void>();
    await t.tap(find.text('Chọn tệp ảnh'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    // Chọn xong, đang nén: đã hiện "Đang xử lý ảnh…", chưa gửi lên.
    expect(find.text('Đang xử lý ảnh…'), findsOneWidget);
    expect(server.calls('PUT', '/api/users/me/avatar'), isEmpty);
    picker.gate!.complete();
    await t.pumpAndSettle();
    expect(picker.sources, [PhotoSource.file]);
    expect(picker.onSelectedCalled, isTrue);
    expect(server.calls('PUT', '/api/users/me/avatar'), hasLength(1));
    expect(profile.profile?.avatarMediaId, 'm1');
  });

  testWidgets('tab Hồ sơ: thẻ người khám và ô chọn hiện ảnh đại diện, đổi ảnh cập nhật ngay',
      (t) async {
    t.view.physicalSize = const Size(420, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    server.me = {...server.me, 'avatarMediaId': 'm-me'};
    server.family[0] = {...server.family[0], 'avatarMediaId': 'm-kid'};
    server.family.add({'id': 'grandma', 'fullName': 'Bà Ngoại', 'relationship': 'Bà'});
    final profile = server.profile();
    await profile.loadProfile();
    await profile.loadFamily();
    final data = PatientDataProvider(
        seedDemo: false, recordsService: RecordsService(client: server.client))
      ..syncPatients(profile.profile!, profile.family);
    final catalog = FakeCatalogBackend().provider();
    await catalog.load();
    await t.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
      ChangeNotifierProvider(
          create: (_) => AppointmentsProvider(service: BookingService(client: server.client))),
    ], child: const MaterialApp(home: Scaffold(body: RecordsHomeScreen()))));
    await t.pumpAndSettle();

    Finder cardAvatar(String patientId, String mediaId) => find.descendant(
        of: find.byKey(ValueKey('records-patient-avatar-$patientId')),
        matching: find.byKey(ValueKey('person-avatar-$mediaId')));
    expect(cardAvatar('A', 'm-me'), findsOneWidget);

    // Ô chọn người khám: người có ảnh hiện ảnh, người chưa có giữ biểu tượng.
    await t.tap(find.text('Chủ tài khoản (Bản thân)'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('person-avatar-m-kid')), findsWidgets);
    await t.tap(find.text('Bé Na (Con)').last);
    await t.pumpAndSettle();
    expect(cardAvatar('kid', 'm-kid'), findsOneWidget);

    data.selectPatient('grandma');
    await t.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('records-patient-avatar-grandma')),
            matching: find.byType(MediaImage)),
        findsNothing);

    // Đổi ảnh người thân: đồng bộ người khám (MainShell làm khi family đổi).
    data.selectPatient('kid');
    await profile.changeFamilyAvatar('kid', PickedImage.fromBytes(png));
    data.syncPatients(profile.profile!, profile.family);
    await t.pumpAndSettle();
    expect(cardAvatar('kid', profile.familyAvatar('kid')!), findsOneWidget);

    // Đổi ảnh bản thân: applyAccountProfile mang theo avatarMediaId.
    data.selectPatient('A');
    await profile.changeMyAvatar(PickedImage.fromBytes(png));
    final me = profile.profile!;
    data.applyAccountProfile(
        name: me.fullName,
        phone: me.phone,
        dateOfBirth: me.birthday,
        avatarMediaId: me.avatarMediaId);
    await t.pumpAndSettle();
    expect(cardAvatar('A', me.avatarMediaId!), findsOneWidget);
    // Đổi tên không làm mất ảnh.
    data.applyAccountProfile(
        name: 'Tên mới', phone: me.phone, avatarMediaId: me.avatarMediaId);
    await t.pumpAndSettle();
    expect(data.primaryPatient.avatarMediaId, me.avatarMediaId);
  });

  group('ảnh trước sau điều trị', () {
    const plan = TreatmentPlan(
        id: 't1',
        patientId: 'A',
        title: 'Niềng răng',
        description: '',
        completedVisits: 0,
        totalVisits: 2,
        sessions: [TreatmentSession(id: 't1_s1', title: 'Buổi 1', completed: false)]);

    Future<void> mountPhotos(WidgetTester t, {double height = 1400}) async {
      t.view.physicalSize = Size(420, height);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ChangeNotifierProvider(
          create: (_) => PatientDataProvider(seedDemo: false),
          child: const MaterialApp(home: TreatmentPhotosScreen(plan: plan))));
      await t.pumpAndSettle();
    }

    testWidgets('trống thì hiện "Chưa có ảnh điều trị."; thêm ảnh Sau gắn buổi 1', (t) async {
      await mountPhotos(t);
      expect(find.text('Chưa có ảnh điều trị.'), findsOneWidget);
      expect(find.text('0/30 ảnh'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('add-treatment-photo')));
      await t.pumpAndSettle();
      await t.tap(find.text('Chọn từ thư viện'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sau'));
      await t.tap(find.byType(DropdownButtonFormField<String?>));
      await t.pumpAndSettle();
      await t.tap(find.text('Buổi 1').last);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Sau 1 tháng');
      await t.tap(find.byKey(const ValueKey('confirm-upload-photo')));
      await t.pumpAndSettle();

      final body = jsonDecode(server.calls('POST', '/api/treatments/t1/photos').single.body);
      expect([body['phase'], body['sessionId'], body['note'], body['mimeType']],
          ['after', 't1_s1', 'Sau 1 tháng', 'image/png']);
      expect(find.text('Đã tải ảnh lên.'), findsOneWidget);
      expect(find.text('Sau điều trị (1)'), findsOneWidget);
      expect(find.text('Trước điều trị (0)'), findsOneWidget);
      expect(find.text('1/30 ảnh'), findsOneWidget);
    });

    testWidgets('xem ảnh lớn; ảnh của mình có nút xóa, ảnh cũ/staff thì không', (t) async {
      server.photos.addAll([
        {'id': 'mine', 'phase': 'before', 'mediaId': 'pm1', 'canDelete': true, 'note': 'Ảnh của tôi'},
        {'id': 'legacy', 'type': 'after', 'imageUrl': 'https://x/old.jpg', 'canDelete': false},
      ]);
      await mountPhotos(t);
      expect(find.text('Trước điều trị (1)'), findsOneWidget);
      expect(find.text('Sau điều trị (1)'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('treatment-photo-legacy')));
      await t.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byTooltip('Xóa ảnh'), findsNothing);
      await t.tap(find.byTooltip('Đóng'));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('treatment-photo-mine')));
      await t.pumpAndSettle();
      expect(find.text('Ảnh của tôi'), findsOneWidget);
      await t.tap(find.byTooltip('Xóa ảnh'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xóa'));
      await t.pumpAndSettle();
      expect(server.calls('DELETE', '/api/treatments/t1/photos/mine'), hasLength(1));
      expect(find.text('Đã xóa ảnh.'), findsOneWidget);
      expect(find.text('Trước điều trị (0)'), findsOneWidget);
    });

    testWidgets('máy chủ từ chối (đủ 30 ảnh) thì hiện lời nhắn của máy chủ', (t) async {
      server.uploadCode = 409;
      await mountPhotos(t);
      await t.tap(find.byKey(const ValueKey('add-treatment-photo')));
      await t.pumpAndSettle();
      await t.tap(find.text('Chụp ảnh'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('confirm-upload-photo')));
      await t.pumpAndSettle();
      expect(find.text('Liệu trình đã đủ 30 ảnh, hãy xóa bớt ảnh cũ'), findsOneWidget);
    });

    testWidgets('đủ 30 ảnh thì khóa nút Thêm ảnh', (t) async {
      for (var i = 0; i < 30; i++) {
        server.photos.add({'id': 'p$i', 'phase': 'before', 'imageUrl': 'https://x/$i.jpg'});
      }
      await mountPhotos(t, height: 3000);
      expect(find.text('Đã đủ 30 ảnh'), findsOneWidget);
      final button = t.widget<FilledButton>(find.ancestor(
          of: find.text('Đã đủ 30 ảnh'), matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
    });
  });
}
