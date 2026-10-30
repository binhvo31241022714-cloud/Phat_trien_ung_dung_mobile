import 'package:flutter/foundation.dart';

/// Shared lifetime/generation guard for asynchronous private-state providers.
class SessionNotifier extends ChangeNotifier {
  int _generation = 0;
  bool _disposed = false;
  int get sessionGeneration => _generation;
  bool get isDisposed => _disposed;
  bool isSessionCurrent(int generation) =>
      !_disposed && generation == _generation;
  void invalidateSession() {
    _generation++;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
