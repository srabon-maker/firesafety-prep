import 'package:flutter/material.dart';

void main() => runApp(const FireSafetyJobPrepApp());

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color red = Color(0xFFE32636);
const Color cream = Color(0xFFFFF8F4);
const Color ink = Color(0xFF27191B);

class FireSafetyJobPrepApp extends StatelessWidget {
  const FireSafetyJobPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fire Safety Job Prep',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(seedColor: maroon, primary: maroon),
        fontFamily: null,
        appBarTheme: const AppBarTheme(
          backgroundColor: maroon, foregroundColor: Colors.white,
          centerTitle: false, elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: const Color(0xFFF6ECE8),
          hintStyle: const TextStyle(color: Color(0xFF8C7777)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080C25),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Image.asset('assets/fire_safety_job_prep_logo.png', fit: BoxFit.contain),
      ),
    ),
  );
}

class AppData {
  static final List<CommunityPost> posts = [
    CommunityPost(author: 'Rafiq Rahman', time: '১৫ মিনিট আগে', category: 'ফায়ার', text: 'ফায়ার এক্সটিংগুইশার ব্যবহারের সময় PASS পদ্ধতির ধাপগুলো কী কী? নতুনদের জন্য সংক্ষেপে বুঝিয়ে বলুন।', comments: [
      Comment(author: 'Tanvir Hasan', text: 'Pull, Aim, Squeeze, Sweep — এই চারটি ধাপ।'),
      Comment(author: 'Nusrat Jahan', text: 'ব্যবহারের আগে নিরাপদ বের হওয়ার পথ নিশ্চিত করতে হবে।'),
    ], likes: 12),
    CommunityPost(author: 'Tania Akter', time: '১ ঘণ্টা আগে', category: 'সেইফটি', text: 'ফ্যাক্টরিতে ফায়ার ড্রিলের সময় কোন বিষয়গুলো বিশেষভাবে পর্যবেক্ষণ করা উচিত?', comments: [
      Comment(author: 'Shakil Ahmed', text: 'ইভাকুয়েশন টাইম, exit route, assembly point ও head count।'),
    ], likes: 8),
    CommunityPost(author: 'Md. Hasan', time: '৩ ঘণ্টা আগে', category: 'কমপ্লায়েন্স', text: 'NFPA 72 অনুযায়ী ফায়ার অ্যালার্ম সিস্টেমের নিয়মিত inspection ও testing কেন গুরুত্বপূর্ণ?', comments: [], likes: 5),
  ];
  static final List<String> notes = [
    'Fire Triangle — Heat, Fuel ও Oxygen',
    'NFPA 10 — Portable Fire Extinguishers',
    'NFPA 14 — Standpipe and Hose Systems',
    'NFPA 20 — Stationary Fire Pumps',
    'NFPA 25 — Inspection, Testing and Maintenance',
    'NFPA 72 — Fire Alarm and Signaling Systems',
    'BNBC 2020 — Fire Protection',
  ];
}

class CommunityPost {
  CommunityPost({required this.author, required this.time, required this.category, required this.text, required this.comments, this.likes = 0});
  final String author, time, category, text;
  final List<Comment> comments;
  int likes;
  bool liked = false;
}
class Comment {
  Comment({required this.author, required this.text});
  final String author, text;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int index = 0;
  final pages = const [HomePage(), CommunityPage(), NotesPage(), ProfilePage()];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: NavigationBar(
      height: 70, selectedIndex: index, backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFFFE0D8),
      onDestinationSelected: (i) => setState(() => index = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'হোম'),
        NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'কমিউনিটি'),
        NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'নোট'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'প্রোফাইল'),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  final categories = const [
    ('চাকরির সার্কুলার', Icons.work_outline, Color(0xFFFFE7DD), Color(0xFFB83228)),
    ('মডেল টেস্ট', Icons.assignment_turned_in_outlined, Color(0xFFFFE8E8), Color(0xFF9E1630)),
    ('ফায়ার', Icons.local_fire_department, Color(0xFFFFE2DF), Color(0xFFD92735)),
    ('সেইফটি', Icons.health_and_safety_outlined, Color(0xFFE4F4E7), Color(0xFF20834B)),
    ('কমপ্লায়েন্স', Icons.verified_user_outlined, Color(0xFFF0E7FF), Color(0xFF7142B8)),
    ('টেকনিক্যাল', Icons.settings_outlined, Color(0xFFE2F3FA), Color(0xFF14799A)),
  ];
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [deepMaroon, maroon, Color(0xFF8D1723)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 48, height: 48, padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/fire_safety_job_prep_logo.png', fit: BoxFit.cover)),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Fire Safety Job Prep', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: Colors.white)),
          ]),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(hintText: 'প্রশ্ন, টপিক বা বিষয় খুঁজুন...', prefixIcon: Icon(Icons.search), fillColor: Colors.white),
            onSubmitted: (v) {},
          ),
        ]),
      )),
      SliverPadding(padding: const EdgeInsets.fromLTRB(18, 20, 18, 10), sliver: SliverToBoxAdapter(
        child: Row(children: [
          const Icon(Icons.grid_view_rounded, color: maroon, size: 24), const SizedBox(width: 9),
          const Expanded(child: Text('ক্যাটাগরি', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: deepMaroon))),
          Text('৬টি বিষয়', style: TextStyle(color: Colors.brown.shade400, fontSize: 12)),
        ]),
      )),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, i) {
          final c = categories[i];
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (i == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsPage()));
              else if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const TestsPage()));
              else Navigator.push(context, MaterialPageRoute(builder: (_) => TopicPage(title: c.$1, icon: c.$2, color: c.$4)));
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: c.$3, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.$4.withOpacity(.12))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(.8), shape: BoxShape.circle), child: Icon(c.$2, color: c.$4, size: 25)),
                Row(children: [Expanded(child: Text(c.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink))), Icon(Icons.arrow_forward_ios, size: 14, color: c.$4)]),
              ]),
            ),
          );
        }, childCount: categories.length),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.45),
      )),
      SliverPadding(padding: const EdgeInsets.fromLTRB(18, 24, 18, 10), sliver: SliverToBoxAdapter(
        child: Row(children: const [Icon(Icons.bolt, color: maroon), SizedBox(width: 8), Text('দ্রুত প্রস্তুতি', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: deepMaroon))]),
      )),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: _quickButton(context, 'মডেল টেস্ট শুরু', Icons.play_circle_fill, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestsPage())))),
          const SizedBox(width: 10),
          Expanded(child: _quickButton(context, 'নোট পড়ুন', Icons.menu_book, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesPage())))),
        ]),
      )),
      SliverPadding(padding: const EdgeInsets.fromLTRB(18, 24, 18, 10), sliver: SliverToBoxAdapter(
        child: Row(children: const [Icon(Icons.campaign_outlined, color: maroon), SizedBox(width: 8), Text('সাম্প্রতিক আপডেট', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: deepMaroon))]),
      )),
      SliverList(delegate: SliverChildListDelegate([
        _updateTile(Icons.local_fire_department, red, 'ফায়ার সেফটি প্রস্তুতি', 'গুরুত্বপূর্ণ টপিক ও ইন্টারভিউ প্রশ্ন', context),
        _updateTile(Icons.assignment_outlined, Colors.blue, 'মডেল টেস্ট', 'নিজের প্রস্তুতি যাচাই করুন', context),
        _updateTile(Icons.menu_book_outlined, Colors.green, 'নতুন নোট', 'NFPA ও BNBC বিষয়ভিত্তিক নোট', context),
        const SizedBox(height: 20),
      ])),
    ],
  );
  static Widget _quickButton(BuildContext context, String title, IconData icon, VoidCallback onTap) => FilledButton.icon(
    style: FilledButton.styleFrom(backgroundColor: maroon, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    onPressed: onTap, icon: Icon(icon, size: 19), label: FlexibleText(title),
  );
  static Widget _updateTile(IconData icon, Color color, String title, String subtitle, BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8), padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0E4DF))),
    child: Row(children: [
      CircleAvatar(backgroundColor: color.withOpacity(.1), child: Icon(icon, color: color)),
      const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ])), const Icon(Icons.chevron_right, color: maroon),
    ]),
  );
}
class FlexibleText extends StatelessWidget {
  const FlexibleText(this.text, {super.key}); final String text;
  @override Widget build(BuildContext context) => Flexible(child: Text(text, overflow: TextOverflow.ellipsis));
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override State<CommunityPage> createState() => _CommunityPageState();
}
class _CommunityPageState extends State<CommunityPage> {
  String filter = 'সব পোস্ট';
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('কমিউনিটি', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
      IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
      IconButton(onPressed: () => _createPost(context), icon: const Icon(Icons.add_circle_outline, size: 28)),
    ]),
    body: Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(14, 12, 14, 10), child: Row(children: [
        const CircleAvatar(backgroundColor: Color(0xFFFFE4DD), child: Icon(Icons.person, color: maroon)),
        const SizedBox(width: 10), Expanded(child: InkWell(onTap: () => _createPost(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13), decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(22)), child: const Text('ফায়ার সেফটি বিষয়ে পোস্ট লিখুন...', style: TextStyle(color: Colors.black54))))),
        const SizedBox(width: 8), FilledButton(onPressed: () => _createPost(context), style: FilledButton.styleFrom(backgroundColor: red), child: const Text('পোস্ট')),
      ])),
      SizedBox(height: 58, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), children: [
        for (final f in ['সব পোস্ট', 'ফায়ার', 'সেইফটি', 'কমপ্লায়েন্স', 'টেকনিক্যাল'])
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(f), selected: filter == f, selectedColor: const Color(0xFFFFD9D0), onSelected: (_) => setState(() => filter = f))),
      ])),
      Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 16), itemCount: AppData.posts.where((p) => filter == 'সব পোস্ট' || p.category == filter).length, itemBuilder: (context, i) {
        final post = AppData.posts.where((p) => filter == 'সব পোস্ট' || p.category == filter).toList()[i];
        return PostCard(post: post, onChanged: () => setState(() {}));
      })),
    ]),
  );
  Future<void> _createPost(BuildContext context) async {
    final textController = TextEditingController();
    String category = 'ফায়ার';
    final result = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: cream, builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
      padding: EdgeInsets.fromLTRB(18, 22, 18, MediaQuery.of(ctx).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('নতুন পোস্ট', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: deepMaroon)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'বিষয়'), items: ['ফায়ার', 'সেইফটি', 'কমপ্লায়েন্স', 'টেকনিক্যাল'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setModal(() => category = v ?? 'ফায়ার')),
        const SizedBox(height: 12),
        TextField(controller: textController, maxLines: 5, decoration: const InputDecoration(hintText: 'আপনার প্রশ্ন বা অভিজ্ঞতা লিখুন...')),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
          if (textController.text.trim().isNotEmpty) {
            AppData.posts.insert(0, CommunityPost(author: 'আপনি', time: 'এখনই', category: category, text: textController.text.trim(), comments: []));
            Navigator.pop(ctx, true);
          }
        }, style: FilledButton.styleFrom(backgroundColor: maroon), child: const Text('পোস্ট প্রকাশ করুন'))),
      ]),
    )));
    if (result == true && mounted) setState(() {});
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, required this.onChanged});
  final CommunityPost post; final VoidCallback onChanged;
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF0E3DE)), boxShadow: [BoxShadow(color: maroon.withOpacity(.035), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const CircleAvatar(backgroundColor: Color(0xFFFFE1DA), child: Icon(Icons.person, color: maroon)),
        const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(post.author, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
          Text(post.time, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFFE9E3), borderRadius: BorderRadius.circular(20)), child: Text(post.category, style: const TextStyle(color: maroon, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 13),
      Text(post.text, style: const TextStyle(fontSize: 15, height: 1.55, color: ink)),
      const Divider(height: 24),
      Row(children: [
        TextButton.icon(onPressed: () { post.liked = !post.liked; post.likes += post.liked ? 1 : -1; onChanged(); }, icon: Icon(post.liked ? Icons.favorite : Icons.favorite_border, color: post.liked ? red : maroon), label: Text('${post.likes}')),
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsPage(post: post, onChanged: onChanged))), icon: const Icon(Icons.mode_comment_outlined, color: maroon), label: Text('${post.comments.length} মন্তব্য')),
        const Spacer(), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsPage(post: post, onChanged: onChanged))), icon: const Icon(Icons.arrow_forward_ios, size: 16, color: maroon)),
      ]),
    ]),
  );
}

class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key, required this.post, required this.onChanged});
  final CommunityPost post; final VoidCallback onChanged;
  @override State<CommentsPage> createState() => _CommentsPageState();
}
class _CommentsPageState extends State<CommentsPage> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('পোস্ট ও মন্তব্য')),
    body: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        PostCard(post: widget.post, onChanged: () { setState(() {}); widget.onChanged(); }),
        const Text('মন্তব্য', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: deepMaroon)),
        const SizedBox(height: 8),
        if (widget.post.comments.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('এখনো কোনো মন্তব্য নেই। প্রথম মন্তব্যটি করুন।')),
        for (final c in widget.post.comments) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.author, style: const TextStyle(fontWeight: FontWeight.w800, color: maroon)), const SizedBox(height: 4), Text(c.text),
        ])),
      ])),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), child: Row(children: [
        Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'মন্তব্য লিখুন...'))),
        const SizedBox(width: 8), IconButton.filled(onPressed: () {
          if (controller.text.trim().isNotEmpty) {
            setState(() { widget.post.comments.add(Comment(author: 'আপনি', text: controller.text.trim())); controller.clear(); });
            widget.onChanged();
          }
        }, style: IconButton.styleFrom(backgroundColor: maroon, foregroundColor: Colors.white), icon: const Icon(Icons.send)),
      ]))),
    ]),
  );
}

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});
  final jobs = const [
    ('ফায়ার সার্ভিস ও সিভিল ডিফেন্স', 'ফায়ারফাইটার / সংশ্লিষ্ট পদ', 'নিয়োগ বিজ্ঞপ্তি প্রকাশিত'),
    ('Ha-Meem Group', 'Fire Safety / Safety Officer', 'যোগ্যতা ও অভিজ্ঞতা বিজ্ঞপ্তি অনুযায়ী'),
    ('বাংলাদেশ রপ্তানি প্রক্রিয়াকরণ এলাকা', 'Fire & Safety পদ', 'সর্বশেষ বিজ্ঞপ্তি যাচাই করুন'),
    ('বিভিন্ন শিল্পপ্রতিষ্ঠান', 'Fire Safety Professional', 'আবেদনের শেষ তারিখ বিজ্ঞপ্তিতে দেখুন'),
  ];
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('চাকরির সার্কুলার'), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search)), IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list))]),
    body: ListView(padding: const EdgeInsets.all(14), children: [
      const Text('ফায়ার ও সেফটি চাকরি', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: deepMaroon)),
      const SizedBox(height: 5), const Text('আবেদনের আগে মূল বিজ্ঞপ্তি ও শেষ তারিখ যাচাই করুন।', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 14),
      for (final j in jobs) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF0E3DE))), child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFFFE5DF), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.work_outline, color: maroon, size: 26)),
        const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(j.$1, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 4), Text(j.$2, style: const TextStyle(color: maroon, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4), Text(j.$3, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ])), const Icon(Icons.chevron_right, color: maroon),
      ])),
    ]),
  );
}

class TestsPage extends StatelessWidget {
  const TestsPage({super.key});
  final tests = const [
    ('ফায়ার সেফটি (সেট ০১)', '৫০টি প্রশ্ন • ৪৫ মিনিট', Icons.local_fire_department, red),
    ('সেইফটি (সেট ০২)', '৫০টি প্রশ্ন • ৪৫ মিনিট', Icons.health_and_safety, Colors.green),
    ('কমপ্লায়েন্স (সেট ০১)', '৪০টি প্রশ্ন • ৩০ মিনিট', Icons.verified_user, Colors.deepPurple),
    ('টেকনিক্যাল (সেট ০১)', '৫০টি প্রশ্ন • ৬০ মিনিট', Icons.settings, Colors.blue),
  ];
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('মডেল টেস্ট'), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search)), IconButton(onPressed: () {}, icon: const Icon(Icons.tune))]),
    body: ListView(padding: const EdgeInsets.all(14), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [deepMaroon, maroon]), borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.track_changes, color: Colors.orangeAccent, size: 36), SizedBox(height: 10),
        Text('নিজেকে যাচাই করুন', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(height: 5), Text('নিয়মিত মডেল টেস্ট দিয়ে প্রস্তুতি আরও মজবুত করুন।', style: TextStyle(color: Colors.white70)),
      ])),
      const SizedBox(height: 18),
      for (final t in tests) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF0E3DE))), child: Row(children: [
        CircleAvatar(radius: 25, backgroundColor: (t.$4 as Color).withOpacity(.12), child: Icon(t.$3, color: t.$4 as Color, size: 27)),
        const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5), Text(t.$2, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ])),
        FilledButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('টেস্ট প্রশ্ন যুক্ত করলে এখানে পরীক্ষা শুরু হবে।'))), style: FilledButton.styleFrom(backgroundColor: maroon), child: const Text('শুরু করুন')),
      ])),
    ]),
  );
}

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('নোট ও রিসোর্স'), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))]),
    body: ListView(padding: const EdgeInsets.all(14), children: [
      const Text('ফায়ার সেফটি স্টাডি নোট', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: deepMaroon)),
      const SizedBox(height: 5), const Text('গুরুত্বপূর্ণ স্ট্যান্ডার্ড ও ইন্টারভিউ প্রস্তুতি', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 14),
      for (int i = 0; i < AppData.notes.length; i++) Card(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF0E3DE))), child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: [const Color(0xFFFFE4DF), const Color(0xFFE4EDFF), const Color(0xFFE5F5E8)][i % 3], borderRadius: BorderRadius.circular(13)), child: Icon(Icons.description_outlined, color: [red, Colors.blue, Colors.green][i % 3])),
        title: Text(AppData.notes[i], style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
        subtitle: const Text('স্টাডি নোট • পড়তে ট্যাপ করুন'),
        trailing: const Icon(Icons.chevron_right, color: maroon),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(title: AppData.notes[i]))),
      )),
    ]),
  );
}
class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({super.key, required this.title});
  final String title;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('নোট')), body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: deepMaroon)),
    const SizedBox(height: 14), const Text('এখানে আপনার বিস্তারিত বাংলা নোট, ব্যাখ্যা, চেকলিস্ট এবং ইন্টারভিউ প্রশ্নোত্তর যুক্ত করুন।', style: TextStyle(fontSize: 16, height: 1.7)),
    const SizedBox(height: 16), const Text('নোটের বিষয়বস্তু বর্তমানে ডেমো হিসেবে রাখা হয়েছে। আপনার বিদ্যমান নোট/PDF যুক্ত করলে সেগুলো এখানে দেখানো যাবে।', style: TextStyle(color: Colors.black54, height: 1.6)),
  ])));
}

class TopicPage extends StatelessWidget {
  const TopicPage({super.key, required this.title, required this.icon, required this.color});
  final String title; final IconData icon; final Color color;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: ListView(padding: const EdgeInsets.all(16), children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon, size: 38, color: color), const SizedBox(width: 12), Expanded(child: Text('$title প্রস্তুতি', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)))])),
    const SizedBox(height: 16),
    for (final item in ['মৌলিক ধারণা ও গুরুত্বপূর্ণ সংজ্ঞা', 'প্রয়োজনীয় নিয়ম ও চেকলিস্ট', 'ইন্টারভিউ প্রশ্নোত্তর', 'মডেল প্রশ্ন']) Card(color: Colors.white, child: ListTile(title: Text(item), trailing: const Icon(Icons.chevron_right, color: maroon), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('আপনার কনটেন্ট যুক্ত করলে এখানে খুলবে।'))))),
  ]));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('প্রোফাইল'), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [deepMaroon, maroon]), borderRadius: BorderRadius.circular(22)), child: const Column(children: [
        CircleAvatar(radius: 38, backgroundColor: Colors.white, child: Icon(Icons.person, color: maroon, size: 45)),
        SizedBox(height: 12), Text('আপনার প্রোফাইল', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
        SizedBox(height: 4), Text('Fire Safety Job Prep সদস্য', style: TextStyle(color: Colors.white70)),
      ])),
      const SizedBox(height: 18),
      Row(children: const [
        Expanded(child: _StatCard(number: '০', label: 'মডেল টেস্ট')),
        SizedBox(width: 10), Expanded(child: _StatCard(number: '০', label: 'পোস্ট')),
        SizedBox(width: 10), Expanded(child: _StatCard(number: '০%', label: 'অগ্রগতি')),
      ]),
      const SizedBox(height: 18),
      for (final item in [
        (Icons.person_outline, 'ব্যক্তিগত তথ্য'), (Icons.history, 'মডেল টেস্টের ফলাফল'),
        (Icons.bookmark_border, 'সংরক্ষিত নোট'), (Icons.notifications_none, 'নোটিফিকেশন'),
        (Icons.language, 'ভাষা'), (Icons.info_outline, 'অ্যাপ সম্পর্কে'), (Icons.logout, 'লগ আউট'),
      ]) Card(color: Colors.white, elevation: 0, child: ListTile(leading: Icon(item.$1, color: maroon), title: Text(item.$2), trailing: const Icon(Icons.chevron_right), onTap: () {})),
    ]),
  );
}
class _StatCard extends StatelessWidget {
  const _StatCard({required this.number, required this.label});
  final String number, label;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: [
    Text(number, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: maroon)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
  ]));
}
