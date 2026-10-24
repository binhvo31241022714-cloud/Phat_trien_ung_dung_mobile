import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nơi lưu tùy chọn trên máy (ngôn ngữ, nhận thông báo).
abstract interface class SettingsStore {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

/// Lưu thật xuống máy bằng shared_preferences, mở lại app vẫn còn.
class SharedPrefsSettingsStore implements SettingsStore {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<bool?> getBool(String key) async => (await _prefs).getBool(key);

  @override
  Future<void> setBool(String key, bool value) async {
    // Lưu lỗi thì chỉ ghi log: tùy chọn vẫn đúng trong lần mở app này.
    try {
      await (await _prefs).setBool(key, value);
    } catch (e) {
      debugPrint('Không lưu được tùy chọn $key: $e');
    }
  }

  @override
  Future<String?> getString(String key) async => (await _prefs).getString(key);

  @override
  Future<void> setString(String key, String value) async {
    try {
      await (await _prefs).setString(key, value);
    } catch (e) {
      debugPrint('Không lưu được tùy chọn $key: $e');
    }
  }
}

/// Lưu trong bộ nhớ, dùng cho test (không cần plugin của máy).
class MemorySettingsStore implements SettingsStore {
  final Map<String, Object> values;
  MemorySettingsStore([Map<String, Object>? values]) : values = values ?? {};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}
