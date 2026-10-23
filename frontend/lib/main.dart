import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/providers/patient_data_provider.dart';
import 'providers/user_provider.dart';

void main() {
  assert(() {
    debugPrint('DATA_SOURCE=${AppConfig.current.dataSource.name}; '
        'API scope: legacy users read. Patient flows and authentication remain demo.');
    return true;
  }());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => PatientDataProvider()),
      ],
      child: const App(),
    ),
  );
}
