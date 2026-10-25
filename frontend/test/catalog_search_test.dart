import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/text_search.dart';
import 'package:frontend/features/doctors/doctor_detail_screen.dart';
import 'package:frontend/features/doctors/doctor_list_screen.dart';
import 'package:frontend/features/services/service_detail_screen.dart';
import 'package:frontend/features/services/service_list_screen.dart';
import 'package:frontend/features/shared/catalog_navigation.dart';
import 'package:frontend/providers/catalog_provider.dart';

import 'support/fake_catalog_backend.dart';

/// Dữ liệu giống Firestore: 3 dịch vụ, 2 combo, 3 bác sĩ 2 chuyên khoa.
FakeCatalogBackend backend() => FakeCatalogBackend(services: [
      {'id': 'svc_01', 'name': 'Khám răng tổng quát', 'price': 100000},
      {'id': 'svc_02', 'name': 'Lấy cao răng', 'price': 200000},
      {'id': 'svc_04', 'name': 'Tẩy trắng răng', 'price': 120000},
    ], combos: [
      {
        'id': 'combo_01',
        'name': 'Combo chăm sóc răng miệng cơ bản',
        'price': 250000,
        'serviceIds': ['svc_01', 'svc_02']
      },
      {
        'id': 'combo_03',
        'name': 'Combo nụ cười sáng',
        'price': 1200000,
        'serviceIds': ['svc_04']
      },
    ], doctors: [
      {
        'id': 'doc_01',
        'name': 'BS. Nguyễn Minh Anh',
        'specialty': 'Nha khoa tổng quát',
        'serviceIds': ['svc_01', 'svc_02']
      },
      {
        'id': 'doc_02',
        'name': 'BS. Trần Thu Mai',
        'specialty': 'Nha khoa thẩm mỹ',
        'serviceIds': ['svc_04']
      },
      {
        'id': 'doc_04',
        'name': 'BS. Phạm Thu Hà',
        'specialty': 'Nha khoa tổng quát',
        'serviceIds': ['svc_01']
      },
    ]);

Future<CatalogProvider> pump(WidgetTester tester, Widget page) async {
  // Màn hình đủ cao để mọi thẻ đều được vẽ (ListView chỉ vẽ phần nhìn thấy).
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final catalog = backend().provider();
  await catalog.load();
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: catalog,
      child: MaterialApp(
          theme: AppTheme.light,
          home: CatalogPage(title: 'Danh sách', body: page))));
  await tester.pumpAndSettle();
  return catalog;
}

/// Tên các thẻ đang hiện, theo thứ tự trên màn hình.
List<String> visibleNames(WidgetTester tester, List<String> candidates) {
  final found = [
    for (final name in candidates)
      if (find.text(name).evaluate().isNotEmpty) name
  ];
  found.sort((a, b) => tester
      .getTopLeft(find.text(a))
      .dy
      .compareTo(tester.getTopLeft(find.text(b)).dy));
  return found;
}

/// Cuộn chip vào tầm nhìn (hàng chip vuốt ngang được) rồi bấm.
Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  test('foldVietnamese ignores accents, đ and case', () {
    expect(foldVietnamese('  Lấy CAO   Răng '), 'lay cao rang');
    expect(foldVietnamese('Đội ngũ'), 'doi ngu');
    expect(matchesSearch('Lấy cao răng', 'cao rang'), isTrue);
    expect(matchesSearch('Lấy cao răng', 'CẠO'), isTrue);
    expect(matchesSearch('Tẩy trắng răng', 'nhổ'), isFalse);
    expect(matchesSearch('Bất kỳ', ''), isTrue);
  });

  test('doctorsFor: service needs its id, combo needs ALL its services',
      () async {
    final b = backend()
      ..combos.addAll([
        // Không bác sĩ nào làm cả svc_02 lẫn svc_04.
        {
          'id': 'combo_x',
          'name': 'Combo thiếu bác sĩ',
          'serviceIds': ['svc_02', 'svc_04']
        },
        {'id': 'combo_empty', 'name': 'Combo chưa có dịch vụ'},
      ]);
    final catalog = b.provider();
    await catalog.load();
    List<String> ids(String serviceId) => catalog
        .doctorsFor(catalog.services.firstWhere((s) => s.id == serviceId))
        .map((d) => d.id)
        .toList();
    expect(ids('svc_01'), ['doc_01', 'doc_04']);
    expect(ids('svc_04'), ['doc_02']);
    List<String> comboIds(String id) => catalog
        .doctorsFor(catalog.combos.firstWhere((c) => c.id == id))
        .map((d) => d.id)
        .toList();
    // combo_01 = svc_01 + svc_02: doc_04 chỉ làm svc_01 nên không đủ.
    expect(comboIds('combo_01'), ['doc_01']);
    expect(comboIds('combo_x'), isEmpty);
    expect(comboIds('combo_empty'), isEmpty);
  });

  testWidgets('service list search, kind filter, price sort and no result',
      (tester) async {
    await pump(tester, const ServiceListScreen());
    const all = [
      'Khám răng tổng quát',
      'Lấy cao răng',
      'Tẩy trắng răng',
      'Combo chăm sóc răng miệng cơ bản',
      'Combo nụ cười sáng',
    ];
    expect(visibleNames(tester, all), all);

    await tester.enterText(find.byType(TextField), 'cao rang');
    await tester.pumpAndSettle();
    expect(visibleNames(tester, all), ['Lấy cao răng']);
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();

    await tapChip(tester, 'Combo');
    expect(visibleNames(tester, all),
        ['Combo chăm sóc răng miệng cơ bản', 'Combo nụ cười sáng']);
    await tapChip(tester, 'Dịch vụ');
    expect(visibleNames(tester, all),
        ['Khám răng tổng quát', 'Lấy cao răng', 'Tẩy trắng răng']);

    await tapChip(tester, 'Tất cả');
    await tester.tap(find.byTooltip('Sắp xếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giá giảm dần'));
    await tester.pumpAndSettle();
    expect(visibleNames(tester, all), [
      'Combo nụ cười sáng',
      'Combo chăm sóc răng miệng cơ bản',
      'Lấy cao răng',
      'Tẩy trắng răng',
      'Khám răng tổng quát',
    ]);
    await tester.tap(find.byTooltip('Sắp xếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giá tăng dần'));
    await tester.pumpAndSettle();
    expect(visibleNames(tester, all).first, 'Khám răng tổng quát');

    await tester.enterText(find.byType(TextField), 'niềng');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy dịch vụ phù hợp'), findsOneWidget);
  });

  testWidgets('doctor list search and specialty chips from real data',
      (tester) async {
    await pump(tester, const DoctorListScreen());
    const all = ['BS. Nguyễn Minh Anh', 'BS. Trần Thu Mai', 'BS. Phạm Thu Hà'];
    expect(visibleNames(tester, all), all);
    // Mỗi chuyên khoa chỉ một chip, kể cả khi nhiều bác sĩ cùng chuyên khoa.
    expect(
        find.widgetWithText(ChoiceChip, 'Nha khoa tổng quát'), findsOneWidget);

    await tapChip(tester, 'Nha khoa thẩm mỹ');
    expect(visibleNames(tester, all), ['BS. Trần Thu Mai']);

    await tapChip(tester, 'Tất cả');
    await tester.enterText(find.byType(TextField), 'thu');
    await tester.pumpAndSettle();
    expect(visibleNames(tester, all), ['BS. Trần Thu Mai', 'BS. Phạm Thu Hà']);
    await tester.enterText(find.byType(TextField), 'không có');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy bác sĩ phù hợp'), findsOneWidget);
  });

  /// Mở [page] trong CatalogPage với dữ liệu mẫu.
  Future<CatalogProvider> pumpDetail(
      WidgetTester tester, Widget Function(CatalogProvider) page) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = backend().provider();
    await catalog.load();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: catalog,
        child: MaterialApp(
            theme: AppTheme.light,
            home: CatalogPage(title: 'Chi tiết', body: page(catalog)))));
    await tester.pumpAndSettle();
    return catalog;
  }

  testWidgets(
      'service → doctor: doctor page hides "Dịch vụ thực hiện" (no loop)',
      (tester) async {
    await pumpDetail(
        tester,
        (c) => ServiceDetailScreen(
            service: c.combos.firstWhere((s) => s.id == 'combo_03')));
    // Mở từ danh sách: đầy đủ.
    expect(find.text('Bác sĩ thực hiện'), findsOneWidget);
    expect(find.text('BS. Trần Thu Mai'), findsOneWidget);
    expect(find.text('BS. Nguyễn Minh Anh'), findsNothing);

    await tester.tap(find.text('BS. Trần Thu Mai'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết bác sĩ'), findsOneWidget);
    expect(find.text('Dịch vụ thực hiện'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);

    // Chỉ cần 1 lần quay lại là về chi tiết dịch vụ.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bác sĩ thực hiện'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'doctor → service: service page hides "Bác sĩ thực hiện" (no loop)',
      (tester) async {
    await pumpDetail(
        tester,
        (c) => DoctorDetailScreen(
            doctor: c.doctors.firstWhere((d) => d.id == 'doc_02')));
    // Mở từ danh sách: đầy đủ.
    expect(find.text('Dịch vụ thực hiện'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Tẩy trắng răng'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết dịch vụ'), findsOneWidget);
    expect(find.text('Tẩy trắng răng'), findsWidgets);
    expect(find.text('Bác sĩ thực hiện'), findsNothing);
    expect(find.text('BS. Trần Thu Mai'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Dịch vụ thực hiện'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('service without doctors hides the section', (tester) async {
    final b = backend()..doctors.clear();
    final catalog = b.provider();
    await catalog.load();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: catalog,
        child: MaterialApp(
            theme: AppTheme.light,
            home: CatalogPage(
                title: 'Chi tiết dịch vụ',
                body: ServiceDetailScreen(service: catalog.services.first)))));
    await tester.pumpAndSettle();
    expect(find.text('Bác sĩ thực hiện'), findsNothing);
  });

  testWidgets('combo without a doctor covering all services shows a note',
      (tester) async {
    final b = backend()
      ..combos.add({
        'id': 'combo_x',
        'name': 'Combo thiếu bác sĩ',
        'serviceIds': ['svc_02', 'svc_04']
      });
    final catalog = b.provider();
    await catalog.load();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: catalog,
        child: MaterialApp(
            theme: AppTheme.light,
            home: CatalogPage(
                title: 'Chi tiết dịch vụ',
                body: ServiceDetailScreen(
                    service: catalog.combos
                        .firstWhere((c) => c.id == 'combo_x'))))));
    await tester.pumpAndSettle();
    // Tiêu đề vẫn hiện, kèm câu thay thế, không liệt kê bác sĩ làm thiếu.
    expect(find.text('Bác sĩ thực hiện'), findsOneWidget);
    expect(find.text('Phòng khám sẽ sắp xếp bác sĩ phù hợp cho combo này.'),
        findsOneWidget);
    expect(find.text('BS. Nguyễn Minh Anh'), findsNothing);
    expect(find.text('BS. Trần Thu Mai'), findsNothing);
  });
}
