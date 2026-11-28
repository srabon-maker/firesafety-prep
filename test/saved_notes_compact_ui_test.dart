import 'package:fire_safety_job_prep/screens/saved_notes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Saved notes compact header in ${brightness.name}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SavedNotesPage(openedFromNotes: true),
            )),
            child: const Text('Open saved notes'),
          ),
        )),
      ));
      await tester.tap(find.text('Open saved notes'));
      await tester.pumpAndSettle();
      final header = tester.widget<AppBar>(find.byType(AppBar));
      expect(header.toolbarHeight, 68);
      expect(header.backgroundColor, brightness == Brightness.dark
          ? const Color(0xFF36060D) : const Color(0xFF650D18));
      expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
      expect(find.text('Saved notes'), findsOneWidget);
      expect(find.text('No saved notes'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('No saved notes'), findsOneWidget);
      await tester.tap(find.text('Browse notes'));
      await tester.pumpAndSettle();
      expect(find.text('Open saved notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
