import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/services/profile_service.dart';
import 'package:frontend/providers/profile_provider.dart';

http.Response rows(List<Map<String, Object>> value) =>
    http.Response(jsonEncode(value), 200);
const active = {'id': 'active', 'fullName': 'Active'};
const archived = {'id': 'archived', 'isArchived': true};

void main() {
  test('model defaults, preserves archived with avatar, write DTO excludes flag', () {
    expect(FamilyMember.fromJson(active).isArchived, isFalse);
    final member = FamilyMember.fromJson(archived).withAvatar('image');
    expect(member.isArchived, isTrue);
    expect(member.avatarMediaId, 'image');
    expect(member.withAvatar(null).isArchived, isTrue);
    expect(member.toJson().containsKey('isArchived'), isFalse);
  });

  test('service uses explicit history query; provider lists remain separate', () async {
    final queries = <String>[];
    final p = ProfileProvider(service: ProfileService(client: ApiClient(
      client: MockClient((r) async {
        queries.add(r.url.query);
        return rows(r.url.query.isEmpty ? [active] : [active, archived]);
      }),
    )));
    addTearDown(p.dispose);
    await p.loadFamily();
    await p.loadHistoryFamily();
    expect(queries, ['', 'includeArchived=true']);
    expect(p.family.map((m) => m.id), ['active']);
    expect(p.historyFamily.map((m) => m.id), ['active', 'archived']);
    expect(p.historyFamilyLoaded, isTrue);
    expect(p.historyFamilyLoading, isFalse);
    expect(() => p.historyFamily.clear(), throwsUnsupportedError);
  });

  test('active family defensively excludes archived response rows', () async {
    final p = ProfileProvider(service: ProfileService(client: ApiClient(
      client: MockClient((_) async => rows([active, archived])),
    )));
    addTearDown(p.dispose);
    await p.loadFamily();
    expect(p.family.map((m) => m.id), ['active']);
  });

  test('newest history request wins; stale failure cannot change state', () async {
    final pending = <Completer<http.Response>>[];
    final p = ProfileProvider(service: ProfileService(client: ApiClient(
      client: MockClient((_) { final c = Completer<http.Response>(); pending.add(c); return c.future; }),
    )));
    addTearDown(p.dispose);
    final first = p.loadHistoryFamily();
    await Future<void>.delayed(Duration.zero);
    final second = p.loadHistoryFamily();
    await Future<void>.delayed(Duration.zero);
    pending[1].complete(rows([active]));
    await second;
    pending[0].complete(http.Response('{"message":"old"}', 400));
    await first;
    expect(p.historyFamily.map((m) => m.id), ['active']);
    expect(p.historyFamilyError, isNull);
    expect(p.historyFamilyLoading, isFalse);
  });

  test('session clear rejects old history response and resets flags', () async {
    final old = Completer<http.Response>();
    var count = 0;
    final p = ProfileProvider(service: ProfileService(client: ApiClient(
      client: MockClient((_) => count++ == 0 ? old.future : Future.value(rows([active]))),
    )));
    addTearDown(p.dispose);
    final first = p.loadHistoryFamily();
    await Future<void>.delayed(Duration.zero);
    p.clear();
    expect(p.historyFamily, isEmpty);
    expect(p.historyFamilyLoaded, isFalse);
    expect(p.historyFamilyLoading, isFalse);
    expect(p.historyFamilyError, isNull);
    await p.loadHistoryFamily();
    old.complete(rows([archived]));
    await first;
    expect(p.historyFamily.map((m) => m.id), ['active']);
  });

  test('older history success cannot overwrite a newer request', () async {
    final pending = <Completer<http.Response>>[];
    final p = ProfileProvider(service: ProfileService(client: ApiClient(
      client: MockClient((_) { final c = Completer<http.Response>(); pending.add(c); return c.future; }),
    )));
    addTearDown(p.dispose);
    final first = p.loadHistoryFamily();
    await Future<void>.delayed(Duration.zero);
    final second = p.loadHistoryFamily();
    await Future<void>.delayed(Duration.zero);
    pending[1].complete(rows([active]));
    await second;
    pending[0].complete(rows([archived]));
    await first;
    expect(p.historyFamily.map((m) => m.id), ['active']);
  });

  test('failed archive preserves history and dispose rejects pending response', () async {
    final pending = Completer<http.Response>();
    var gets = 0;
    final p = ProfileProvider(service: ProfileService(client: ApiClient(
      client: MockClient((r) async {
        if (r.method == 'DELETE') return http.Response('{"message":"upcoming"}', 409);
        return gets++ == 0 ? rows([active, archived]) : pending.future;
      }),
    )));
    await p.loadHistoryFamily();
    expect(await p.deleteFamily('active'), 'upcoming');
    expect(p.historyFamilyLoaded, isTrue);
    expect(p.historyFamily.length, 2);
    final job = p.loadHistoryFamily();
    await Future<void>.delayed(Duration.zero);
    p.dispose();
    pending.complete(rows([]));
    await job;
    expect(p.historyFamily.length, 2);
  });

  test('history error is separate and retry clears it', () async {
    var fail = true;
    final p = ProfileProvider(service: ProfileService(client: ApiClient(
      client: MockClient((r) async => r.url.query.isNotEmpty && fail
          ? http.Response('{"message":"history error"}', 400) : rows([active])),
    )));
    addTearDown(p.dispose);
    await p.loadFamily();
    await p.loadHistoryFamily();
    expect(p.historyFamilyError, 'history error');
    expect(p.familyError, isNull);
    expect(p.familyLoaded, isTrue);
    fail = false;
    await p.loadHistoryFamily();
    expect(p.historyFamilyError, isNull);
    expect(p.historyFamilyLoaded, isTrue);
    p.clear();
    expect(p.historyFamilyLoaded, isFalse);
  });

  test('archive invalidates history and pending history, reloads active list', () async {
    final old = Completer<http.Response>();
    var historyCalls = 0;
    var deleted = false;
    final p = ProfileProvider(service: ProfileService(client: ApiClient(
      client: MockClient((r) async {
        if (r.method == 'DELETE') { deleted = true; return http.Response('{}', 200); }
        if (r.url.query.isNotEmpty) {
          historyCalls++;
          if (historyCalls == 2) return old.future;
          return rows(deleted ? [archived] : [active]);
        }
        return rows(deleted ? [] : [active]);
      }),
    )));
    addTearDown(p.dispose);
    await p.loadFamily();
    await p.loadHistoryFamily();
    final pending = p.loadHistoryFamily();
    await Future<void>.delayed(Duration.zero);
    expect(await p.deleteFamily('active'), isNull);
    expect(p.family, isEmpty);
    expect(p.historyFamily, isEmpty);
    expect(p.historyFamilyLoaded, isFalse);
    old.complete(rows([active]));
    await pending;
    expect(p.historyFamily, isEmpty);
    await p.loadHistoryFamily();
    expect(p.historyFamily.single.isArchived, isTrue);
  });
}
