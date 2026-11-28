import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fire_safety_job_prep/models/study_note.dart';
import 'package:fire_safety_job_prep/screens/notes_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

const categories = [
  StudyNoteCategory(id: 1, name: 'Fire', nameBn: 'অগ্নি নিরাপত্তা', nameEn: 'Fire'),
];

Future<void> mountNotes(WidgetTester tester, ThemeMode mode, String language,
    Future<StudyNotesPage> Function(String, int?, int) loader,
    {double scale = 1}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: mode,
    locale: Locale(language),
    supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: NotesPage(loadNotes: loader),
  ));
  await tester.pumpAndSettle();
}

StudyNotesPage emptyPage() => const StudyNotesPage(
  notes: [], categories: categories, page: 1, totalPages: 1, total: 0,
);

void main() {
  testWidgets('Dark Bengali notes has compact header and empty state', (tester) async {
    await mountNotes(tester, ThemeMode.dark, 'bn', (_search, _category, _page) async => emptyPage());
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(tester.widget<Text>(find.text('নোট ও রিসোর্স')).style?.fontSize, 15.5);
    expect(find.text('ফায়ার সেফটি স্টাডি নোট'), findsNothing);
    expect(find.byTooltip('সংরক্ষিত নোট'), findsOneWidget);
    expect(find.byTooltip('রিফ্রেশ'), findsOneWidget);
    expect(find.text('সব ক্যাটাগরি'), findsOneWidget);
    expect(find.text('0টি নোট'), findsOneWidget);
    expect(find.text('এখনো কোনো নোট নেই।'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English notes preserves total, pagination, bookmark and search', (tester) async {
    final calls = <String>[];
    await mountNotes(tester, ThemeMode.light, 'en', (search, category, page) async {
      calls.add('$search/$category/$page');
      if (search.isNotEmpty) return emptyPage();
      return StudyNotesPage(
        notes: [StudyNote(id: page, title: 'Sample note $page', locked: true)],
        categories: categories, page: page, totalPages: 2, total: 2,
      );
    });
    expect(find.text('Notes & resources'), findsOneWidget);
    expect(find.text('2 notes'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    await tester.tap(find.byTooltip('Bookmark note'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('saved_study_note_ids'), ['1']);
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();
    expect(find.text('Sample note 2'), findsOneWidget);
    expect(calls.last, '/null/2');
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(calls.last, 'missing/null/1');
    expect(find.text('No matching notes.'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Sample note 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Category selection and large text remain usable', (tester) async {
    final selected = <int?>[];
    await mountNotes(tester, ThemeMode.dark, 'en', (_search, category, _page) async {
      selected.add(category);
      return emptyPage();
    }, scale: 1.6);
    await tester.tap(find.text('All categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fire').last);
    await tester.pumpAndSettle();
    expect(selected.last, 1);
    expect(find.text('No matching notes.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
