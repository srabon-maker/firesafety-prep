import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import '../models/job_circular.dart';
import '../models/study_note.dart';
import '../services/auth_guard.dart';
import '../services/homepage_service.dart';
import '../services/job_circular_service.dart';
import '../services/notes_service.dart';
import '../settings/app_settings.dart';
import 'jobs_page.dart';
import 'career_page.dart';
import 'tests_page.dart';
import 'notes_page.dart';
import 'marketplace_page.dart';
import 'community_page.dart';
import 'notification_inbox_page.dart';
import 'support_page.dart';
import 'learning_library_page.dart';
import '../widgets/home_hero_banner.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color red = Color(0xFFE32636);
const Color cream = Color(0xFFFFF8F4);
const Color ink = Color(0xFF27191B);

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.loadHome, this.loadJobs, this.loadNotes});
  final Future<Map<String, dynamic>> Function()? loadHome;
  final Future<List<JobCircular>> Function()? loadJobs;
  final Future<StudyNotesPage> Function()? loadNotes;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _tr(String bn, String en) => AppText.of(context, bn, en);
  final _search = TextEditingController();
  late Future<Map<String,dynamic>> _home;
  late Future<List<JobCircular>> _jobs;
  late Future<StudyNotesPage> _notes;
  static const _quick = [
    ('jobs','চাকরির খবর','Jobs',Icons.work_outline,Color(0xFFB83228)),
    ('questions','প্রশ্ন ব্যাংক','Question bank',Icons.quiz_outlined,Color(0xFF7142B8)),
    ('notes','স্টাডি নোট','Study notes',Icons.menu_book_outlined,Color(0xFF20834B)),
    ('tests','মডেল টেস্ট','Model tests',Icons.assignment_outlined,Color(0xFF9E1630)),
    ('interview','ইন্টারভিউ','Interview',Icons.forum_outlined,Color(0xFFB36A14)),
    ('progress','আমার প্রস্তুতি','My preparation',Icons.insights,Color(0xFF14799A)),
  ];
  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    _home=widget.loadHome?.call() ?? HomepageService.fetch('home');
    _jobs=widget.loadJobs?.call() ?? JobCircularService.instance.fetchCirculars();
    _loadNotesPreview();
    // Hidden optional sections may have no FutureBuilder subscriber.
    // Attach an error listener immediately, without replacing the original future.
    _home.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _jobs.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }
  void _loadNotesPreview() {
    _notes = widget.loadNotes?.call() ?? NotesService.instance.fetchNotes(summaryOnly: true);
    _notes.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }
  void _retryNotesPreview() => setState(_loadNotesPreview);
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _refresh() async {
    setState(_load);
    await Future.wait<void>([
      _home.then<void>((_) {},onError:(Object _,StackTrace __){}),
      _jobs.then<void>((_) {},onError:(Object _,StackTrace __){}),
      _notes.then<void>((_) {},onError:(Object _,StackTrace __){}),
    ]);
  }
  Future<void> _open(String target, {String search=''}) async {
    if (target == 'career') { await CareerPage.open(context); return; }
    if (!['jobs','shop','questions','notes','tests','interview','progress','community','notifications','support'].contains(target)) return;
    if (target!='jobs' && target!='shop') {
      if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    }
    if (!mounted) return;
    final Widget page = switch(target) {
      'jobs'=>JobsPage(initialSearch:search),
      'questions'=>QuestionBankPage(initialSearch:search),
      'notes'=>NotesPage(initialSearch:search),
      'tests'=>const TestsPage(),
      'interview'=>InterviewPage(initialSearch:search),
      'progress'=>const PracticeDashboardPage(),
      'shop'=>const MarketplacePage(),
      'community'=>const CommunityPage(),
      'support'=>const SupportPage(generalSupport: true),
      _=>const NotificationInboxPage(),
    };
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>page));
    if (mounted && target == 'notes') _retryNotesPreview();
  }
  Future<void> _searchFor(String value) async {
    final query=value.trim();
    if(query.isEmpty) return;
    final target=await showModalBottomSheet<String>(context:context,builder:(sheet)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Padding(padding:const EdgeInsets.all(16),child:Text(_tr('কোথায় খুঁজবেন: $query','Search in: $query'),maxLines:2,overflow:TextOverflow.ellipsis)),
      for(final item in const [('jobs','চাকরি','Jobs'),('notes','স্টাডি নোট','Study notes'),('questions','প্রশ্নের বিভাগ','Question categories'),('interview','ইন্টারভিউ','Interview')])
        ListTile(title:Text(_tr(item.$2,item.$3)),trailing:const Icon(Icons.search),onTap:()=>Navigator.pop(sheet,item.$1)),
    ])));
    if(mounted&&target!=null) await _open(target,search:query);
  }
  Widget _heading(String title,{String? target})=>Padding(padding:const EdgeInsets.fromLTRB(2,8,2,2),child:Row(children:[
    Expanded(child:Text(title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w600))),
    if(target!=null) TextButton(onPressed:()=>_open(target),style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:8),minimumSize:const Size(48,44)),child:Text(_tr('সব দেখুন','View all'))),
  ]));
  // Keep each shortcut's semantic colour, with lighter tones on dark cards.
  Color _shortcutIconColor(Color color) {
    if (Theme.of(context).brightness != Brightness.dark) return color;
    return <Color, Color>{
      Color(0xFFB83228): Color(0xFFF29B91),
      Color(0xFF7142B8): Color(0xFFBBA1F5),
      Color(0xFF20834B): Color(0xFF80CDA4),
      Color(0xFF9E1630): Color(0xFFF5A1B8),
      Color(0xFFB36A14): Color(0xFFE5B16C),
      Color(0xFF14799A): Color(0xFF80C4E6),
    }[color] ?? Theme.of(context).colorScheme.primary;
  }

  RoundedRectangleBorder _shortcutShape() => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .40)),
  );

  Widget _tile(String title,IconData icon,Color color,VoidCallback action)=>Card(
    margin:EdgeInsets.zero, shape:_shortcutShape(),
    child:InkWell(borderRadius:BorderRadius.circular(14),onTap:action,child:Padding(padding:const EdgeInsets.all(5),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(width:36,height:36,decoration:BoxDecoration(color:color.withValues(alpha:.13),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:_shortcutIconColor(color),size:22)),
      const SizedBox(height:4),
      Text(title,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w500,fontSize:12,height:1.2)),
    ]))),
  );
  Widget _careerTile(String target, String title, IconData icon, Color color, VoidCallback action) => Card(
    key: ValueKey('home-career-$target'),
    margin: EdgeInsets.zero,
    shape: _shortcutShape(),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 6, 3, 3),
        child: Column(children: [
          Container(
            key: ValueKey('home-career-icon-$target'),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19,
              color: _shortcutIconColor(color)),
          ),
          const SizedBox(height: 3),
          Expanded(child: Center(child: Text(title, textAlign: TextAlign.center, maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.15, fontWeight: FontWeight.w500)))),
        ]),
      ),
    ),
  );
  void _openBanner(Map<String,dynamic> row) {
    final target=HomepageService.text(row,'target');
    final title=AppText.of(context,HomepageService.text(row,'title'),
      HomepageService.text(row,'title_en').isEmpty?HomepageService.text(row,'title'):HomepageService.text(row,'title_en'));
    final body=AppText.of(context,HomepageService.text(row,'body'),
      HomepageService.text(row,'body_en').isEmpty?HomepageService.text(row,'body'):HomepageService.text(row,'body_en'));
    showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
      title:Text(title),content:SingleChildScrollView(child:Text(body)),actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog),child:Text(_tr('বন্ধ করুন','Close'))),
        if(target!='none') TextButton(onPressed:(){Navigator.pop(dialog);_open(target);},child:Text(_tr('দেখুন','View'))),
      ],
    ));
  }
  Widget _content(Map<String,dynamic> row,{bool banner=false}) {
    final image=HomepageService.text(row,'image_url');
    final target=HomepageService.text(row,'target');
    final title=AppText.of(context,HomepageService.text(row,'title'),HomepageService.text(row,'title_en').isEmpty?HomepageService.text(row,'title'):HomepageService.text(row,'title_en'));
    final body=AppText.of(context,HomepageService.text(row,'body'),HomepageService.text(row,'body_en').isEmpty?HomepageService.text(row,'body'):HomepageService.text(row,'body_en'));
    return Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>showDialog<void>(context:context,builder:(dialog)=>AlertDialog(title:Text(title),content:SingleChildScrollView(child:Text(body)),actions:[
      TextButton(onPressed:()=>Navigator.pop(dialog),child:Text(_tr('বন্ধ করুন','Close'))),
      if(target!='none') TextButton(onPressed:(){Navigator.pop(dialog);_open(target);},child:Text(_tr('দেখুন','View'))),
    ])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
      if(banner&&HomepageService.safeImage(image)) Image.network(image,height:88,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),
      Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600)),
        const SizedBox(height:5),Text(body,maxLines:2,overflow:TextOverflow.ellipsis),
      ])),
    ])));
  }
  Widget _section(String key,Map<String,dynamic>? data) {
    switch(key) {
      case 'banners':
        final rows=data==null?<Map<String,dynamic>>[]:HomepageService.rows(data['banners']);
        if(rows.isEmpty)return const SizedBox.shrink();
        return HomeHeroBanner(items: rows, onOpen: _openBanner);
      case 'jobs':return Column(children:[_heading(_tr('সর্বশেষ চাকরির বিজ্ঞপ্তি','Latest jobs'),target:'jobs'),FutureBuilder<List<JobCircular>>(future:_jobs,builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const FsLoadingCards(count: 2);
        if(snapshot.hasError)return FsStatusCard(icon: Icons.cloud_off_outlined, message: _tr('চাকরির খবর লোড হয়নি।','Jobs could not load.'), onRetry: _refresh);
        final jobs=(snapshot.data??[]).where((j)=>!j.isExpired).toList()..sort((a,b)=>b.publishedAt.compareTo(a.publishedAt));
        if(jobs.isEmpty)return FsStatusCard(icon:Icons.work_outline,message:_tr('বর্তমানে কোনো চলমান বিজ্ঞপ্তি নেই।','No active jobs published.'));
        return Column(children:[for(final job in jobs.take(3)) _previewCard(icon:Icons.work_outline,title:job.title,subtitle:job.organization.trim(),compactJob:true,onTap:()=>_open('jobs',search:job.title))]);
      })]);
      case 'notes':return Column(children:[_heading(_tr('নতুন স্টাডি নোট','New study notes'),target:'notes'),FutureBuilder<StudyNotesPage>(future:_notes,builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const FsLoadingCards(count: 2);
        if(snapshot.hasError) {
          final error = snapshot.error;
          return FsStatusCard(icon: Icons.cloud_off_outlined,
            message: error is NotesLoadException ? _tr(error.message(), error.message(english: true)) : _tr('নোট লোড হয়নি।','Notes could not load.'),
            onRetry: _retryNotesPreview);
        }
        final notes=snapshot.data?.notes??[];
        if(notes.isEmpty)return FsStatusCard(icon:Icons.menu_book_outlined,message:_tr('কোনো প্রকাশিত নোট নেই।','No notes published.'));
        return Column(children:[for(final note in notes.take(3)) _previewCard(icon:note.locked?Icons.lock_outline:Icons.menu_book_outlined,title:note.title,subtitle:note.displayCategory(Localizations.localeOf(context).languageCode),onTap:()=>_open('notes',search:note.title))]);
      })]);
      case 'marketplace':return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [deepMaroon, maroon, Color(0xFF8D1723)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              key: const ValueKey('home-marketplace-tile'),
              onTap: () => _open('shop'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                child: Row(children: [
                  Container(
                    key: const ValueKey('home-marketplace-icon'),
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.storefront, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(key: const ValueKey('home-marketplace-labels'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_tr('মার্কেটপ্লেস','Marketplace'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15, height: 1.2)),
                    const SizedBox(height: 1),
                    Text(AppText.of(context, 'ফায়ার সেফটি পণ্য ও সার্ভিস', 'Fire safety products & services'), style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.2)),
                  ])),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                ]),
              ),
            ),
          ),
        ),
      );
      case 'tips':
        final rows=data==null?<Map<String,dynamic>>[]:HomepageService.rows(data['tips']);
        return rows.isEmpty?const SizedBox.shrink():Column(children:[_heading(_tr('সেফটি টিপস','Safety tips')),for(final row in rows)_content(row)]);
      default:return const SizedBox.shrink();
    }
  }
  Widget _previewCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool compactJob = false}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(margin:const EdgeInsets.only(bottom:6),clipBehavior:Clip.antiAlias,
      child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:2),
        leading:Container(width:36,height:36,decoration:BoxDecoration(color:scheme.primary.withValues(alpha:.12),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:scheme.primary,size:21)),
        title:compactJob ? Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(title,maxLines:2,overflow:TextOverflow.ellipsis,
              style:theme.textTheme.titleSmall?.copyWith(fontSize:14,height:1.2,fontWeight:FontWeight.w600)),
            if(subtitle.trim().isNotEmpty)...[
              const SizedBox(height:2),
              Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,
                style:theme.textTheme.bodySmall?.copyWith(fontSize:12,height:1.2,fontWeight:FontWeight.w400,color:scheme.onSurfaceVariant)),
            ],
          ],
        ) : Text(title,maxLines:2,overflow:TextOverflow.ellipsis,style:theme.textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w600)),
        subtitle:compactJob||subtitle.trim().isEmpty?null:Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:theme.textTheme.bodySmall?.copyWith(color:scheme.onSurfaceVariant)),
        trailing:Icon(Icons.chevron_right,color:scheme.primary,size:20),onTap:onTap));
  }
  @override
  Widget build(BuildContext context)=>DecoratedBox(
    key: const ValueKey('home-status-gradient'),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [deepMaroon, maroon, Color(0xFF8D1723)])),
    child:SafeArea(bottom:false,left:false,right:false,child:ColoredBox(color:Theme.of(context).scaffoldBackgroundColor,child:RefreshIndicator(onRefresh:_refresh,child:ListView(
    padding:EdgeInsets.zero,physics:const AlwaysScrollableScrollPhysics(),children:[
      Container(padding:const EdgeInsets.fromLTRB(14,8,14,12),
        decoration:const BoxDecoration(gradient:LinearGradient(colors:[deepMaroon,maroon,Color(0xFF8D1723)]),borderRadius:BorderRadius.vertical(bottom:Radius.circular(20))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(
              key: const ValueKey('home-brand-icon'),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28, height: 28,
                child: CustomPaint(
                  key: ValueKey('home-brand-flame'),
                  painter: _HomeBrandFlamePainter(),
                ),
              ),
            ),
            const SizedBox(width:10),
            const Expanded(child: _HomeBrandTitle()),
            IconButton(
              key: const ValueKey('home-admin-support'),
              tooltip: _tr('অ্যাডমিন সাপোর্ট', 'Admin support'),
              onPressed: () => _open('support'),
              icon: Container(width:34,height:34,
                decoration:BoxDecoration(color:Colors.white.withValues(alpha:.12),borderRadius:BorderRadius.circular(10)),
                child:const Icon(Icons.support_agent_rounded,color:Colors.white,size:21)),
            ),
            IconButton(
              tooltip: _tr('নোটিফিকেশন', 'Notifications'),
              onPressed: () => _open('notifications'),
              icon: Container(width:34,height:34,
                decoration:BoxDecoration(color:Colors.white.withValues(alpha:.12),borderRadius:BorderRadius.circular(10)),
                child:const Icon(Icons.notifications_none_rounded,color:Colors.white,size:20)),
            ),
          ]),
          const SizedBox(height:8),
          Builder(builder: (context) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final scheme = Theme.of(context).colorScheme;
            final iconColor = dark ? scheme.primary : maroon;
            final border = OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: dark ? scheme.outlineVariant : Colors.transparent),
            );
            return TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              maxLength: 120,
              onSubmitted: _searchFor,
              style: TextStyle(color: dark ? scheme.onSurface : ink),
              cursorColor: iconColor,
              decoration: InputDecoration(
                counterText: '',
                hintText: _tr('প্রশ্ন, নোট, চাকরি খুঁজুন', 'Search questions, notes, jobs'),
                hintStyle: TextStyle(color: dark ? scheme.onSurfaceVariant : Colors.black54, fontSize: 13),
                filled: true,
                fillColor: dark ? scheme.surface : Colors.white,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(borderSide: BorderSide(color: iconColor, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: Icon(Icons.search, color: iconColor),
                suffixIcon: IconButton(
                  tooltip: _tr('খুঁজুন', 'Search'),
                  onPressed: () => _searchFor(_search.text),
                  icon: Icon(Icons.arrow_forward, color: iconColor),
                ),
              ),
            );
          }),
        ])),
      Padding(padding:const EdgeInsets.fromLTRB(14,4,14,20),child:FutureBuilder<Map<String,dynamic>>(future:_home,builder:(context,snapshot){
        final data=snapshot.hasData?snapshot.data:null;
        // The retired topic shortcuts must not reappear via remote configuration.
        final sections=(data==null?HomepageService.defaultSections:HomepageService.sections(data['sections']))
            .where((key)=>!const {'topics','progress','community'}.contains(key)).toList();
        final policy=data?['access_policy'];
        final pending=policy is Map&&policy['mode']=='free'&&policy['scheduled_mode']!='free';
        final activation=policy is Map?DateTime.tryParse(policy['starts_at']?.toString()??'')?.toUtc().add(const Duration(hours:6)):null;
        // Quick access and the bottom navigation cannot be hidden by remote configuration.
        final top=sections.isNotEmpty&&sections.first=='banners';
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(pending&&activation!=null)Card(child:ListTile(leading:Icon(Icons.campaign_outlined,color:Theme.of(context).colorScheme.primary),title:Text(_tr('Premium সুবিধা চালুর আগাম নোটিশ','Upcoming Premium access')),subtitle:Text(_tr('এখন সব Free। লক কার্যকর হবে: ${activation.toString().substring(0,16)} (বাংলাদেশ সময়)।','Currently free. Access restrictions begin: ${activation.toString().substring(0,16)} (Bangladesh time).')))),
          if(top)_section('banners',data),
          const SizedBox(height: 8),
          LayoutBuilder(builder:(context,box)=>GridView.count(padding:EdgeInsets.zero,crossAxisCount:box.maxWidth<320||MediaQuery.textScalerOf(context).scale(13)>17?2:box.maxWidth>=700?4:3,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:8,mainAxisSpacing:8,mainAxisExtent:MediaQuery.textScalerOf(context).scale(13)>17?145.0:80.0+(MediaQuery.textScalerOf(context).scale(13)-13).clamp(0.0,4.0).toDouble()*3,children:[for(final item in _quick)_tile(AppText.of(context,item.$2,item.$3),item.$4,item.$5,()=>_open(item.$1))])),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.work_outline,color:Theme.of(context).colorScheme.primary,size:20),
            const SizedBox(width:6),
            Expanded(child:Text(_tr('ক্যারিয়ার ডেভেলপমেন্ট','Career development'),
              style:Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
                LayoutBuilder(builder: (context, box) {
                  final largeText = MediaQuery.textScalerOf(context).scale(13) > 17;
                  // Four compact shortcuts in one row at normal phone widths.
                  final columns = box.maxWidth < 260 || largeText ? 2 : 4;
                  return GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    mainAxisExtent: largeText ? 128.0 : (box.maxWidth < 320 ? 84.0 : 78.0) + (MediaQuery.textScalerOf(context).scale(13) - 13).clamp(0.0, 4.0).toDouble() * 3,
                    children: [
                      for (final item in const [
                        ('alerts', 'চাকরির\nঅ্যালার্ট', 'Job\nalerts', Icons.notifications_active_outlined, Color(0xFFB83228)),
                        ('mock', 'মক\nইন্টারভিউ', 'Mock\ninterview', Icons.record_voice_over_outlined, Color(0xFF7142B8)),
                        ('courses', 'প্রশিক্ষণ\nও কোর্স', 'Training\n& courses', Icons.school_outlined, Color(0xFF20834B)),
                        ('directory', 'পেশাজীবী\nডিরেক্টরি', 'Professional\ndirectory', Icons.groups_outlined, Color(0xFF14799A)),
                      ])
                        _careerTile(item.$1, _tr(item.$2, item.$3), item.$4, item.$5,
                          () => CareerPage.open(context, section: item.$1)),
                    ],
                  );
                }),
          if(snapshot.hasError) Padding(padding:const EdgeInsets.only(top:10),child:Text(_tr('হোমপেজ আপডেট এখন পাওয়া যাচ্ছে না। মূল সেবা ব্যবহার করুন।','Home updates unavailable. Main services remain accessible.'))),
          for(final key in sections) if(!top||key!='banners')_section(key,data),
        ]);
      })),
    ],
  )))));
}

// Same approved outline path as assets/launcher_foreground.svg. Paint directly
// at device resolution so the small header mark remains sharp at every density.
class _HomeBrandFlamePainter extends CustomPainter {
  const _HomeBrandFlamePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(258, 109)
      ..cubicTo(265, 105, 269, 109, 271, 118)
      ..cubicTo(274, 137, 279, 149, 294, 165)
      ..cubicTo(318, 189, 333, 211, 333, 240)
      ..cubicTo(333, 283, 300, 317, 257, 317)
      ..cubicTo(215, 317, 180, 280, 180, 242)
      ..cubicTo(180, 224, 188, 207, 197, 199)
      ..cubicTo(203, 193, 209, 197, 211, 205)
      ..cubicTo(214, 216, 219, 221, 227, 220)
      ..cubicTo(241, 220, 244, 207, 236, 190)
      ..cubicTo(228, 174, 223, 165, 226, 151)
      ..cubicTo(230, 134, 242, 119, 258, 109)
      ..close()
      ..moveTo(256, 136)
      ..cubicTo(246, 146, 243, 155, 247, 167)
      ..cubicTo(250, 177, 259, 190, 259, 204)
      ..cubicTo(260, 225, 247, 240, 227, 240)
      ..cubicTo(216, 240, 208, 235, 202, 229)
      ..cubicTo(196, 248, 203, 266, 219, 282)
      ..cubicTo(230, 293, 243, 298, 257, 298)
      ..cubicTo(288, 298, 314, 273, 314, 241)
      ..cubicTo(314, 218, 302, 201, 283, 181)
      ..cubicTo(267, 164, 259, 152, 256, 136)
      ..close();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = size.shortestSide / 212;
    canvas.scale(scale);
    canvas.translate(-256.5, -212.5);
    canvas.drawPath(path, Paint()
      ..color = Colors.white
      ..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HomeBrandFlamePainter oldDelegate) => false;
}


// Keep the actual title as a normal Text widget: its original font, layout,
// ellipsis and accessibility remain unchanged. Color only the counters behind
// the white B and D glyphs, using the measured text positions and baseline.
class _HomeBrandTitle extends StatelessWidget {
  const _HomeBrandTitle();
  static const _label = 'Fire Safety BD';
  static const _style = TextStyle(
    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600,
    height: 1.05, letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    return CustomPaint(
      key: const ValueKey('home-brand-bd-counters'),
      painter: _HomeBrandCountersPainter(
        style: defaults.style.merge(_style),
        textScaler: MediaQuery.textScalerOf(context),
        direction: Directionality.of(context),
        locale: Localizations.maybeLocaleOf(context),
        textHeightBehavior: defaults.textHeightBehavior,
      ),
      child: const Text(
        _label,
        key: ValueKey('home-brand-title'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _style,
      ),
    );
  }
}

class _HomeBrandCountersPainter extends CustomPainter {
  const _HomeBrandCountersPainter({
    required this.style, required this.textScaler, required this.direction,
    required this.locale, required this.textHeightBehavior,
  });

  final TextStyle style;
  final TextScaler textScaler;
  final TextDirection direction;
  final Locale? locale;
  final TextHeightBehavior? textHeightBehavior;

  @override
  void paint(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(text: _HomeBrandTitle._label, style: style),
      textDirection: direction,
      textScaler: textScaler,
      locale: locale,
      textHeightBehavior: textHeightBehavior,
      maxLines: 1,
      ellipsis: '\u2026',
    )..layout(maxWidth: size.width);
    try {
      // Do not paint any floating marks when the title is truncated.
      if (text.didExceedMaxLines) return;
      final lines = text.computeLineMetrics();
      if (lines.isEmpty) return;
      final baseline = lines.first.baseline;
      final em = textScaler.scale(style.fontSize ?? 20);
      // Nominal Android sans-serif counter silhouettes, slightly overlapping
      // the white strokes. The real text is painted above them.
      final b = Path()
        ..moveTo(375, 1295)
        ..lineTo(655, 1295)
        ..quadraticBezierTo(960, 1295, 960, 1040)
        ..quadraticBezierTo(960, 790, 655, 790)
        ..lineTo(375, 790)
        ..close()
        ..moveTo(375, 710)
        ..lineTo(700, 710)
        ..quadraticBezierTo(985, 710, 985, 430)
        ..quadraticBezierTo(985, 145, 685, 145)
        ..lineTo(375, 145)
        ..close();
      final d = Path()
        ..moveTo(375, 1295)
        ..lineTo(580, 1295)
        ..cubicTo(875, 1295, 1035, 1040, 1035, 750)
        ..cubicTo(1035, 420, 875, 145, 570, 145)
        ..lineTo(375, 145)
        ..close();
      void fill(int offset, Path path, Color color, double advance) {
        final boxes = text.getBoxesForSelection(
          TextSelection(baseOffset: offset, extentOffset: offset + 1),
        );
        if (boxes.length != 1) return;
        final rect = boxes.single.toRect();
        if (rect.width <= 0) return;
        canvas.save();
        canvas.clipRect(Offset.zero & size);
        canvas.translate(rect.left, baseline);
        canvas.scale(rect.width / advance, -em / 2048);
        canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
        canvas.restore();
      }
      fill(12, b, const Color(0xFF006A4E), 1300);
      fill(13, d, const Color(0xFFB91025), 1335);
    } finally {
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _HomeBrandCountersPainter oldDelegate) =>
      style != oldDelegate.style || textScaler != oldDelegate.textScaler ||
      direction != oldDelegate.direction || locale != oldDelegate.locale ||
      textHeightBehavior != oldDelegate.textHeightBehavior;
}
