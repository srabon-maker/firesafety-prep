import 'package:fire_safety_job_prep/theme/app_theme.dart';
import 'package:fire_safety_job_prep/screens/career_page.dart';
import 'package:fire_safety_job_prep/widgets/ui_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark themes use the intended brand and brightness', () {
    expect(AppTheme.lightTheme.colorScheme.primary, AppColors.maroon);
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(AppTheme.darkTheme.colorScheme.primary, isNot(AppColors.maroon));
  });
  testWidgets('career dashboard adapts to small screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const CareerPage()));
    expect(find.text('Job alerts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading placeholder renders in dark mode', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: const Scaffold(body: UiLoading())));
    await tester.pumpAndSettle();
    expect(find.byType(UiLoading), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
