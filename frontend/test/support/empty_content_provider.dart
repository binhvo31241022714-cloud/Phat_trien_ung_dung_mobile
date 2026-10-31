import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/providers/content_provider.dart';

ContentProvider emptyContentProvider() => ContentProvider(
    service: ContentService(
        client: ApiClient(
            baseUrl: 'http://fake.invalid:3000',
            client: MockClient((r) async => http.Response(
                jsonEncode(r.url.path.endsWith('unread-count')
                    ? {'count': 0}
                    : r.url.path == '/api/home'
                        ? <String, dynamic>{
                            'featuredServices': [],
                            'featuredDoctors': [],
                            'latestArticles': [],
                            'upcomingAppointment': null
                          }
                        : <dynamic>[]),
                200,
                headers: {'content-type': 'application/json'})))));
