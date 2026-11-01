import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/media/photo_picker.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/media_service.dart';
import 'package:frontend/features/shared/media_image.dart';
import 'package:frontend/features/shared/person_avatar.dart';
import 'package:frontend/features/me/me_widgets.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'media_photos_api_test.dart' show MediaServer, png;
import 'module4_test.dart' as content_fixture;
import 'support/fake_auth_service.dart';

// All HTTP/auth uses the existing in-memory fixtures; production main() is never run.
void main() {
  late AppConfig previousConfig;
  late MediaService previousMedia;
  late MediaServer server;
  late ProfileProvider profile;
  setUp(() {
    previousConfig = AppConfig.current;
    previousMedia = MediaService.shared;
    AppConfig.current = AppConfig.fromValues(
        source: 'api', baseUrl: 'http://fake.invalid:3000');
    MediaCache.clear();
    server = MediaServer();
    profile = server.profile();
    MediaService.shared = server.media();
  });
  tearDown(() {
    profile.dispose();
    MediaCache.clear();
    MediaService.shared = previousMedia;
    AppConfig.current = previousConfig;
  });
  final avatar = find.byKey(const ValueKey('home-avatar'));
  Finder images() => find.descendant(of: avatar, matching: find.byType(Image));
  Finder fallback() =>
      find.descendant(of: avatar, matching: find.byIcon(Icons.person_rounded));
  Future<void> mount(WidgetTester t, {bool settle = true}) async {
    t.view.physicalSize = const Size(430, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final backend = content_fixture.Backend();
    final content = await content_fixture.ready(backend);
    final catalog = backend.catalog();
    final data = PatientDataProvider();
    final users = UserProvider(auth: FakeAuthService());
    addTearDown(content.dispose);
    addTearDown(catalog.dispose);
    addTearDown(data.dispose);
    addTearDown(users.dispose);
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: profile),
          ChangeNotifierProvider.value(value: content),
          ChangeNotifierProvider.value(value: catalog),
          ChangeNotifierProvider.value(value: data),
          ChangeNotifierProvider.value(value: users),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Column(children: [
          Consumer<ProfileProvider>(
              builder: (_, p, child) =>
                  MeAvatar(mediaId: p.profile?.avatarMediaId)),
          const Expanded(child: HomeScreen()),
        ])))));
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
    }
  }

  testWidgets('no avatar: original Home fallback, name and appointment remain',
      (t) async {
    await profile.loadProfile();
    await mount(t);
    expect(fallback(), findsOneWidget);
    expect(images(), findsNothing);
    expect(find.text('Chủ tài khoản'), findsOneWidget);
    expect(server.mediaCalls, 0);
  });

  testWidgets(
      'upload, replace and remove synchronize Home and Profile without login',
      (t) async {
    await profile.loadProfile();
    await mount(t);
    for (final expectedId in ['m1', 'm2']) {
      expect(await profile.changeMyAvatar(PickedImage.fromBytes(png)), isNull);
      await t.pumpAndSettle();
      expect(t.widget<PersonAvatar>(avatar).mediaId, expectedId);
      expect(t.widget<MeAvatar>(find.byType(MeAvatar)).mediaId, expectedId);
      expect(images(), findsOneWidget);
      expect(fallback(), findsNothing);
      if (expectedId == 'm2') {
        expect(find.byKey(const ValueKey('person-avatar-m1')), findsNothing);
      }
      // Both widgets reuse the authenticated shared cache, one GET per new ID.
      expect(
          server.requests.where((r) => r.url.path == '/api/media/$expectedId'),
          hasLength(1));
    }
    expect(await profile.changeMyAvatar(null), isNull);
    await t.pumpAndSettle();
    expect(t.widget<MeAvatar>(find.byType(MeAvatar)).mediaId, isNull);
    expect(fallback(), findsOneWidget);
    expect(images(), findsNothing);
    expect(find.text('Chủ tài khoản'), findsOneWidget);
  });

  testWidgets('existing saved avatar loads through authenticated media service',
      (t) async {
    server.me['avatarMediaId'] = 'saved';
    await profile.loadProfile();
    await mount(t);
    expect(images(), findsOneWidget);
    expect(server.requests.where((r) => r.url.path == '/api/media/saved'),
        hasLength(1));
    expect(t.takeException(), isNull);
  });

  testWidgets('HTTP failure or invalid image bytes shows safe fallback',
      (t) async {
    server.me['avatarMediaId'] = 'missing';
    await profile.loadProfile();
    await mount(t);
    expect(fallback(), findsOneWidget);
    expect(t.takeException(), isNull);
    MediaCache.clear();
    MediaService.shared = MediaService(
        client: ApiClient(
            client:
                MockClient((_) async => http.Response.bytes([1, 2, 3], 200))));
    server.me['avatarMediaId'] = 'corrupt';
    await profile.loadProfile();
    await t.pumpAndSettle();
    expect(fallback(), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'logout clears Home and switching accounts reloads same media ID without old cache',
      (t) async {
    server.me['avatarMediaId'] = 'shared';
    await profile.loadProfile();
    await mount(t);
    expect(server.mediaCalls, 1);
    profile
        .clear(); // PrivateSession invokes this synchronously on account change/logout.
    await t.pumpAndSettle();
    expect(fallback(), findsOneWidget);
    expect(images(), findsNothing);
    server.me.addAll(
        {'id': 'B', 'fullName': 'Account B', 'avatarMediaId': 'shared'});
    await profile.loadProfile();
    await t.pumpAndSettle();
    expect(server.mediaCalls, 2);
    expect(find.text('Account B'), findsOneWidget);
    expect(images(), findsOneWidget);
  });

  testWidgets('old pending image cannot reappear after session switch',
      (t) async {
    final pending = Completer<http.Response>();
    MediaService.shared = MediaService(
        client: ApiClient(client: MockClient((_) => pending.future)));
    server.me['avatarMediaId'] = 'old';
    await profile.loadProfile();
    await mount(t, settle: false);
    profile.clear();
    server.me
        .addAll({'id': 'B', 'fullName': 'Account B', 'avatarMediaId': null});
    await profile.loadProfile();
    await t.pump();
    pending.complete(
        http.Response.bytes(png, 200, headers: {'content-type': 'image/png'}));
    await t.pumpAndSettle();
    expect(fallback(), findsOneWidget);
    expect(images(), findsNothing);
    expect(find.text('Account B'), findsOneWidget);
  });
}
