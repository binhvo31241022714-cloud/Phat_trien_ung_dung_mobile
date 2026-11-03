import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/page_background.dart';

// Validate readability of resolved theme styles, rather than palette snapshots.
double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  test('primary normal/pressed states and body copy remain readable', () {
    final theme = AppTheme.light;
    final button = theme.filledButtonTheme.style!;
    for (final states in [
      <WidgetState>{},
      {WidgetState.pressed}
    ]) {
      final background = button.backgroundColor!.resolve(states)!;
      final foreground = button.foregroundColor!.resolve(states)!;
      final overlay = button.overlayColor?.resolve(states);
      final painted = states.contains(WidgetState.pressed) && overlay != null
          ? Color.alphaBlend(overlay, background)
          : background;
      expect(contrast(foreground, painted), greaterThanOrEqualTo(4.5));
    }
    final disabled = button.backgroundColor!.resolve({WidgetState.disabled});
    expect(disabled, isNot(button.backgroundColor!.resolve({})));
    expect(contrast(theme.textTheme.bodyMedium!.color!, AppColors.surface),
        greaterThanOrEqualTo(4.5));
    expect(contrast(theme.textTheme.bodySmall!.color!, AppColors.surface),
        greaterThanOrEqualTo(4.5));
    expect(contrast(theme.colorScheme.onSecondary, theme.colorScheme.secondary),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets('ordinary page uses a solid surface without blur', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
            body: PageBackground(child: Text('Thông tin hồ sơ')))));
    final background = find
        .descendant(
            of: find.byType(PageBackground),
            matching: find.byType(DecoratedBox))
        .first;
    final decoration =
        t.widget<DecoratedBox>(background).decoration as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, isNotNull);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'theme supports long titles, validation and disabled controls at 320/1.5',
      (t) async {
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: Scaffold(
            appBar: AppBar(title: const Text('Liệu trình điều trị')),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              const TextField(
                  decoration: InputDecoration(
                      labelText: 'Thông tin sức khỏe',
                      errorText: 'Vui lòng kiểm tra lại thông tin đã nhập.')),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () {}, child: const Text('Xác nhận thông tin')),
              const FilledButton(
                  onPressed: null, child: Text('Chưa đủ điều kiện')),
              OutlinedButton(onPressed: () {}, child: const Text('Quay lại')),
            ]))));
    expect(t.getSize(find.byType(FilledButton).first).height,
        greaterThanOrEqualTo(48));
    expect(t.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    expect(find.text('Liệu trình điều trị'), findsOneWidget);
    expect(
        find.text('Vui lòng kiểm tra lại thông tin đã nhập.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
