import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/career_page.dart';
import 'package:fire_safety_job_prep/widgets/free_mock_interview_panel.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

const questions = <Map<String, dynamic>>[
  {'title': 'Sample question', 'body': 'Sample answer about prevention'},
];

Future<void> mountMock(WidgetTester tester, ThemeMode mode, String language,
    Future<Map<String, dynamic>> Function(Map<String, String>) loader,
    {double scale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const voice = MethodChannel('com.firesafetybd/offline_voice');
  const events = MethodChannel('com.firesafetybd/offline_voice_events');
  messenger.setMockMethodCallHandler(voice, (call) async {
    if (call.method == 'requestMicrophonePermission') return false;
    if (call.method == 'isOfflineSpeechAvailable') return false;
    return null;
  });
  messenger.setMockMethodCallHandler(events, (call) async => null);
  addTearDown(() {
    messenger.setMockMethodCallHandler(voice, null);
    messenger.setMockMethodCallHandler(events, null);
  });
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
    home: CareerSection(section: 'mock', loadMock: loader),
  ));
  await tester.pumpAndSettle();
}

// Locate the outer page rather than a nested TextField scrollable. The
// ListView may keep a widget built even while its hit target is offscreen.
Finder mockPageScroll() => find.descendant(
  of: find.byType(ListView).first,
  matching: find.byType(Scrollable),
).first;

Future<void> revealMockControl(WidgetTester tester, Finder target,
    {required double delta}) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, delta, scrollable: mockPageScroll());
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget,
    reason: 'Control must be inside the viewport before tapping');
}

Future<void> returnToMockSetup(WidgetTester tester, Finder target) async {
  final position = tester.state<ScrollableState>(mockPageScroll()).position;
  position.jumpTo(position.minScrollExtent);
  await tester.pumpAndSettle();
  await revealMockControl(tester, target, delta: -150);
}

void main() {
  testWidgets('Bengali compact setup keeps the non-AI disclosure and empty state', (tester) async {
    await mountMock(tester, ThemeMode.dark, 'bn',
      (filters) async => {'data': []});
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 68);
    expect(find.text('মক ইন্টারভিউ'), findsOneWidget);
    expect(find.text('টেক্সট'), findsOneWidget);
    expect(find.text('ভয়েস'), findsOneWidget);
    expect(find.text('এখনো কোনো প্রশ্ন পাওয়া যায়নি।'), findsOneWidget);
    await tester.tap(find.byTooltip('ইন্টারভিউ সম্পর্কে'));
    await tester.pumpAndSettle();
    expect(find.textContaining('এটি AI বা পরীক্ষকের মূল্যায়ন নয়'), findsOneWidget);
    await tester.tap(find.text('বন্ধ করুন'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mode selection changes real controls and preserves typed answer', (tester) async {
    await mountMock(tester, ThemeMode.light, 'en',
      (filters) async => {'data': questions});
    expect(tester.widget<FreeMockInterviewPanel>(find.byType(FreeMockInterviewPanel)).voiceMode, isFalse);
    expect(find.text('Hear question'), findsNothing);
    final answer = find.byKey(const ValueKey('mock-answer'));
    final voice = find.descendant(
      of: find.byKey(const ValueKey('mock-voice-mode')),
      matching: find.byType(InkWell));
    final text = find.descendant(
      of: find.byKey(const ValueKey('mock-text-mode')),
      matching: find.byType(InkWell));
    await revealMockControl(tester, answer, delta: 120);
    await tester.enterText(answer, 'Sample answer');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await returnToMockSetup(tester, voice);
    await tester.tap(voice.hitTestable());
    await tester.pumpAndSettle();
    expect(tester.widget<FreeMockInterviewPanel>(find.byType(FreeMockInterviewPanel)).voiceMode, isTrue);
    expect(find.text('Hear question'), findsOneWidget);
    await revealMockControl(tester, find.text('Speak answer'), delta: 150);
    await tester.tap(find.text('Speak answer').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Voice requires microphone permission.'), findsOneWidget);
    // Return to the top even if the lazy list still has an offscreen tile.
    await returnToMockSetup(tester, text);
    await tester.tap(text.hitTestable());
    await tester.pumpAndSettle();
    expect(tester.widget<FreeMockInterviewPanel>(find.byType(FreeMockInterviewPanel)).voiceMode, isFalse);
    expect(find.text('Hear question'), findsNothing);
    await revealMockControl(tester, answer, delta: 120);
    expect(tester.widget<TextField>(answer).controller!.text, 'Sample answer');
    await revealMockControl(tester, find.text('Check answer'), delta: 150);
    await tester.tap(find.text('Check answer').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('sample-match indicator'), findsOneWidget);
    await revealMockControl(tester, find.text('View summary'), delta: 150);
    await tester.tap(find.text('View summary').hitTestable());
    await tester.pumpAndSettle();
    await revealMockControl(tester, find.text('Practice complete'), delta: -150);
    expect(find.text('Practice complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text and exact role filter remain usable', (tester) async {
    final roles = <String>[];
    await mountMock(tester, ThemeMode.dark, 'en', (filters) async {
      roles.add(filters['role'] ?? '');
      return {'data': []};
    }, scale: 1.6);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Safety Officer');
    await tester.ensureVisible(find.text('Start interview'));
    await tester.tap(find.text('Start interview'));
    await tester.pumpAndSettle();
    expect(roles.last, 'Safety Officer');
    expect(tester.takeException(), isNull);
  });
}
