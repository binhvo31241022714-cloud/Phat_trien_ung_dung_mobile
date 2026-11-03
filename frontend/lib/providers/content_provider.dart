import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/state/session_notifier.dart';
import '../data/api_client.dart';
import '../data/mock_data.dart';
import '../data/models/article.dart';
import '../data/services/content_service.dart';
import 'catalog_provider.dart';
import 'user_provider.dart';

typedef HomeContent = ContentHome;

class ContentProvider extends SessionNotifier {
  final ContentService _service;

  ContentProvider({ContentService? service})
      : _service = service ?? ContentService();

  int unreadCount = 0;
  bool signedIn = false;
  HomeContent? home;
  final Map<String, String?> errors = {};
  final Set<String> loaded = {};
  final Set<String> _loading = {};
  final Map<String, Future<void>> _inFlight = {};
  List<Article> articles = const [];
  final Map<String, Article> articleDetails = {};
  List<ContentNotification> notifications = const [];
  UserProvider? _users;
  VoidCallback? _userListener;
  String? _account;

  Map<String, Article> get details => articleDetails;
  bool loading(String key) => _loading.contains(key);

  void setAccount(String? account) {
    if (_account == account) return;
    _account = account;
    signedIn = account != null;
    invalidateSession();
    _clearPrivateState();
    notifyListeners();
  }

  void bindUser(UserProvider users, CatalogProvider catalog) {
    if (identical(_users, users)) return;
    if (_users != null && _userListener != null) {
      _users!.removeListener(_userListener!);
    }
    _users = users;
    _userListener = () => setAccount(users.uid);
    users.addListener(_userListener!);
    setAccount(users.uid);
  }

  Future<void> loadHome() => _request('home', () async {
        if (!signedIn) return;
        final session = sessionGeneration;
        try {
          if (AppConfig.current.dataSource == DataSource.mock) {
            home = HomeContent.fromParts(
                articles: MockData.articles,
                services: MockData.services,
                doctors: MockData.doctors);
          } else {
            final result = await _service.home();
            if (!isSessionCurrent(session)) return;
            home = HomeContent.fromParts(
                articles: result.articles,
                services: result.services,
                doctors: result.doctors,
                appointment: result.appointment);
          }
          loaded.add('home');
          errors.remove('home');
        } catch (e) {
          if (!isSessionCurrent(session)) return;
          errors['home'] = _message(e, 'Không thể tải nội dung trang chủ.');
        }
      });

  Future<void> loadArticles() => _request('articles', () async {
        if (!signedIn) return;
        final session = sessionGeneration;
        try {
          final result = AppConfig.current.dataSource == DataSource.mock
              ? MockData.articles
              : await _service.articles();
          if (!isSessionCurrent(session)) return;
          articles = List.unmodifiable(result);
          loaded.add('articles');
          errors.remove('articles');
        } catch (e) {
          if (!isSessionCurrent(session)) return;
          articles = const [];
          errors['articles'] = _message(e, 'Không thể tải bài viết.');
        }
      });

  Future<void> loadArticle(String id) => _request('article:$id', () async {
        if (!signedIn) return;
        final session = sessionGeneration;
        try {
          final result = AppConfig.current.dataSource == DataSource.mock
              ? MockData.articles.where((a) => a.id == id).firstOrNull
              : await _service.article(id);
          if (!isSessionCurrent(session)) return;
          if (result == null || result.id != id) {
            throw const ApiException('Nội dung bài viết không hợp lệ.');
          }
          articleDetails[id] = result;
          loaded.add('article:$id');
          errors.remove('article:$id');
        } catch (e) {
          if (!isSessionCurrent(session)) return;
          articleDetails.remove(id);
          errors['article:$id'] = _message(e, 'Không thể tải bài viết.');
        }
      });

  Future<void> loadNotifications() => _request('notifications', () async {
        if (!signedIn) return;
        final session = sessionGeneration;
        try {
          final results = await Future.wait([
            _service.notifications(),
            _service.unreadCount(),
          ]);
          if (!isSessionCurrent(session)) return;
          notifications =
              List.unmodifiable(results[0] as List<ContentNotification>);
          unreadCount = results[1] as int;
          loaded.add('notifications');
          errors.remove('notifications');
          errors.remove('unread');
        } catch (e) {
          if (!isSessionCurrent(session)) return;
          errors['notifications'] =
              _message(e, 'Không thể tải thông báo. Vui lòng thử lại.');
          errors['unread'] = errors['notifications'];
        }
      });

  Future<void> loadUnread() => _request('unread', () async {
        if (!signedIn) return;
        final session = sessionGeneration;
        try {
          final count = await _service.unreadCount();
          if (!isSessionCurrent(session)) return;
          unreadCount = count;
          errors.remove('unread');
        } catch (e) {
          if (!isSessionCurrent(session)) return;
          errors['unread'] =
              _message(e, 'Không thể tải số thông báo chưa đọc.');
        }
      });

  Future<void> markRead(String id) => _request('read', () async {
        if (!signedIn) return;
        final session = sessionGeneration;
        try {
          await _service.markRead(id);
          if (!isSessionCurrent(session)) return;
          final index = notifications.indexWhere((n) => n.id == id);
          if (index >= 0 && !notifications[index].isRead) {
            final updated = [...notifications];
            updated[index] = updated[index].read();
            notifications = List.unmodifiable(updated);
            if (unreadCount > 0) unreadCount--;
          }
          errors.remove('read');
        } catch (e) {
          if (!isSessionCurrent(session)) return;
          errors['read'] = _message(e, 'Không thể đánh dấu thông báo đã đọc.');
        }
      });

  Future<void> readAll() => _request('read', () async {
        if (!signedIn) return;
        final session = sessionGeneration;
        try {
          await _service.readAll();
          if (!isSessionCurrent(session)) return;
          notifications = List.unmodifiable(notifications.map((n) => n.read()));
          unreadCount = 0;
          errors.remove('read');
        } catch (e) {
          if (!isSessionCurrent(session)) return;
          errors['read'] = _message(e, 'Không thể đánh dấu thông báo đã đọc.');
        }
      });

  void clear() {
    _account = null;
    signedIn = false;
    invalidateSession();
    _clearPrivateState();
    notifyListeners();
  }

  void appointmentsChanged(String _) {
    if (signedIn) unawaited(loadHome());
  }

  void _clearPrivateState() {
    _inFlight.clear();
    _loading.clear();
    home = null;
    articles = const [];
    articleDetails.clear();
    notifications = const [];
    unreadCount = 0;
    errors.clear();
    loaded.clear();
  }

  Future<void> _request(String key, Future<void> Function() action) {
    final existing = _inFlight[key];
    if (existing != null) return existing;
    _loading.add(key);
    notifyListeners();
    late final Future<void> future;
    future = action().whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
        _loading.remove(key);
        if (!isDisposed) notifyListeners();
      }
    });
    _inFlight[key] = future;
    return future;
  }

  String _message(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;

  @override
  void dispose() {
    if (_users != null && _userListener != null) {
      _users!.removeListener(_userListener!);
    }
    super.dispose();
  }
}
