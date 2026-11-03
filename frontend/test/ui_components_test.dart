import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/shared/photo_source_sheet.dart';

void main() {
  testWidgets('primary loading keeps the same bounds with scaled text',
      (t) async {
    final loading = ValueNotifier(false);
    addTearDown(loading.dispose);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 200,
                        child: ValueListenableBuilder<bool>(
                            valueListenable: loading,
                            builder: (_, value, __) => PrimaryButton(
                                label: 'Lưu thông tin cá nhân',
                                isLoading: value,
                                onPressed: () {}))))))));
    final before = t.getSize(find.byType(FilledButton));
    loading.value = true;
    await t.pump();
    expect(t.getSize(find.byType(FilledButton)), before);
    expect(t.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 411.0]) {
    testWidgets('photo sheet scrolls at width $width and scale 1.5', (t) async {
      t.view.physicalSize = Size(width, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (_, child) => MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => choosePhoto(context, allowRemove: true),
                      child: const Text('Ảnh'))))));
      await t.tap(find.text('Ảnh'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Gỡ ảnh'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // Dismiss without invoking a camera, upload, or other data mutation.
      Navigator.of(t.element(find.text('Gỡ ảnh'))).pop();
      await t.pumpAndSettle();
    });
  }
}
