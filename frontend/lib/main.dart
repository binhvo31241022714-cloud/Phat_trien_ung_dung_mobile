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
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: users),
        ChangeNotifierProvider(create: (_) => PatientDataProvider()),
        ChangeNotifierProvider(
            create: (_) => ProfileProvider(service: profileService)),
        ChangeNotifierProvider(
            create: (_) => CatalogProvider(service: catalogService)),
        ChangeNotifierProvider(
            create: (_) => AppointmentsProvider(service: bookingService)),
      ],
      child: App(signedIn: users.isAuthenticated),
    ),
  );
}
