import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';
import 'package:fire_safety_job_prep/widgets/stat_card.dart';
import 'package:fire_safety_job_prep/screens/jobs_page.dart';

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('Dark theme has readable foreground and muted text on cards', () {
    final theme = AppTheme.darkTheme;
    final colors = theme.colorScheme;

    expect(theme.brightness, Brightness.dark);
    expect(_contrastRatio(colors.onSurface, theme.cardColor), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(colors.onSurfaceVariant, theme.cardColor), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(colors.primary, theme.cardColor), greaterThanOrEqualTo(4.5));
  });

  testWidgets('Statistics use the current dark theme text colors', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(body: StatCard(number: '100', label: 'মডেল টেস্ট')),
    ));

    final theme = AppTheme.darkTheme;
    final number = tester.widget<Text>(find.text('100'));
    final label = tester.widget<Text>(find.text('মডেল টেস্ট'));
    expect(number.style?.color, theme.colorScheme.primary);
    expect(label.style?.color, theme.colorScheme.onSurfaceVariant);
  });

  testWidgets('Jobs page heading remains readable in dark mode', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const JobsPage(),
    ));

    expect(find.text('Fire & Safety Jobs'), findsOneWidget);
    expect(find.text('সর্বশেষ প্রকাশিত চাকরির বিজ্ঞপ্তি'), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(appBar.foregroundColor, Colors.white);
    final title = tester.widget<Text>(find.text('Fire & Safety Jobs'));
    expect(title.style?.fontWeight, FontWeight.w800);
  });
}
