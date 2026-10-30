import 'app/private_session.dart';
import 'providers/content_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/providers/patient_data_provider.dart';
import 'data/services/auth_service.dart';
import 'data/services/booking_service.dart';
import 'data/services/catalog_service.dart';
import 'data/services/profile_service.dart';
import 'data/services/settings_store.dart';
import 'firebase_options.dart';
import 'providers/appointments_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/user_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await startApp(FirebaseAuthService());
}

/// Tách khỏi main() để integration test chạy app với AuthService,
/// ProfileService, CatalogService và BookingService giả.
Future<void> startApp(AuthService auth,
    {ProfileService? profileService,
    CatalogService? catalogService,
    BookingService? bookingService}) async {
  assert(() {
    debugPrint('DATA_SOURCE=${AppConfig.current.dataSource.name}; '
        'API_BASE_URL=${AppConfig.current.apiBaseUrl}; '
        'authentication uses Firebase, patient flows remain demo.');
    return true;
  }());
  final users = UserProvider(auth: auth, settings: SharedPrefsSettingsStore());
  // Đọc tùy chọn đã lưu trên máy (ngôn ngữ, nhận thông báo).
  await users.loadSettings();
  // Còn phiên đăng nhập cũ thì vào thẳng trang chính.
  await users.restoreSession();
  // Initialize/reset session state before any Provider listener is mounted.
  // UID changes after mounting still clear private stores synchronously.
  final patients = PatientDataProvider(
      seedDemo: AppConfig.current.dataSource != DataSource.api);
  final profiles = ProfileProvider(service: profileService);
  final catalog = CatalogProvider(service: catalogService);
  final appointments = AppointmentsProvider(service: bookingService);
  final content = ContentProvider();
  final privateSession = PrivateSession(
      users: users,
      apiMode: AppConfig.current.dataSource == DataSource.api,
      patients: patients,
      profiles: profiles,
      appointments: appointments,
      catalog: catalog,
      content: content);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(
            key: ObjectKey(users), create: (_) => users),
        ChangeNotifierProvider(create: (_) => patients),
        ChangeNotifierProvider(create: (_) => profiles),
        ChangeNotifierProvider(create: (_) => catalog),
        ChangeNotifierProvider(create: (_) => appointments),
        ChangeNotifierProvider(create: (_) => content),
        Provider<PrivateSession>(
          lazy: false,
          create: (_) => privateSession,
          dispose: (_, session) => session.dispose(),
        ),
      ],
      child: Consumer<UserProvider>(
          builder: (_, current, __) => App(
              key: ValueKey(current.sessionGeneration),
              signedIn: current.isAuthenticated)),
    ),
  );
}
