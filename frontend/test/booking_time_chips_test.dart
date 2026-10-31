import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/models/availability_slot.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/features/booking/steps/select_datetime_step.dart';
import 'support/data_source_scope.dart';

class SlotController extends BookingController {
  SlotController(super.data);
  @override
  Future<void> loadAvailability() async {}
}

void main() {
  testWidgets(
      'time-only chips distinguish doctors at the same time and reset on date/doctor change',
      (t) async {
    useDataSourceForTest(DataSource.api);
    final data = PatientDataProvider(seedDemo: false);
    final c = SlotController(data);
    addTearDown(c.dispose);
    addTearDown(data.dispose);
    c.serviceIds.add('service');
    c.date = DateTime(2099, 1, 1);
    c.doctorChosen = true;
    c.availabilitySlots = [
      for (final id in ['doctor-a', 'doctor-b'])
        AvailabilitySlot(
            doctorId: id,
            doctorName: 'Name $id',
            date: '2099-01-01',
            startTime: '09:00',
            endTime: '09:30',
            durationMinutes: 30),
    ];
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnimatedBuilder(
                animation: c,
                builder: (_, __) => SelectDatetimeStep(controller: c)))));
    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(2));
    for (final chip in t.widgetList<ChoiceChip>(chips)) {
      expect((chip.label as Text).data, '09:00');
    }
    expect(find.descendant(of: chips, matching: find.textContaining('Name')),
        findsNothing);
    expect(find.textContaining('09:30'), findsNothing);
    final second = find.byKey(const ValueKey('slot-2099-01-01-doctor-b-09:00'));
    await t.tap(second);
    await t.pump();
    expect(c.time, '09:00');
    expect(c.doctorId, 'doctor-b');
    expect(c.validTime, isTrue);
    expect(t.widget<ChoiceChip>(second).selected, isTrue);
    expect(t.widget<ChoiceChip>(chips.first).selected, isFalse);
    c.chooseDoctor('doctor-a');
    await t.pump();
    expect(c.time, isNull);
    expect(c.availabilitySlots, isEmpty);
    c.chooseDate(DateTime(2099, 1, 2));
    await t.pump();
    expect(c.time, isNull);
    expect(c.validTime, isFalse);
  });

  testWidgets('loading shows a progress state without stale selectable chips',
      (t) async {
    useDataSourceForTest(DataSource.api);
    final data = PatientDataProvider(seedDemo: false);
    final c = SlotController(data)..serviceIds.add('service');
    c.date = DateTime(2099, 1, 1);
    c.availabilityLoading = true;
    addTearDown(c.dispose);
    addTearDown(data.dispose);
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: SelectDatetimeStep(controller: c))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    c.availabilityLoading = false;
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: SelectDatetimeStep(controller: c))));
    expect(find.textContaining('chưa có khung giờ phù hợp'), findsOneWidget);
  });
}
