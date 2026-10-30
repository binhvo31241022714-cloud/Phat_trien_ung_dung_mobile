import '../models/home_appointment.dart';
import '../models/content_date.dart';
import '../api_client.dart';
import '../models/article.dart';
import '../models/appointment.dart';
import '../models/dental_service.dart';
import '../models/doctor.dart';

class ContentNotification {
  final String id, title, body, type, refId;
  final DateTime? createdAt;
  final bool isRead;
  const ContentNotification(
      {required this.id,
      required this.title,
      required this.body,
      required this.type,
      required this.refId,
      required this.createdAt,
      required this.isRead});
  factory ContentNotification.fromJson(Map<String, dynamic> j) =>
      ContentNotification(
          id: j['id'] is String ? j['id'] : '',
          title: j['title'] is String ? j['title'] : '',
          body: j['body'] is String ? j['body'] : '',
          type: j['type'] is String ? j['type'] : '',
          refId: j['refId'] is String ? j['refId'] : '',
          createdAt: contentDate(j['createdAt']),
          isRead: j['isRead'] == true);
  ContentNotification read() => ContentNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      refId: refId,
      createdAt: createdAt,
      isRead: true);
}

class ContentHome {
  final List<DentalService> services;
  final List<Doctor> doctors;
  final List<Article> articles;
  final Appointment? appointment;
  ContentHome(Map<String, dynamic> j)
      : services = _rows(j['featuredServices'])
            .map((r) => DentalService.fromJson(r))
            .toList(),
        doctors = _rows(j['featuredDoctors']).map(Doctor.fromJson).toList(),
        articles = _rows(j['latestArticles']).map(Article.fromJson).toList(),
        appointment = j['upcomingAppointment'] is Map<String, dynamic>
            ? HomeAppointment.read(j['upcomingAppointment'])
            : null;
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List || value.any((row) => row is! Map<String, dynamic>)) {
    throw const ApiException('Dữ liệu máy chủ trả về không đúng định dạng.');
  }
  return value.cast<Map<String, dynamic>>();
}

class ContentService {
  final ApiClient client;
  ContentService({ApiClient? client}) : client = client ?? api;
  Future<List<Article>> articles() async =>
      _rows(await client.get('/api/articles')).map(Article.fromJson).toList();
  Future<Article> article(String id) async => Article.fromJson(
      await _object('/api/articles/${Uri.encodeComponent(id)}'));
  Future<ContentHome> home() async => ContentHome(await _object('/api/home'));
  Future<List<ContentNotification>> notifications() async =>
      _rows(await client.get('/api/notifications'))
          .map(ContentNotification.fromJson)
          .toList();
  Future<int> unreadCount() async {
    final j = await _object('/api/notifications/unread-count');
    if (j['count'] is! int || j['count'] < 0) {
      throw const ApiException('Số thông báo chưa đọc không hợp lệ.');
    }
    return j['count'];
  }

  Future<void> markRead(String id) async {
    await client
        .patch('/api/notifications/${Uri.encodeComponent(id)}/read', {});
  }

  Future<void> readAll() async {
    await client.patch('/api/notifications/read-all', {});
  }

  Future<Map<String, dynamic>> _object(String path) async {
    final value = await client.get(path);
    if (value is! Map<String, dynamic>) {
      throw const ApiException('Dữ liệu máy chủ trả về không đúng định dạng.');
    }
    return value;
  }
}
