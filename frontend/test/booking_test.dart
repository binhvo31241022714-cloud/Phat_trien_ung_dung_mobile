import 'support/data_source_scope.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/features/booking/booking_screen.dart';

import 'support/fake_catalog_backend.dart';
import 'support/fake_profile_backend.dart';

void main() {
  test('services, total and steps preserve selections', () {
    // Local-price demo contract; API quotes are covered separately.
    useDataSourceForTest(DataSource.mock);
    final data = PatientDataProvider();
    final controller = BookingController(data);

    // Chưa chọn dịch vụ thì không thể sang bước tiếp theo.
    controller.next();
    expect(controller.step, 0);

    // Chọn hai dịch vụ và kiểm tra tổng tiền.
    controller.toggleService(data.services[0].id);
    controller.toggleService(data.services[1].id);

    expect(
      controller.total,
      data.services[0].price + data.services[1].price,
    );

    // Chưa chọn bác sĩ nên vẫn ở bước chọn bác sĩ sau lần next đầu tiên.
    controller.next();
    expect(controller.step, 1);

    controller.next();
    expect(controller.step, 1);

    // Chọn bác sĩ rồi chuyển bước và quay lại.
    controller.chooseDoctor(data.doctors.first.id);
    controller.next();
    expect(controller.step, 2);

    controller.back();
    expect(controller.step, 1);
    expect(controller.doctorId, data.doctors.first.id);
    expect(controller.serviceIds.length, 2);

    // Bỏ chọn dịch vụ đầu tiên.
    controller.toggleService(data.services[0].id);
    expect(controller.total, data.services[1].price);

    controller.dispose();
  });

  test('past dates are rejected and time requires an available slot', () {
    final data = PatientDataProvider();
    final controller = BookingController(
      data,
      clock: () => DateTime(2026, 10, 21, 10),
    );

    // Không cho chọn ngày trong quá khứ.
    controller.chooseDate(DateTime(2026, 10, 20));
    expect(controller.date, isNull);

    // Chưa có dịch vụ nên chưa thể xác nhận khung giờ.
    controller.chooseDate(DateTime(2026, 10, 22));
    controller.chooseTime('09:00');
    expect(controller.time, isNull);

    // Đổi ngày sẽ xóa khung giờ được chọn trước đó.
    controller.chooseDate(DateTime(2026, 10, 21));
    expect(controller.time, isNull);

    // Chỉ nhập giờ không đủ để xác nhận còn slot trống.
    controller.chooseTime('10:30');
    expect(controller.time, isNull);
    expect(controller.validTime, isFalse);

    controller.dispose();
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('booking detail and doctor step fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = PatientDataProvider();

      // Dùng cùng một FakeCatalogBackend cho provider và dữ liệu của test.
      final fakeCatalog = FakeCatalogBackend();

      await tester.pumpWidget(
        ChangeNotifierProvider<PatientDataProvider>.value(
          value: data,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => FakeProfileBackend().provider(),
              ),
              ChangeNotifierProvider(
                create: (_) => fakeCatalog.provider(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(
                body: BookingScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mở chi tiết dịch vụ đầu tiên.
      await tester.tap(find.text('Chi tiết').first);
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết dịch vụ'), findsOneWidget);
      expect(find.text('Lưu để xem sau'), findsOneWidget);

      // Đóng chi tiết và xác nhận đã quay về màn hình đặt lịch.
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết dịch vụ'), findsNothing);
      expect(find.text('Đặt lịch khám'), findsOneWidget);

      // Lấy tên dịch vụ từ chính dữ liệu đang được hiển thị trên màn hình.
      final serviceName = fakeCatalog.services.first['name'] as String;
      final serviceFinder = find.text(serviceName).first;

      await tester.ensureVisible(serviceFinder);
      await tester.tap(serviceFinder);
      await tester.pumpAndSettle();

      // Xác nhận dịch vụ đã được chọn.
      expect(find.text('1 dịch vụ đã chọn'), findsOneWidget);

      // Chỉ nhấn tiếp tục khi nút thực sự xuất hiện.
      final nextButton = find.text('Tiếp theo →');
      expect(nextButton, findsOneWidget);

      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Xác nhận chuyển sang bước chọn bác sĩ mà không phát sinh exception.
      expect(find.text('Chọn bác sĩ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
