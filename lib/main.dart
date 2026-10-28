import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

void main() => runApp(const FireSafetyJobPrepApp());

const maroon = Color(0xFF650D18);
const deepMaroon = Color(0xFF36060D);
const cream = Color(0xFFFFF8F4);
const ink = Color(0xFF27191B);
const apiUrl = 'https://fire.manobikishwarganj.com/api/get_questions.php';

class FireSafetyJobPrepApp extends StatelessWidget {
  const FireSafetyJobPrepApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Fire Safety Job Prep',
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: maroon),
      appBarTheme: const AppBarTheme(backgroundColor: maroon, foregroundColor: Colors.white)),
    home: const MainShell(),
  );
}

class PrepQuestion {
  final int id;
  final String category, question, a, b, c, d, answer, explanation;
  const PrepQuestion({required this.id, required this.category, required this.question,
    required this.a, required this.b, required this.c, required this.d,
    required this.answer, required this.explanation});
  factory PrepQuestion.fromJson(Map<String,dynamic> j) => PrepQuestion(
    id: int.tryParse('${j['id']}') ?? 0, category: '${j['category'] ?? ''}',
    question: '${j['question'] ?? ''}', a: '${j['option_a'] ?? ''}',
    b: '${j['option_b'] ?? ''}', c: '${j['option_c'] ?? ''}',
    d: '${j['option_d'] ?? ''}', answer: '${j['correct_answer'] ?? ''}'.trim().toUpperCase(),
    explanation: '${j['explanation'] ?? ''}');
  List<MapEntry<String,String>> get options => [
    MapEntry('A',a), MapEntry('B',b), MapEntry('C',c), MapEntry('D',d)];
}

Future<List<PrepQuestion>> loadQuestions() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await client.getUrl(Uri.parse(apiUrl));
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw Exception('সার্ভার সমস্যা: HTTP ${res.statusCode}');
    final data = jsonDecode(body);
    if (data is! Map || data['success'] != true) throw Exception('API থেকে প্রশ্ন পাওয়া যায়নি।');
    return (data['questions'] as List? ?? [])
      .whereType<Map>().map((e) => PrepQuestion.fromJson(Map<String,dynamic>.from(e)))
      .where((q) => q.question.trim().isNotEmpty).toList();
  } on SocketException {
    throw Exception('ইন্টারনেট সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।');
  } finally { client.close(force: true); }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int tab = 0;
  @override Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: tab, children: const [HomePage(), CommunityPage(), NotesPage(), ProfilePage()]),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v)=>setState(()=>tab=v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label:'হোম'),
        NavigationDestination(icon: Icon(Icons.forum_outlined), label:'কমিউনিটি'),
        NavigationDestination(icon: Icon(Icons.menu_book_outlined), label:'নোট'),
        NavigationDestination(icon: Icon(Icons.person_outline), label:'প্রোফাইল'),
      ]),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  static const cats = [
    ('চাকরির সার্কুলার', Icons.work_outline, Color(0xFFFFE7DD), Color(0xFFB83228)),
    ('মডেল টেস্ট', Icons.assignment_outlined, Color(0xFFFFE8E8), Color(0xFF9E1630)),
    ('ফায়ার', Icons.local_fire_department, Color(0xFFFFE2DF), Color(0xFFD92735)),
    ('সেইফটি', Icons.health_and_safety_outlined, Color(0xFFE4F4E7), Color(0xFF20834B)),
    ('কমপ্লায়েন্স', Icons.verified_user_outlined, Color(0xFFF0E7FF), Color(0xFF7142B8)),
    ('টেকনিক্যাল', Icons.settings_outlined, Color(0xFFE2F3FA), Color(0xFF14799A)),
  ];
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fire Safety Job Prep')),
    body: GridView.count(padding: const EdgeInsets.all(16), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
      children: [for (final c in cats) InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (c.$1 == 'মডেল টেস্ট') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TestsPage()));
          } else if (c.$1 == 'চাকরির সার্কুলার') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsPage()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TopicPage(title:c.$1, icon:c.$2, color:c.$4)));
          }
        },
        child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color:c.$3, borderRadius:BorderRadius.circular(18)),
          child: Column(crossAxisAlignment:CrossAxisAlignment.start, mainAxisAlignment:MainAxisAlignment.spaceBetween,
            children:[Icon(c.$2,color:c.$4,size:32), Text(c.$1,style:const TextStyle(fontWeight:FontWeight.bold,color:ink,fontSize:16))])),
      )],
    ),
  );
}

class TopicPage extends StatelessWidget {
  const TopicPage({super.key, required this.title, required this.icon, required this.color});
  final String title; final IconData icon; final Color color;
  String get apiCategory => const {'ফায়ার':'Fire','সেইফটি':'Safety','কমপ্লায়েন্স':'Compliance','টেকনিক্যাল':'Technical'}[title] ?? title;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title:Text(title)),
    body: ListView(padding:const EdgeInsets.all(16), children:[
      Card(color:Colors.white, child:ListTile(leading:Icon(icon,color:color), title:const Text('মডেল প্রশ্ন'), subtitle:const Text('প্রশ্ন, চারটি অপশন ও সঠিক উত্তর'), trailing:const Icon(Icons.chevron_right),
        onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>QuestionsPage(title:'$title — মডেল প্রশ্ন',category:apiCategory,examMode:false)))),
    ]),
  );
}

class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key,required this.title,this.category,required this.examMode});
  final String title; final String? category; final bool examMode;
  @override State<QuestionsPage> createState()=>_QuestionsPageState();
}
class _QuestionsPageState extends State<QuestionsPage> {
  late Future<List<PrepQuestion>> future;
  final Map<int,String> answers={};
  bool submitted=false;
  @override void initState(){super.initState();future=loadQuestions();}
  String norm(String s) {
    final v=s.trim().toUpperCase();
    final m=RegExp(r'^[\(\[]?([ABCD])[\)\].:\s]*$').firstMatch(v);
    return m?.group(1) ?? v;
  }
  void reload()=>setState(()=>{answers.clear(),submitted=false,future=loadQuestions()});
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.title)),
    body:FutureBuilder<List<PrepQuestion>>(future:future,builder:(context,snap){
      if(snap.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      if(snap.hasError)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('${snap.error}',textAlign:TextAlign.center),const SizedBox(height:12),FilledButton(onPressed:reload,child:const Text('আবার চেষ্টা করুন'))])));
      final qs=(snap.data??[]).where((q){
        final c=widget.category;
        return c==null || c=='All' || q.category.trim().toLowerCase()==c.toLowerCase();
      }).toList();
      if(qs.isEmpty)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('এই ক্যাটাগরিতে কোনো প্রশ্ন পাওয়া যায়নি।'),TextButton(onPressed:reload,child:const Text('আবার লোড করুন'))]));
      final score=qs.where((q)=>answers[q.id]!=null && norm(answers[q.id]!)==norm(q.answer)).length;
      return Column(children:[
        Container(width:double.infinity,padding:const EdgeInsets.all(12),margin:const EdgeInsets.all(10),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12)),
          child:Text(widget.examMode?(submitted?'ফলাফল: $score / ${qs.length}':'${qs.length}টি প্রশ্ন • শেষে জমা দিন'):'মোট ${qs.length}টি প্রশ্ন',
            style:const TextStyle(fontWeight:FontWeight.bold,color:maroon))),
        Expanded(child:ListView.builder(padding:const EdgeInsets.symmetric(horizontal:12),itemCount:qs.length,itemBuilder:(context,i){
          final q=qs[i]; final selected=answers[q.id]; final reveal=!widget.examMode||submitted;
          return Card(color:Colors.white,margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('প্রশ্ন ${i+1}',style:const TextStyle(color:maroon,fontWeight:FontWeight.bold)),
            const SizedBox(height:8),Text(q.question,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600,height:1.5)),
            const SizedBox(height:10),
            for(final op in q.options) if(op.value.trim().isNotEmpty)
              Container(margin:const EdgeInsets.only(bottom:7),decoration:BoxDecoration(
                color:reveal&&norm(q.answer)==op.key?const Color(0xFFE4F5E8):selected==op.key?const Color(0xFFFFE7E1):Colors.white,
                borderRadius:BorderRadius.circular(12),border:Border.all(color:reveal&&norm(q.answer)==op.key?Colors.green:selected==op.key?maroon:Colors.black12)),
                child:ListTile(dense:true,title:Text('${op.key}. ${op.value}'),leading:CircleAvatar(radius:14,child:Text(op.key)),
                  onTap:submitted&&widget.examMode?null:()=>setState(()=>answers[q.id]=op.key))),
            if(reveal)Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFE8F5E9),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('সঠিক উত্তর: ${q.answer}',style:const TextStyle(color:Color(0xFF176B3B),fontWeight:FontWeight.bold)),
              if(q.explanation.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:5),child:Text('ব্যাখ্যা: ${q.explanation}')),
              if(widget.examMode&&selected!=null)Text(norm(selected)==norm(q.answer)?'আপনার উত্তর সঠিক।':'আপনার উত্তর সঠিক নয়।'),
            ])),
          ]));
        })),
        if(widget.examMode&&!submitted)SafeArea(child:Padding(padding:const EdgeInsets.all(12),child:SizedBox(width:double.infinity,child:FilledButton(
          onPressed:()=>setState(()=>submitted=true),style:FilledButton.styleFrom(backgroundColor:maroon,padding:const EdgeInsets.all(15)),child:const Text('পরীক্ষা জমা দিন ও ফলাফল দেখুন'))))),
        if(widget.examMode&&submitted)SafeArea(child:TextButton(onPressed:reload,child:const Text('আবার পরীক্ষা দিন'))),
      ]);
    }),
  );
}

class TestsPage extends StatelessWidget {
  const TestsPage({super.key});
  static const tests=[('ফায়ার সেফটি মডেল টেস্ট','Fire',Icons.local_fire_department,Colors.red),
    ('সেইফটি মডেল টেস্ট','Safety',Icons.health_and_safety,Colors.green),
    ('কমপ্লায়েন্স মডেল টেস্ট','Compliance',Icons.verified_user,Colors.deepPurple),
    ('টেকনিক্যাল মডেল টেস্ট','Technical',Icons.settings,Colors.blue)];
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('মডেল টেস্ট')),body:ListView(padding:const EdgeInsets.all(14),children:[
    const Card(color:deepMaroon,child:Padding(padding:EdgeInsets.all(18),child:Text('পরীক্ষা জমা দেওয়ার আগে সঠিক উত্তর দেখানো হবে না.',style:TextStyle(color:Colors.white,fontSize:16)))),
    for(final t in tests)Card(color:Colors.white,child:ListTile(leading:Icon(t.$3,color:t.$4),title:Text(t.$1),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>QuestionsPage(title:t.$1,category:t.$2,examMode:true))))),
  ]));
}

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('চাকরির সার্কুলার')),body:const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('চাকরির বিজ্ঞপ্তি এখানে যোগ করা যাবে।',textAlign:TextAlign.center))));
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override State<CommunityPage> createState()=>_CommunityPageState();
}
class _CommunityPageState extends State<CommunityPage>{
  final posts=<String>['PASS পদ্ধতির ধাপগুলো কী কী?','ফায়ার ড্রিলের সময় কোন বিষয়গুলো পর্যবেক্ষণ করা উচিত?'];
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('কমিউনিটি'),actions:[IconButton(onPressed:()async{
    final c=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('নতুন পোস্ট'),content:TextField(controller:c,maxLines:4,decoration:const InputDecoration(hintText:'পোস্ট লিখুন')),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('বাতিল')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim().isNotEmpty),child:const Text('পোস্ট করুন'))]));
    if(ok==true&&mounted)setState(()=>posts.insert(0,c.text.trim()));c.dispose();
  },icon:const Icon(Icons.add))]),body:ListView(padding:const EdgeInsets.all(12),children:[for(final p in posts)Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(16),child:Text(p))) ]));
}

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});
  static const notes=['Fire Triangle — Heat, Fuel ও Oxygen','NFPA 10 — Portable Fire Extinguishers','NFPA 14 — Standpipe and Hose Systems','NFPA 20 — Stationary Fire Pumps','NFPA 25 — Inspection, Testing and Maintenance','NFPA 72 — Fire Alarm and Signaling Systems','BNBC 2020 — Fire Protection'];
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('নোট ও রিসোর্স')),body:ListView(children:[for(final n in notes)Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.menu_book,color:maroon),title:Text(n),onTap:()=>showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(n),content:const Text('এই নোটের বিস্তারিত বিষয়বস্তু পরে যোগ করা যাবে।'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('বন্ধ করুন'))]))))]));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('প্রোফাইল')),body:const Center(child:Text('Fire Safety Job Prep সদস্য')));
}
