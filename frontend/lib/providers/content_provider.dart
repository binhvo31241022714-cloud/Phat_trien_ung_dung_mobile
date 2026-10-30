import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/api_client.dart';
import '../data/models/article.dart';
import '../data/services/content_service.dart';
import 'user_provider.dart';
import 'catalog_provider.dart';

/// Module 4 state. Session generations prevent old responses from crossing accounts.
class ContentProvider extends ChangeNotifier {
  final ContentService service;
  ContentProvider({ContentService? service})
      : service = service ?? ContentService();
  VoidCallback? _unbind;
  void bindUser(UserProvider users, CatalogProvider catalog) {
    void changed() {
      final account = users.isAuthenticated ? users.uid : null;
      if (account != _account) {
        catalog.clear();
        setAccount(account);
      }
    }

    users.addListener(changed);
    _unbind = () => users.removeListener(changed);
    setAccount(users.isAuthenticated ? users.uid : null);
  }

  int _notificationRevision = 0;
  int _session = 0;
  String? _account;
  bool _disposed = false;
  final Map<String, Future<void>> _jobs = {};
  final Map<String, String> errors = {};
  final Set<String> loaded = {};
  List<Article> articles = [];
  final Map<String, Article> details = {};
  List<ContentNotification> notifications = [];
  ContentHome? home;
  int unreadCount = 0;
  bool get signedIn => _account != null;
  bool loading(String key) => _jobs.containsKey(key);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setAccount(String? account) {
    if (_account == account) return;
    final refreshArticles = loaded.contains('articles') || loading('articles');
    final refreshNotifications =
        loaded.contains('notifications') || loading('notifications');
    final detailIds = <String>{
      ...details.keys,
      ..._jobs.keys
          .where((key) => key.startsWith('article:'))
          .map((key) => key.substring(8))
    };
    _account = account;
    _session++;
    _notificationRevision++;
    _appointmentSignature = null;
    _jobs.clear();
    errors.clear();
    loaded.clear();
    details.clear();
    articles = [];
    notifications = [];
    home = null;
    unreadCount = 0;
    final generation = _session;
    // Called from provider lifecycle; notify outside the widget build.
    scheduleMicrotask(() {
      if (!_current(generation)) return;
      _notify();
      if (signedIn) {
        if (refreshArticles) {
          unawaited(loadArticles());
        }
        for (final id in detailIds) {
          unawaited(loadArticle(id));
        }
        unawaited(loadHome());
        unawaited(loadUnread());
        if (refreshNotifications) unawaited(loadNotifications());
      }
    });
  }

  Future<void> _load(String key, Future<void> Function(int) work) {
    if (_disposed) return Future.value();
    if (_jobs.containsKey(key)) return _jobs[key]!;
    final session = _session;
    final done = Completer<void>();
    _jobs[key] = done.future;
    errors.remove(key);
    _notify();
    () async {
      try {
        await work(session);
        if (session == _session && !_disposed) loaded.add(key);
      } catch (e) {
        if (session == _session && !_disposed) {
          errors[key] = e is ApiException
              ? e.message
              : 'Không thể tải dữ liệu. Vui lòng thử lại.';
        }
      } finally {
        if (session == _session && !_disposed) {
          _jobs.remove(key);
          _notify();
        }
        done.complete();
      }
    }();
    return done.future;
  }

  bool _current(int s) => s == _session && !_disposed;
  String? _appointmentSignature;
  void appointmentsChanged(String signature) {
    final previous = _appointmentSignature;
    _appointmentSignature = signature;
    if (previous == null || previous == signature || !signedIn) return;
    scheduleMicrotask(() {
      if (!_disposed && signedIn) {
        unawaited(refreshHome());
        unawaited(loadUnread());
      }
    });
  }

  Future<void> refreshHome() async {
    final session = _session;
    if (loading('home')) await _jobs['home'];
    if (_current(session) && signedIn) await loadHome();
  }

  Future<void> loadArticles() => _load('articles', (s) async {
        final value = await service.articles();
        if (_current(s)) articles = value;
      });
  Future<void> loadArticle(String id) => _load('article:$id', (s) async {
        final value = await service.article(id);
        if (value.id != id) {
          throw const ApiException('Mã bài viết trả về không khớp yêu cầu.');
        }
        if (_current(s)) details[id] = value;
      });
  Future<void> loadHome() async {
    if (!signedIn) return;
    await _load('home', (s) async {
      final value = await service.home();
      if (_current(s)) home = value;
    });
  }

  Future<void> loadUnread() async {
    if (!signedIn) return;
    await _load('unread', (s) async {
      final revision = _notificationRevision;
      final value = await service.unreadCount();
      if (_current(s) && revision == _notificationRevision) unreadCount = value;
    });
  }

  Future<void> loadNotifications() async {
    if (!signedIn) return;
    await _load('notifications', (s) async {
      final revision = _notificationRevision;
      final values =
          await Future.wait<dynamic>([service.notifications(), loadUnread()]);
      if (_current(s) && errors['unread'] != null) {
        throw ApiException(errors['unread']!);
      }
      if (_current(s) && revision == _notificationRevision) {
        notifications = values[0] as List<ContentNotification>;
      }
    });
  }

  Future<void> markRead(String id) async {
    if (!signedIn) return;
    await _load('read', (s) async {
      await service.markRead(id);
      if (!_current(s)) return;
      _notificationRevision++;
      final wasUnread = notifications.any((n) => n.id == id && !n.isRead);
      notifications = [
        for (final n in notifications) n.id == id ? n.read() : n
      ];
      if (wasUnread && unreadCount > 0) unreadCount--;
    });
  }

  Future<void> readAll() async {
    if (!signedIn) return;
    await _load('read', (s) async {
      await service.readAll();
      if (_current(s)) {
        _notificationRevision++;
        notifications = notifications.map((n) => n.read()).toList();
        unreadCount = 0;
      }
    });
  }

  @override
  void dispose() {
    _unbind?.call();
    _disposed = true;
    _session++;
    super.dispose();
  }
}
