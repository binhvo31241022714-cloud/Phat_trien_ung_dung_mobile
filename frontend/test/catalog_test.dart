import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/dental_service.dart';
import 'package:frontend/data/models/doctor.dart';
import 'package:frontend/features/doctors/doctor_list_screen.dart';
import 'package:frontend/features/services/service_list_screen.dart';
import 'package:frontend/providers/catalog_provider.dart';

import 'support/fake_catalog_backend.dart';

Future<void> pumpList(
    WidgetTester tester, CatalogProvider catalog, Widget page) async {
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: catalog,
      child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: page))));
  await catalog.load();
  await tester.pumpAndSettle();
}

void main() {
  test('fromJson tolerates missing, null and wrong-typed fields', () {
    final s = DentalService.fromJson({
      'id': 'svc_01',
      'name': null,
      'price': 150000.0,
      'imageUrl': null,
      'serviceIds': ['svc_01', 3, null],
    });
    expect(s.name, '');
    expect(s.price, 150000);
    expect(s.durationMinutes, 0);
    expect(s.imageUrl, '');
    expect(s.serviceIds, ['svc_01']);
    expect(s.fromApi, isTrue);
    expect(s.favoriteType, 'service');
    expect(DentalService.fromJson({}, isCombo: true).favoriteType, 'combo');

    final d = Doctor.fromJson({'id': 'doc_01', 'name': 'BS. A'});
    expect(d.fullName, 'BS. A');
    expect(d.experienceYears, 0);
    expect(d.hasRating, isFalse);
    expect(d.avatarUrl, '');
  });

  testWidgets('service list shows services then combos with VND price',
      (tester) async {
    await pumpList(
        tester, FakeCatalogBackend().provider(), const ServiceListScreen());
    expect(find.text('Khám răng tổng quát'), findsOneWidget);
    expect(find.text('Combo chăm sóc răng miệng cơ bản'), findsOneWidget);
    expect(find.text('Combo'), findsOneWidget);
    expect(find.text('100.000 ₫'), findsOneWidget);
    // imageUrl rỗng: hiện icon mặc định, không tải ảnh.
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('inactive items are hidden from the list', (tester) async {
    final backend = FakeCatalogBackend();
    backend.services.first['isActive'] = false;
    await pumpList(tester, backend.provider(), const ServiceListScreen());
    expect(find.text('Khám răng tổng quát'), findsNothing);
    expect(find.text('Lấy cao răng'), findsOneWidget);
  });

  testWidgets('list shows error with retry, then data', (tester) async {
    final backend = FakeCatalogBackend()..failStatus = 500;
    final catalog = backend.provider();
    await pumpList(tester, catalog, const DoctorListScreen());
    expect(find.text('Yêu cầu thất bại (HTTP 500).'), findsOneWidget);
    backend.failStatus = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('BS. Nguyễn Văn API'), findsOneWidget);
    // API chưa có điểm đánh giá nên không hiện ngôi sao.
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('empty lists show an empty state', (tester) async {
    await pumpList(
        tester,
        FakeCatalogBackend(services: [], combos: [], doctors: []).provider(),
        const ServiceListScreen());
    expect(find.text('Chưa có dịch vụ'), findsOneWidget);
  });

  test('toggleFavorite saves with type_itemId and removes', () async {
    final backend = FakeCatalogBackend();
    final catalog = backend.provider();
    await catalog.loadFavorites();
    expect(await catalog.toggleFavorite('combo', 'combo_01'), isNull);
    expect(catalog.isSaved('combo', 'combo_01'), isTrue);
    expect(backend.favorites.single['id'], 'combo_combo_01');
    expect(await catalog.toggleFavorite('combo', 'combo_01'), isNull);
    expect(catalog.isSaved('combo', 'combo_01'), isFalse);
    expect(backend.favorites, isEmpty);

    backend.failStatus = 400;
    expect(await catalog.toggleFavorite('doctor', 'doc_01'), 'Lỗi giả lập');
    expect(catalog.isSaved('doctor', 'doc_01'), isFalse);
  });
}
