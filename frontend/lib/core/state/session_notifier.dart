import 'package:flutter/foundation.dart';

class SessionNotifier extends ChangeNotifier {
  int _sessionGeneration = 0;
  bool _disposed = false;

  int get sessionGeneration => _sessionGeneration;
  bool get isDisposed => _disposed;

  bool isSessionCurrent(int generation) =>
      !_disposed && generation == _sessionGeneration;

  void invalidateSession() {
    if (!_disposed) {
      _sessionGeneration++;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    super.dispose();
  }
}
