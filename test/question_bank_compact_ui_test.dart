import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/learning_library_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

const fixture = <String, dynamic>{
  'data': [
    {'category': 'Fire', 'category_name_bn': 'অগ্নি নিরাপত্তা',
      'category_name_en': 'Fire', 'question_count': 10, 'locked_count': 0},
    {'category': 'Electrical', 'category_name_bn': 'বিদ্যুৎ',
      'category_name_en': 'Electrical', 'question_count': 5, 'locked_count': 5},
  ],
};

Future<void> mountBank(WidgetTester tester, ThemeMode mode, String language,
    {double scale = 1, Map<String, dynamic> data = fixture}) async {
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
    home: QuestionBankPage(loadCategories: () async => data),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Bengali dark bank preserves shortcuts and category browser actions', (tester) async {
    await mountBank(tester, ThemeMode.dark, 'bn');
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(tester.widget<Text>(find.text('প্রশ্ন ব্যাংক')).style?.fontSize, 15.5);
    expect(find.text('প্রশ্ন খুঁজুন'), findsOneWidget);
    expect(find.text('বুকমার্ক'), findsOneWidget);
    expect(find.text('আমার প্রস্তুতি'), findsOneWidget);
    expect(find.text('অগ্নি নিরাপত্তা'), findsOneWidget);
    expect(find.text('10টি প্রশ্ন'), findsOneWidget);
    expect(find.text('5টি প্রশ্ন · 5টি Premium'), findsOneWidget);
    expect(find.byTooltip('এই বিভাগের প্রশ্ন দেখুন'), findsNWidgets(2));
    expect(tester.getTopLeft(find.ancestor(of: find.text('প্রশ্ন খুঁজুন'), matching: find.byType(InkWell)).first).dy,
      closeTo(tester.getTopLeft(find.ancestor(of: find.text('বুকমার্ক'), matching: find.byType(InkWell)).first).dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('English light bank supports category search in either language', (tester) async {
    await mountBank(tester, ThemeMode.light, 'en');
    expect(find.text('Question Bank'), findsOneWidget);
    expect(find.text('Find questions'), findsOneWidget);
    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('My progress'), findsOneWidget);
    expect(find.text('2 categories'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'বিদ্যুৎ');
    await tester.pumpAndSettle();
    expect(find.text('Electrical'), findsOneWidget);
    expect(find.text('Fire'), findsNothing);
    expect(find.text('1 categories'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Fire'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text and empty categories remain accessible', (tester) async {
    await mountBank(tester, ThemeMode.dark, 'en', scale: 1.6,
      data: const {'data': []});
    expect(find.text('No categories found.'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.text('My progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
