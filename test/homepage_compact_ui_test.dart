import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/job_circular.dart';
import 'package:fire_safety_job_prep/models/study_note.dart';
import 'package:fire_safety_job_prep/screens/home_page.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';

Future<void> mountHome(WidgetTester tester, String language,
    {ThemeMode mode = ThemeMode.dark, double scale = 1, double width = 360,
    List<String> sections = const ['marketplace', 'jobs', 'notes'],
    String company = 'Example Company', DateTime? deadline, int jobCount=1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: mode,
    locale: Locale(language), supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 24),
        viewPadding: const EdgeInsets.only(top: 24),
        textScaler: TextScaler.linear(scale)), child: child!),
    home: Scaffold(body: HomePage(
      loadHome: () async => {'sections': sections},
      loadJobs: () async => [
        for(int i=0;i<jobCount;i++)JobCircular(id:i+1,organization:company,
          title:i==0?'Sample job':'Second job',location:'Dhaka',
          publishedAt:DateTime(2026,1,2-i),deadline:deadline),
      ],
      loadNotes: () async => const StudyNotesPage(notes: [], categories: [], page: 1, totalPages: 1, total: 0),
    )),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Bengali home preserves all ten shortcuts and compact grids', (tester) async {
    await mountHome(tester, 'bn');
    for (final label in ['চাকরির খবর','প্রশ্ন ব্যাংক','স্টাডি নোট','মডেল টেস্ট',
      'ইন্টারভিউ','আমার প্রস্তুতি','চাকরির\nঅ্যালার্ট','মক\nইন্টারভিউ','প্রশিক্ষণ\nও কোর্স','পেশাজীবী\nডিরেক্টরি']) {
      expect(find.text(label), findsOneWidget);
    }
    final grids = tester.widgetList<GridView>(find.byType(GridView)).toList();
    final first = grids[0].gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    final second = grids[1].gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(first.crossAxisCount, 3);
    expect(first.mainAxisExtent, 80);
    expect(second.crossAxisCount, 4);
    expect(second.mainAxisExtent, 78);
    final iconTops = [for (final target in ['alerts','mock','courses','directory'])
      tester.getTopLeft(find.byKey(ValueKey('home-career-icon-$target'))).dy];
    expect(iconTops.toSet().length, 1);
    final mockCard = tester.widget<Card>(find.byKey(const ValueKey('home-career-mock')));
    final shape = mockCard.shape! as RoundedRectangleBorder;
    expect(shape.side.color.a, closeTo(.40, .01));
    expect(find.text('মার্কেটপ্লেস'), findsOneWidget);
    final marketplace = find.byKey(const ValueKey('home-marketplace-tile'));
    final marketIcon = find.byKey(const ValueKey('home-marketplace-icon'));
    final labels = find.byKey(const ValueKey('home-marketplace-labels'));
    final labelHeight = tester.getSize(labels).height;
    final expectedHeight = (labelHeight > 42 ? labelHeight : 42.0) + 26;
    expect(tester.getSize(marketplace).height, closeTo(expectedHeight, .1));
    expect(tester.getSize(marketplace).height, greaterThanOrEqualTo(68));
    expect(tester.getSize(marketIcon), const Size(42, 42));
    expect(tester.widget<Text>(find.text('মার্কেটপ্লেস')).style?.fontSize, 14);
    expect(tester.widget<Text>(find.text('ফায়ার সেফটি পণ্য ও সার্ভিস')).style?.fontSize, 12);
    expect(find.text('Fire Safety BD'), findsOneWidget);
    final brand = find.byKey(const ValueKey('home-brand-title'));
    expect(tester.widget<Text>(brand).style?.fontSize, 20);
    expect(tester.widget<Text>(brand).style?.fontWeight, FontWeight.w600);
    final counters = find.byKey(const ValueKey('home-brand-bd-counters'));
    expect(tester.widget<CustomPaint>(counters).painter, isNotNull);
    expect(find.descendant(of: counters, matching: brand), findsOneWidget);
    expect(tester.getSize(counters), tester.getSize(brand));
    expect(tester.widget<Text>(brand).style?.color, Colors.white);
    expect(tester.widget<Text>(brand).maxLines, 1);
    expect(tester.widget<Text>(brand).overflow, TextOverflow.ellipsis);
    final brandIcon = find.byKey(const ValueKey('home-brand-icon'));
    final flame = find.byKey(const ValueKey('home-brand-flame'));
    expect(tester.getSize(brandIcon), const Size(42, 42));
    expect(tester.getSize(flame), const Size(28, 28));
    expect(tester.getCenter(flame), tester.getCenter(brandIcon));
    expect(tester.widget<CustomPaint>(flame).painter, isNotNull);
    final brandDecoration = tester.widget<Container>(brandIcon).decoration as BoxDecoration;
    expect(brandDecoration.border, isNull);
    expect(brandDecoration.color, Colors.white.withValues(alpha: .12));
    expect(find.descendant(of: brandIcon, matching: find.byType(Image)), findsNothing);
    expect(tester.getCenter(flame).dy, closeTo(tester.getCenter(brand).dy, .1));
    expect(find.text('Learn • Prepare • Connect'), findsNothing);
    expect(find.byKey(const ValueKey('home-brand-tagline')), findsNothing);
    expect(tester.getCenter(brand).dy, closeTo(tester.getCenter(find.byTooltip('অ্যাডমিন সাপোর্ট')).dy, .1));
    expect(tester.widget<Text>(find.text('চাকরির খবর')).style?.fontWeight, FontWeight.w500);
    expect(tester.widget<Text>(find.text('মক\nইন্টারভিউ')).style?.fontWeight, FontWeight.w500);
    expect(tester.widget<Text>(find.text('মার্কেটপ্লেস')).style?.fontWeight, FontWeight.w500);
    expect(find.byTooltip('নোটিফিকেশন'), findsOneWidget);
    expect(find.byTooltip('অ্যাডমিন সাপোর্ট'), findsOneWidget);
    expect(find.byIcon(Icons.support_agent_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Safe area protects scroll viewport and previews remain available', (tester) async {
    await mountHome(tester, 'en', mode: ThemeMode.light);
    final flame = find.byKey(const ValueKey('home-brand-flame'));
    final brandIcon = find.byKey(const ValueKey('home-brand-icon'));
    expect(flame, findsOneWidget);
    expect(tester.getSize(flame), const Size(28, 28));
    expect(tester.getSize(brandIcon), const Size(42, 42));
    expect(tester.getCenter(flame), tester.getCenter(brandIcon));
    expect(tester.widget<Text>(find.byKey(const ValueKey('home-brand-title'))).style?.fontWeight, FontWeight.w600);
    final list = find.byType(ListView).first;
    expect(tester.getTopLeft(list).dy, greaterThanOrEqualTo(24));
    final status = tester.widget<DecoratedBox>(find.byKey(const ValueKey('home-status-gradient')));
    expect((status.decoration as BoxDecoration).gradient, isA<LinearGradient>());
    expect(find.text('Marketplace'), findsOneWidget);
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(list).dy, greaterThanOrEqualTo(24));
    expect(find.text('Sample job'), findsOneWidget);
    expect(find.text('Example Company'), findsOneWidget);
    final jobTitle = find.text('Sample job');
    final companyName = find.text('Example Company');
    expect(tester.getTopLeft(companyName).dy - tester.getBottomLeft(jobTitle).dy, closeTo(2, .1));
    expect(tester.widget<Text>(jobTitle).style?.fontSize, 14);
    expect(tester.widget<Text>(jobTitle).style?.fontWeight, FontWeight.w600);
    expect(tester.widget<Text>(companyName).style?.fontSize, 12);
    expect(tester.widget<Text>(companyName).style?.fontWeight, FontWeight.w400);
    expect(find.text('Dhaka'), findsNothing);
    expect(find.text('Example Company • Dhaka'), findsNothing);
    expect(find.text('No notes published.'), findsOneWidget);
    final empty=find.byKey(const ValueKey('home-empty-notes'));
    expect(tester.getSize(empty).height,lessThan(65));
    expect(tester.widget<Text>(find.text('No notes published.')).style?.fontSize,12);
    expect(find.textContaining('Deadline:'),findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Missing company never substitutes workplace as company name', (tester) async {
    await mountHome(tester, 'en', company: '  ');
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final job = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Sample job'));
    expect(job.subtitle, isNull);
    expect(find.text('Dhaka'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for(final language in ['bn','en']){
    testWidgets('Four home headings share 14dp medium styling and omit preview deadline in $language',(tester)async{
      final deadline=DateTime(2099,12,31);
      final bn=language=='bn';
      await mountHome(tester,language,mode:bn?ThemeMode.dark:ThemeMode.light,deadline:deadline);
      await tester.drag(find.byType(ListView).first,const Offset(0,-500));
      await tester.pumpAndSettle();
      final labels=bn
        ?['ক্যারিয়ার ডেভেলপমেন্ট','সর্বশেষ চাকরির বিজ্ঞপ্তি','নতুন স্টাডি নোট','মার্কেটপ্লেস']
        :['Career development','Latest jobs','New study notes','Marketplace'];
      final headings=labels.map(find.text).toList();
      for(final heading in headings){
        expect(heading,findsOneWidget);
        final text=tester.widget<Text>(heading);
        expect(text.style?.fontSize,14);
        expect(text.style?.fontWeight,FontWeight.w500);
      }
      expect(find.text('Sample job'),findsOneWidget);
      expect(find.textContaining(bn?'শেষ তারিখ:':'Deadline:'),findsNothing);
      expect(find.text('Example Company'),findsOneWidget);
      expect(find.text('Dhaka'),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }

  for(final mode in [ThemeMode.dark,ThemeMode.light]){
    testWidgets('Home sections have 12dp gaps, 8dp header gaps and 6dp card gaps in $mode',(tester)async{
      await mountHome(tester,mode==ThemeMode.dark?'bn':'en',mode:mode,jobCount:2);
      await tester.drag(find.byType(ListView).first,const Offset(0,-500));
      await tester.pumpAndSettle();
      final career=find.byKey(const ValueKey('home-career-grid'));
      final market=find.byKey(const ValueKey('home-marketplace-tile'));
      final jobs=find.byKey(const ValueKey('home-section-header-jobs'));
      final notes=find.byKey(const ValueKey('home-section-header-notes'));
      final first=find.ancestor(of:find.text('Sample job'),matching:find.byType(Card)).first;
      final second=find.ancestor(of:find.text('Second job'),matching:find.byType(Card)).first;
      final empty=find.byKey(const ValueKey('home-empty-notes'));
      double gap(Finder before,Finder after)=>tester.getTopLeft(after).dy-tester.getBottomLeft(before).dy;
      expect(gap(career,market),closeTo(12,.1));
      expect(gap(market,jobs),closeTo(12,.1));
      expect(gap(jobs,first),closeTo(8,.1));
      expect(gap(first,second),closeTo(6,.1));
      expect(gap(second,notes),closeTo(12,.1));
      expect(gap(notes,empty),closeTo(8,.1));
      expect(tester.takeException(),isNull);
    });
  }

  testWidgets('Marketplace is exactly 68dp when both labels fit', (tester) async {
    await mountHome(tester, 'en', width: 600, sections: ['marketplace']);
    final tile = find.byKey(const ValueKey('home-marketplace-tile'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tester.getSize(tile).height, closeTo(68, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Marketplace expands naturally for large text on narrow phones', (tester) async {
    await mountHome(tester, 'en', scale: 1.6, width: 320, sections: ['marketplace']);
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('home-marketplace-tile'));
    expect(tile, findsOneWidget);
    expect(tester.getSize(tile).height, greaterThanOrEqualTo(68));
    expect(find.text('Fire safety products & services'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text narrow home keeps shortcuts and remote section settings', (tester) async {
    await mountHome(tester, 'en', scale: 1.6, width: 320, sections: []);
    final grids = tester.widgetList<GridView>(find.byType(GridView)).toList();
    expect((grids.first.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 2);
    expect(find.text('Marketplace'), findsNothing);
    expect(find.text('My preparation'), findsOneWidget);
    expect(find.byTooltip('Admin support').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Notifications').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Professional\ndirectory'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
