import '../api_client.dart';

class RecordsService {
  final ApiClient _api;
  RecordsService({ApiClient? client}) : _api = client ?? api;

  Future<List<dynamic>> _list(String path) async {
    final value = await _api.get(path);
    if (value is! List) {
      throw const ApiException('Dữ liệu hồ sơ không đúng định dạng.');
    }
    return value;
  }

  Future<Map<String, dynamic>> _map(String path) async {
    final value = await _api.get(path);
    if (value is! Map<String, dynamic>) {
      throw const ApiException('Dữ liệu hồ sơ không đúng định dạng.');
    }
    return value;
  }

  Future<List<dynamic>> visits(String patientId) =>
      _list('/api/patients/$patientId/visits');
  Future<Map<String, dynamic>> visit(String id) => _map('/api/visits/$id');
  Future<List<dynamic>> prescriptions(String visitId) =>
      _list('/api/visits/$visitId/prescriptions');
  Future<List<dynamic>> invoices(String patientId) =>
      _list('/api/patients/$patientId/invoices');
  Future<Map<String, dynamic>> invoice(String id) => _map('/api/invoices/$id');
  Future<List<dynamic>> treatments(String patientId) =>
      _list('/api/patients/$patientId/treatments');
  Future<Map<String, dynamic>> treatment(String id) =>
      _map('/api/treatments/$id');
  Future<List<dynamic>> sessions(String treatmentId) =>
      _list('/api/treatments/$treatmentId/sessions');
  Future<Map<String, dynamic>> linkVisitToTreatment(
          String treatmentId, String visitId, String sessionId) =>
      _api.post('/api/treatments/$treatmentId/sessions/link-visit',
          {'visitId': visitId, 'sessionId': sessionId}).then((value) {
        if (value is! Map<String, dynamic>) {
          throw const ApiException('Dữ liệu hồ sơ không đúng định dạng.');
        }
        return value;
      });
  Future<List<dynamic>> photos(String treatmentId) =>
      _list('/api/treatments/$treatmentId/photos');
  Future<List<dynamic>> followups(String patientId) =>
      _list('/api/patients/$patientId/follow-ups');
  Future<Map<String, dynamic>> followup(String id) =>
      _map('/api/follow-ups/$id');
}
