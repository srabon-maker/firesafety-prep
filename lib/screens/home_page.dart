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
import 'learning_library_page.dart';
import '../widgets/home_hero_banner.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color red = Color(0xFFE32636);
const Color cream = Color(0xFFFFF8F4);
const Color ink = Color(0xFF27191B);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
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
    _home=HomepageService.fetch('home');
    _jobs=JobCircularService.instance.fetchCirculars();
    _notes=NotesService.instance.fetchNotes();
    // Hidden optional sections may have no FutureBuilder subscriber.
    // Attach an error listener immediately, without replacing the original future.
    _home.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _jobs.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _notes.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }
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
    if (!['jobs','shop','questions','notes','tests','interview','progress','community','notifications'].contains(target)) return;
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
      _=>const NotificationInboxPage(),
    };
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>page));
  }
  Future<void> _searchFor(String value) async {
    final query=value.trim();
    if(query.isEmpty) return;
    final target=await showModalBottomSheet<String>(context:context,builder:(sheet)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Padding(padding:const EdgeInsets.all(16),child:Text('কোথায় খুঁজবেন: $query',maxLines:2,overflow:TextOverflow.ellipsis)),
      for(final item in const [('jobs','চাকরি'),('notes','স্টাডি নোট'),('questions','প্রশ্নের বিভাগ'),('interview','ইন্টারভিউ')])
        ListTile(title:Text(item.$2),trailing:const Icon(Icons.search),onTap:()=>Navigator.pop(sheet,item.$1)),
    ])));
    if(mounted&&target!=null) await _open(target,search:query);
  }
  Widget _heading(String title,{String? target})=>Padding(padding:const EdgeInsets.fromLTRB(2,18,2,6),child:Row(children:[
    Expanded(child:Text(title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800))),
    if(target!=null) TextButton(onPressed:()=>_open(target),child:Text(_tr('সব দেখুন','View all'))),
  ]));
  Widget _tile(String title,IconData icon,Color color,VoidCallback action)=>Card(
    margin:EdgeInsets.zero,
    child:InkWell(borderRadius:BorderRadius.circular(12),onTap:action,child:Padding(padding:const EdgeInsets.all(8),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(width:44,height:44,decoration:BoxDecoration(color:color.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:Theme.of(context).brightness==Brightness.dark?Theme.of(context).colorScheme.primary:color)),
      const SizedBox(height:7),
      Text(title,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
    ]))),
  );
  Widget _careerTile(String title, IconData icon, Color color, VoidCallback action) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19,
              color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.primary : color),
          ),
          const SizedBox(height: 5),
          Text(title, textAlign: TextAlign.center, maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.15, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
  Widget _link(String title,String subtitle,IconData icon,String target)=>Card(child:ListTile(
    leading:Icon(icon,color:Theme.of(context).colorScheme.primary),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right),onTap:()=>_open(target)));
  void _openBanner(Map<String,dynamic> row) {
    final target=HomepageService.text(row,'target');
    final title=AppText.of(context,HomepageService.text(row,'title'),
      HomepageService.text(row,'title_en').isEmpty?HomepageService.text(row,'title'):HomepageService.text(row,'title_en'));
    final body=AppText.of(context,HomepageService.text(row,'body'),
      HomepageService.text(row,'body_en').isEmpty?HomepageService.text(row,'body'):HomepageService.text(row,'body_en'));
    showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
      title:Text(title),content:SingleChildScrollView(child:Text(body)),actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('বন্ধ করুন')),
        if(target!='none') TextButton(onPressed:(){Navigator.pop(dialog);_open(target);},child:const Text('দেখুন')),
      ],
    ));
  }
  Widget _content(Map<String,dynamic> row,{bool banner=false}) {
    final image=HomepageService.text(row,'image_url');
    final target=HomepageService.text(row,'target');
    final title=AppText.of(context,HomepageService.text(row,'title'),HomepageService.text(row,'title_en').isEmpty?HomepageService.text(row,'title'):HomepageService.text(row,'title_en'));
    final body=AppText.of(context,HomepageService.text(row,'body'),HomepageService.text(row,'body_en').isEmpty?HomepageService.text(row,'body'):HomepageService.text(row,'body_en'));
    return Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>showDialog<void>(context:context,builder:(dialog)=>AlertDialog(title:Text(title),content:SingleChildScrollView(child:Text(body)),actions:[
      TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('বন্ধ করুন')),
      if(target!='none') TextButton(onPressed:(){Navigator.pop(dialog);_open(target);},child:const Text('দেখুন')),
    ])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
      if(banner&&HomepageService.safeImage(image)) Image.network(image,height:88,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),
      Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),
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
      case 'progress':return FsFeatureCard(icon: Icons.track_changes_rounded,
        title: _tr('আজকের প্রস্তুতি','Today’s preparation'),
        subtitle: _tr('দৈনিক লক্ষ্য, অনুশীলন ও অগ্রগতি','Daily goals, practice and progress'),
        onTap: () => _open('progress'));
      case 'jobs':return Column(children:[_heading(_tr('সর্বশেষ চাকরির বিজ্ঞপ্তি','Latest jobs'),target:'jobs'),FutureBuilder<List<JobCircular>>(future:_jobs,builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const FsLoadingCards(count: 2);
        if(snapshot.hasError)return FsStatusCard(icon: Icons.cloud_off_outlined, message: _tr('চাকরির খবর লোড হয়নি।','Jobs could not load.'), onRetry: _refresh);
        final jobs=(snapshot.data??[]).where((j)=>!j.isExpired).toList()..sort((a,b)=>b.publishedAt.compareTo(a.publishedAt));
        if(jobs.isEmpty)return const Text('বর্তমানে কোনো প্রকাশিত চলমান বিজ্ঞপ্তি নেই।');
        return Column(children:[for(final job in jobs.take(3)) Card(child:ListTile(leading:const Icon(Icons.work_outline),title:Text(job.title,maxLines:2,overflow:TextOverflow.ellipsis),subtitle:Text(job.organization),trailing:const Icon(Icons.chevron_right),onTap:()=>_open('jobs',search:job.title)))]);
      })]);
      case 'notes':return Column(children:[_heading(_tr('নতুন স্টাডি নোট','New study notes'),target:'notes'),FutureBuilder<StudyNotesPage>(future:_notes,builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const FsLoadingCards(count: 2);
        if(snapshot.hasError)return FsStatusCard(icon: Icons.cloud_off_outlined, message: _tr('নোট লোড হয়নি।','Notes could not load.'), onRetry: _refresh);
        final notes=snapshot.data?.notes??[];
        if(notes.isEmpty)return const Text('কোনো প্রকাশিত নোট নেই।');
        return Column(children:[for(final note in notes.take(3)) Card(child:ListTile(leading:const Icon(Icons.menu_book_outlined),title:Text(note.title,maxLines:2,overflow:TextOverflow.ellipsis),subtitle:Text(note.categoryName??''),trailing:const Icon(Icons.chevron_right),onTap:()=>_open('notes',search:note.title)))]);
      })]);
      case 'marketplace':return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
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
              onTap: () => _open('shop'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.storefront, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Fire Safety Marketplace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(AppText.of(context, 'ফায়ার সেফটি পণ্য ও সার্ভিস', 'Fire safety products & services'), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text(AppText.of(context, 'শপে প্রবেশ করুন', 'Explore shop'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                  ])),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                ]),
              ),
            ),
          ),
        ),
      );
      case 'community':return _link('ফায়ার সেফটি কমিউনিটি','অভিজ্ঞতা, প্রশ্ন ও আলোচনা',Icons.groups_outlined,'community');
      case 'tips':
        final rows=data==null?<Map<String,dynamic>>[]:HomepageService.rows(data['tips']);
        return rows.isEmpty?const SizedBox.shrink():Column(children:[_heading(_tr('সেফটি টিপস','Safety tips')),for(final row in rows)_content(row)]);
      default:return const SizedBox.shrink();
    }
  }
  @override
  Widget build(BuildContext context)=>RefreshIndicator(onRefresh:_refresh,child:ListView(
    padding:EdgeInsets.zero,physics:const AlwaysScrollableScrollPhysics(),children:[
      Container(padding:EdgeInsets.fromLTRB(18,MediaQuery.paddingOf(context).top+14,18,22),
        decoration:const BoxDecoration(gradient:LinearGradient(colors:[deepMaroon,maroon,Color(0xFF8D1723)]),borderRadius:BorderRadius.vertical(bottom:Radius.circular(28))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:48,height:48,padding:const EdgeInsets.all(2),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12)),child:ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.asset('assets/fire_safety_job_prep_logo.png',fit:BoxFit.contain))),
            const SizedBox(width:12),
            const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Fire Safety BD',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w800)),
              Text('Learn • Prepare • Connect',style:TextStyle(color:Colors.white70,fontSize:11)),
            ])),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                tooltip: _tr('নোটিফিকেশন', 'Notifications'),
                onPressed: () => _open('notifications'),
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ]),
          const SizedBox(height:16),
          TextField(controller:_search,textInputAction:TextInputAction.search,maxLength:120,onSubmitted:_searchFor,style:const TextStyle(color:ink),decoration:InputDecoration(counterText:'',hintText:_tr('প্রশ্নের বিভাগ, নোট, চাকরি খুঁজুন...','Search questions, notes, jobs...'),hintStyle:const TextStyle(color:Colors.black54,fontSize:13),filled:true,fillColor:Colors.white,prefixIcon:const Icon(Icons.search,color:maroon),suffixIcon:IconButton(onPressed:()=>_searchFor(_search.text),icon:const Icon(Icons.arrow_forward,color:maroon)))),
        ])),
      Padding(padding:const EdgeInsets.fromLTRB(14,6,14,24),child:FutureBuilder<Map<String,dynamic>>(future:_home,builder:(context,snapshot){
        final data=snapshot.hasData?snapshot.data:null;
        // The retired topic shortcuts must not reappear via remote configuration.
        final sections=(data==null?HomepageService.defaultSections:HomepageService.sections(data['sections']))
            .where((key)=>key!='topics').toList();
        final policy=data?['access_policy'];
        final pending=policy is Map&&policy['mode']=='free'&&policy['scheduled_mode']!='free';
        final activation=policy is Map?DateTime.tryParse(policy['starts_at']?.toString()??'')?.toUtc().add(const Duration(hours:6)):null;
        // Quick access and the bottom navigation cannot be hidden by remote configuration.
        final top=sections.isNotEmpty&&sections.first=='banners';
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(pending&&activation!=null)Card(child:ListTile(leading:const Icon(Icons.campaign_outlined,color:maroon),title:const Text('Premium সুবিধা চালুর আগাম নোটিশ'),subtitle:Text('এখন সব Free। লক কার্যকর হবে: ${activation.toString().substring(0,16)} (বাংলাদেশ সময়)।'))),
          if(top)_section('banners',data),
          const SizedBox(height: 12),
          LayoutBuilder(builder:(context,box)=>GridView.count(padding:EdgeInsets.zero,crossAxisCount:box.maxWidth<320||MediaQuery.textScalerOf(context).scale(13)>17?2:box.maxWidth>=700?4:3,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:8,mainAxisSpacing:8,mainAxisExtent:MediaQuery.textScalerOf(context).scale(13)>17?145:118,children:[for(final item in _quick)_tile(AppText.of(context,item.$2,item.$3),item.$4,item.$5,()=>_open(item.$1))])),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: maroon,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tr('ক্যারিয়ার ডেভেলপমেন্ট', 'Career development'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        height: 1,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
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
                    mainAxisExtent: largeText ? 128 : 92,
                    children: [
                      for (final item in const [
                        ('alerts', 'চাকরির এলার্ট', 'Job alerts', Icons.notifications_active_outlined, Color(0xFFB83228)),
                        ('mock', 'মক ইন্টারভিউ', 'Mock interview', Icons.record_voice_over_outlined, Color(0xFF7142B8)),
                        ('courses', 'প্রশিক্ষণ ও কোর্স', 'Training & courses', Icons.school_outlined, Color(0xFF20834B)),
                        ('directory', 'পেশাজীবী ডিরেক্টরি', 'Professional directory', Icons.groups_outlined, Color(0xFF14799A)),
                      ])
                        _careerTile(_tr(item.$2, item.$3), item.$4, item.$5,
                          () => CareerPage.open(context, section: item.$1)),
                    ],
                  );
                }),
              ],
            ),
          ),
          if(snapshot.hasError) const Padding(padding:EdgeInsets.only(top:10),child:Text('হোমপেজ আপডেট এখন পাওয়া যাচ্ছে না। মূল সেবা ব্যবহার করুন।')),
          for(final key in sections) if(!top||key!='banners')_section(key,data),
        ]);
      })),
    ],
  ));
}
