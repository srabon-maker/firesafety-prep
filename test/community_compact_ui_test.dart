import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/community_post.dart';
import 'package:fire_safety_job_prep/screens/community_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';
import 'package:fire_safety_job_prep/widgets/post_card.dart';

CommunityPost sample(String text, {String status = 'approved'}) => CommunityPost(
  id: 1, author: 'Sample member', time: 'Today', text: text,
  comments: [], likes: 3, commentCount: 2, status: status, isOwner: true,
);

Future<void> mountFeed(WidgetTester tester, ThemeMode mode, String language,
    Future<List<CommunityPost>> Function(String) loader, {double scale = 1}) async {
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
    home: CommunityPage(loadFeed: loader),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Dark Bengali community has compact header and all filters', (tester) async {
    await mountFeed(tester, ThemeMode.dark, 'bn',
      (_) async => [sample('Example post')]);
    final title = tester.widget<Text>(find.text('কমিউনিটি'));
    expect(title.style?.fontSize, 15.5);
    expect(find.text('ফায়ার সেফটি নিয়ে শিখুন, জানুন ও শেয়ার করুন'), findsNothing);
    expect(find.text('পোস্ট লিখুন'), findsOneWidget);
    expect(find.text('পোস্ট'), findsOneWidget);
    expect(find.text('সর্বশেষ'), findsOneWidget);
    expect(find.text('জনপ্রিয়'), findsOneWidget);
    expect(find.text('আমার পোস্ট'), findsOneWidget);
    expect(find.byTooltip('ছবি যোগ করুন'), findsOneWidget);
    expect(find.byTooltip('নতুন পোস্ট'), findsOneWidget);
    expect(find.text('Example post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English large-text community retains sort and search', (tester) async {
    final calls = <String>[];
    await mountFeed(tester, ThemeMode.light, 'en', (sort) async {
      calls.add(sort);
      return [sample(sort == 'popular' ? 'Popular example' : 'Latest example')];
    }, scale: 1.5);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('My posts'), findsOneWidget);
    expect(calls, ['latest']);
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    expect(calls, ['latest', 'popular']);
    await tester.tap(find.byTooltip('Search posts'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-found');
    await tester.pumpAndSettle();
    expect(find.text('No matches found'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.text('Popular example'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pending post keeps status and owner actions, not engagement', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: PostCard(
        post: sample('Awaiting review', status: 'pending'),
        onChanged: () {},
      )),
    ));
    expect(find.text('Pending'), findsOneWidget);
    expect(find.byTooltip('Post options'), findsOneWidget);
    expect(find.text('Like'), findsNothing);
    expect(find.text('Comment'), findsNothing);
    await tester.tap(find.byTooltip('Post options'));
    await tester.pumpAndSettle();
    expect(find.text('Edit post'), findsOneWidget);
    expect(find.text('Delete post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
