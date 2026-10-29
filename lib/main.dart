import 'package:flutter/material.dart';

void main() => runApp(const JobPrepApp());

const Color kRed = Color(0xFF791F1F);
const Color kRedDark = Color(0xFF501313);
const Color kCream = Color(0xFFFCEBEB);
const Color kPink = Color(0xFFF7C1C1);
const Color kAmberBg = Color(0xFFFAEEDA);
const Color kAmberLight = Color(0xFFFAC775);
const Color kBrown = Color(0xFF633806);
const Color kFlame = Color(0xFFEF9F27);

class Palette {
  final bool dark;
  const Palette(this.dark);

  factory Palette.of(BuildContext context) =>
      Palette(Theme.of(context).brightness == Brightness.dark);

  Color get tile => dark ? const Color(0xFF1A1A1C) : Colors.white;
  Color get border => dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000);
  Color get text => dark ? Colors.white : const Color(0xFF1B1B1B);
  Color get sub => dark ? const Color(0x99FFFFFF) : const Color(0x8A000000);
  Color get bg => dark ? const Color(0xFF0E0E10) : const Color(0xFFF7F4F2);
}

class Tone {
  final Color bg;
  final Color fg;
  const Tone(this.bg, this.fg);
}

Tone toneOf(String name, bool dark) {
  switch (name) {
    case 'red':
      return dark
          ? const Tone(Color(0xFF501313), Color(0xFFF09595))
          : const Tone(Color(0xFFFCEBEB), Color(0xFF791F1F));
    case 'amber':
      return dark
          ? const Tone(Color(0xFF412402), Color(0xFFEF9F27))
          : const Tone(Color(0xFFFAEEDA), Color(0xFF854F0B));
    case 'green':
      return dark
          ? const Tone(Color(0xFF173404), Color(0xFF97C459))
          : const Tone(Color(0xFFEAF3DE), Color(0xFF3B6D11));
    default:
      return dark
          ? const Tone(Color(0xFF042C53), Color(0xFF85B7EB))
          : const Tone(Color(0xFFE6F1FB), Color(0xFF185FA5));
  }
}

class JobPrepApp extends StatelessWidget {
  const JobPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire Safety Job Prep',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kRed),
        scaffoldBackgroundColor: const Palette(false).bg,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kRed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Palette(true).bg,
      ),
      home: const RootPage(),
    );
  }
}

// ---------------------------------------------------------------- Logo

class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 96.0;
    canvas.save();
    canvas.scale(scale, scale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 96, 96),
        const Radius.circular(22),
      ),
      Paint()..color = kCream,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 7, 82, 82),
        const Radius.circular(18),
      ),
      Paint()..color = kRed,
    );

    final shield = Path()
      ..moveTo(48, 17)
      ..lineTo(73, 27)
      ..lineTo(73, 48)
      ..cubicTo(73, 64, 61, 76, 48, 81)
      ..cubicTo(35, 76, 23, 64, 23, 48)
      ..lineTo(23, 27)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..color = kCream,
    );

    final flame = Path()
      ..moveTo(48, 28)
      ..cubicTo(55, 37, 62, 42, 62, 53)
      ..cubicTo(62, 62, 56, 69, 48, 69)
      ..cubicTo(40, 69, 34, 62, 34, 53)
      ..cubicTo(34, 47, 37, 43, 40, 39)
      ..cubicTo(41, 43, 43, 45, 45, 45)
      ..cubicTo(44, 39, 45, 33, 48, 28)
      ..close();
    canvas.drawPath(flame, Paint()..color = kFlame);

    final inner = Path()
      ..moveTo(48, 49)
      ..cubicTo(52, 53, 55, 56, 55, 61)
      ..cubicTo(55, 65, 52, 67, 48, 67)
      ..cubicTo(44, 67, 41, 65, 41, 61)
      ..cubicTo(41, 57, 45, 54, 48, 49)
      ..close();
    canvas.drawPath(inner, Paint()..color = kAmberLight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LogoPainter oldDelegate) => false;
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: LogoPainter()),
      );
}

// ---------------------------------------------------------------- Root

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  // IndexedStack preserves each tab's state while switching tabs.
  final List<Widget> _pages = const [
    HomeTab(),
    CircularTab(),
    CommunityTab(),
    SoonPage(title: 'নোট', showBack: false),
    SoonPage(title: 'প্রোফাইল', showBack: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'সার্কুলার',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'কমিউনিটি',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'নোট',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'প্রোফাইল',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Home

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  void _open(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SoonPage(title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kRed,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const LogoMark(size: 50),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Fire Safety Job Prep',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: palette.tile,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _open(context, 'সার্চ'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 22, color: palette.sub),
                            const SizedBox(width: 8),
                            Text(
                              'প্রশ্ন বা টপিক খুঁজুন',
                              style: TextStyle(color: palette.sub, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ModelTestCard(
                onTap: () => _open(context, 'মডেল টেস্ট'),
              ),
            ),
            SectionTitle('বিষয় অনুযায়ী প্রস্তুতি', color: palette.text),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = constraints.maxWidth < 340 ? 1.35 : 1.6;
                  return GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: ratio,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      TileCard(
                        label: 'ফায়ার',
                        tone: 'red',
                        icon: Icons.local_fire_department,
                        onTap: () => _open(context, 'ফায়ার'),
                      ),
                      TileCard(
                        label: 'সেফটি',
                        tone: 'amber',
                        icon: Icons.warning_amber_rounded,
                        onTap: () => _open(context, 'সেফটি'),
                      ),
                      TileCard(
                        label: 'কমপ্লায়েন্স',
                        tone: 'green',
                        icon: Icons.verified_user,
                        onTap: () => _open(context, 'কমপ্লায়েন্স'),
                      ),
                      TileCard(
                        label: 'টেকনিক্যাল',
                        tone: 'blue',
                        icon: Icons.build,
                        onTap: () => _open(context, 'টেকনিক্যাল'),
                      ),
                    ],
                  );
                },
              ),
            ),
            SectionTitle('উৎস অনুযায়ী প্রশ্নোত্তর', color: palette.text),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  TileCard(
                    label: 'NFPA',
                    tone: 'red',
                    abbr: 'NFPA',
                    onTap: () => _open(context, 'NFPA'),
                  ),
                  TileCard(
                    label: 'BNBC',
                    tone: 'green',
                    icon: Icons.apartment,
                    onTap: () => _open(context, 'BNBC'),
                  ),
                  TileCard(
                    label: 'শ্রম আইন',
                    tone: 'amber',
                    icon: Icons.gavel,
                    onTap: () => _open(context, 'শ্রম আইন'),
                  ),
                  TileCard(
                    label: 'RSC গাইডলাইন',
                    tone: 'blue',
                    abbr: 'RSC',
                    onTap: () => _open(context, 'RSC গাইডলাইন'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: WideTile(
                label: 'Nirapon',
                tone: 'red',
                icon: Icons.health_and_safety,
                onTap: () => _open(context, 'Nirapon'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const SectionTitle(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
}

class IconBox extends StatelessWidget {
  final Tone tone;
  final IconData? icon;
  final String? abbr;
  const IconBox({super.key, required this.tone, this.icon, this.abbr});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: abbr != null
          ? Text(
              abbr!,
              style: TextStyle(
                color: tone.fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(icon ?? Icons.help_outline, color: tone.fg, size: 25),
    );
  }
}

class TileCard extends StatelessWidget {
  final String label;
  final String tone;
  final IconData? icon;
  final String? abbr;
  final VoidCallback onTap;

  const TileCard({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.abbr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Material(
      color: palette.tile,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconBox(tone: toneOf(tone, palette.dark), icon: icon, abbr: abbr),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WideTile extends StatelessWidget {
  final String label;
  final String tone;
  final IconData icon;
  final VoidCallback onTap;

  const WideTile({
    super.key,
    required this.label,
    required this.tone,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Material(
      color: palette.tile,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              IconBox(tone: toneOf(tone, palette.dark), icon: icon),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: palette.sub),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Circulars (sample data)

class CircularTab extends StatelessWidget {
  const CircularTab({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final items = <List<String>>[
      ['ফায়ার সেফটি অফিসার', 'নমুনা কোম্পানি লিমিটেড', '৩০ নভেম্বর'],
      ['ফায়ার সেফটি ম্যানেজার', 'নমুনা গ্রুপ', '২৫ নভেম্বর'],
      ['সেফটি ইঞ্জিনিয়ার', 'নমুনা ইন্ডাস্ট্রিজ', '১৫ ডিসেম্বর'],
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        title: const Text('চাকরির সার্কুলার'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'নিচের তথ্যগুলো শুধু নমুনা। পরে সার্ভার থেকে আসল সার্কুলার আসবে।',
            style: TextStyle(color: palette.sub, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.dark ? const Color(0xFF2A2118) : kAmberBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: kAmberLight,
                    child: Icon(Icons.work, color: kBrown),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item[0],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kBrown,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item[1],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0x99633806),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'শেষ তারিখ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0x99633806),
                        ),
                      ),
                      Text(
                        item[2],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Placeholder page

class SoonPage extends StatelessWidget {
  final String title;
  final bool showBack;
  const SoonPage({super.key, required this.title, this.showBack = true});

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: showBack,
        title: Text(title),
      ),
      body: Center(
        child: Text(
          'শীঘ্রই আসছে',
          style: TextStyle(fontSize: 18, color: palette.sub),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Model test card

class ModelTestCard extends StatelessWidget {
  final VoidCallback onTap;
  const ModelTestCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCream,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 100,
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -18,
                child: Icon(
                  Icons.assignment_turned_in,
                  size: 100,
                  color: kRed.withAlpha(28),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: kPink,
                      child: Icon(
                        Icons.assignment_turned_in,
                        color: kRed,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'মডেল টেস্ট',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kRed,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'সময় ধরে পরীক্ষা দিন',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xB3791F1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: kRed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'শুরু করুন',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kCream,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: kCream),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Community (local demo)

class Comment {
  final String author;
  final String text;
  Comment(this.author, this.text);
}

class Post {
  final String author;
  final String time;
  final String category;
  final String text;
  int likes;
  bool liked;
  bool reported;
  final List<Comment> comments;

  Post({
    required this.author,
    required this.time,
    required this.category,
    required this.text,
    this.likes = 0,
    this.liked = false,
    this.reported = false,
    required this.comments,
  });
}

class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  static const List<String> _categories = [
    'চাকরির আলোচনা',
    'প্রশ্ন',
    'ইন্টারভিউ অভিজ্ঞতা',
  ];

  String _filter = 'সব';

  final List<Post> _posts = [
    Post(
      author: 'নমুনা ব্যবহারকারী ১',
      time: '২ ঘণ্টা আগে',
      category: 'প্রশ্ন',
      text:
          'ফায়ার সেফটি অফিসার পদের ইন্টারভিউতে সাধারণত কী কী প্রশ্ন আসে? কেউ অভিজ্ঞতা জানালে উপকার হতো।',
      likes: 12,
      comments: [
        Comment(
          'নমুনা ব্যবহারকারী ৩',
          'আগুনের শ্রেণি, এক্সটিংগুইশারের ব্যবহার আর ইভ্যাকুয়েশন প্ল্যান নিয়ে প্রশ্ন বেশি আসে।',
        ),
      ],
    ),
    Post(
      author: 'নমুনা ব্যবহারকারী ২',
      time: 'গতকাল',
      category: 'চাকরির আলোচনা',
      text: 'NFPA ১০ আর NFPA ১৩ পড়ার জন্য কোন অংশগুলো আগে দেখা ভালো?',
      likes: 8,
      comments: [],
    ),
  ];

  List<Post> get _shown => _posts
      .where((post) =>
          !post.reported &&
          (_filter == 'সব' || post.category == _filter))
      .toList();

  void _report(Post post) {
    setState(() => post.reported = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('এই ডেমোতে পোস্টটি আপনার তালিকা থেকে লুকানো হয়েছে।'),
      ),
    );
  }

  Future<void> _openComments(Post post) async {
    final controller = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: 430,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'মন্তব্য (${post.comments.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: post.comments.isEmpty
                            ? const Center(
                                child: Text('এখনো কোনো মন্তব্য নেই'),
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  for (final comment in post.comments)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment.author,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            comment.text,
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _addComment(
                                  post,
                                  controller,
                                  setSheetState,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'মন্তব্য লিখুন...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'মন্তব্য পাঠান',
                              icon: const Icon(Icons.send, color: kRed),
                              onPressed: () => _addComment(
                                post,
                                controller,
                                setSheetState,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _addComment(
    Post post,
    TextEditingController controller,
    StateSetter setSheetState,
  ) {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setSheetState(() {
      post.comments.add(Comment('আপনি', text));
      controller.clear();
    });
    if (mounted) setState(() {});
  }

  Future<void> _newPost() async {
    final controller = TextEditingController();
    String category = _categories.first;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'নতুন পোস্ট',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final item in _categories)
                            ChoiceChip(
                              label: Text(item),
                              selected: category == item,
                              showCheckmark: false,
                              selectedColor: kRed,
                              labelStyle: TextStyle(
                                color: category == item ? Colors.white : null,
                                fontSize: 12,
                              ),
                              onSelected: (_) =>
                                  setSheetState(() => category = item),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 5,
                        minLines: 3,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'আপনার প্রশ্ন বা আলোচনা লিখুন...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('পোস্ট লেখার পর জমা দিন।'),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _posts.insert(
                                0,
                                Post(
                                  author: 'আপনি',
                                  time: 'এইমাত্র',
                                  category: category,
                                  text: text,
                                  comments: [],
                                ),
                              );
                            });
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('পোস্ট করুন'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final shown = _shown;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPost,
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('নতুন পোস্ট'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kRed,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'কমিউনিটি',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ফায়ার সেফটি চাকরি নিয়ে আলোচনা করুন',
                    style: TextStyle(color: kPink, fontSize: 13),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                children: [
                  for (final category in ['সব', ..._categories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _filter == category,
                        showCheckmark: false,
                        selectedColor: kRed,
                        labelStyle: TextStyle(
                          color: _filter == category
                              ? Colors.white
                              : palette.text,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setState(() => _filter = category),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        'এখানে এখনো কোনো পোস্ট নেই',
                        style: TextStyle(color: palette.sub),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'ডেমো সংস্করণ: পোস্টগুলো শুধু এই অ্যাপের বর্তমান সেশনে থাকে। সার্ভার যুক্ত না থাকায় অন্য ব্যবহারকারীরা দেখতে পাবেন না।',
                            style: TextStyle(
                              color: palette.sub,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        for (final post in shown) _postCard(post, palette),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(Post post, Palette palette) {
    final avatarText = post.author.isEmpty ? '?' : post.author.substring(0, 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: toneOf('red', palette.dark).bg,
                child: Text(
                  avatarText,
                  style: TextStyle(
                    color: toneOf('red', palette.dark).fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      post.time,
                      style: TextStyle(fontSize: 11, color: palette.sub),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'পোস্টের বিকল্প',
                icon: Icon(Icons.more_horiz, color: palette.sub),
                onSelected: (value) {
                  if (value == 'report') _report(post);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Text('এই পোস্টটি লুকান'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: toneOf('amber', palette.dark).bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              post.category,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: toneOf('amber', palette.dark).fg,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  post.liked = !post.liked;
                  post.likes = (post.likes + (post.liked ? 1 : -1))
                      .clamp(0, 1 << 30)
                      .toInt();
                }),
                icon: Icon(
                  post.liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18,
                  color: post.liked ? kRed : palette.sub,
                ),
                label: Text(
                  '${post.likes}',
                  style: TextStyle(color: post.liked ? kRed : palette.sub),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openComments(post),
                icon: Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: palette.sub,
                ),
                label: Text(
                  '${post.comments.length}',
                  style: TextStyle(color: palette.sub),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
