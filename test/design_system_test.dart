import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';
import 'package:fire_safety_job_prep/widgets/design_system.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('Feature card is usable in ${theme.brightness} and narrow layout', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: Center(child: SizedBox(width: 280,
        child: FsFeatureCard(icon: Icons.school_outlined, title: 'Career development',
          subtitle: 'Jobs, interviews, training', onTap: () => tapped = true))))));
      await tester.tap(find.text('Career development'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Loading cards settle and status retry works', (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const FsLoadingCards(count: 2),
      FsStatusCard(icon: Icons.cloud_off, message: 'Not available', onRetry: () => retries++),
    ]))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
