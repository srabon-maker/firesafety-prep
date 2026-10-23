import 'package:flutter/material.dart';

void main() => runApp(const JobPrepApp());

const Color kRed = Color(0xFF791F1F);
const Color kRedDark = Color(0xFF501313);
const Color kCream = Color(0xFFFCEBEB);
const Color kPink = Color(0xFFF7C1C1);
const Color kAmberBg = Color(0xFFFAEEDA);
const Color kAmberLight = Color(0xFFFAC775);
const Color kBrown = Color(0xFF633806);
const Color kGreen = Color(0xFF27500A);
const Color kBlue = Color(0xFF0C447C);
const Color kFlame = Color(0xFFEF9F27);

class JobPrepApp extends StatelessWidget {
  const JobPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire Safety Job Prep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kRed),
        scaffoldBackgroundColor: const Color(0xFFF7F4F2),
      ),
      home: const RootPage(),
    );
  }
}

// ---------------------------------------------------------------- Root

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeTab(onGoTab: (i) => setState(() => _index = i)),
      const CircularTab(),
      const SoonPage(title: 'নোট', showBack: false),
      const SoonPage(title: 'প্রোফাইল', showBack: false),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'হোম'),
          NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'সার্কুলার'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'নোট'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'প্রোফাইল'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Home

class HomeTab extends StatelessWidget {
  final void Function(int) onGoTab;
  const HomeTab({super.key, required this.onGoTab});

  void _open(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SoonPage(title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjects = <SubjectItem>[
      const SubjectItem('ফায়ার', 'আগুন ও নির্বাপণ', kRed,
          Icons.local_fire_department),
      const SubjectItem(
          'সেফটি', 'ঝুঁকি ও নিরাপত্তা', kBrown, Icons.warning_amber_rounded),
      const SubjectItem(
          'কমপ্লায়েন্স', 'নিয়ম ও অডিট', kGreen, Icons.verified_user),
      const SubjectItem('টেকনিক্যাল', 'সিস্টেম ও ডিজাইন', kBlue, Icons.build),
    ];

    final sources = <SourceItem>[
      const SourceItem('NFPA', 'আন্তর্জাতিক স্ট্যান্ডার্ড', kRed, 'NFPA', null),
      const SourceItem(
          'BNBC', 'বাংলাদেশ জাতীয় বিল্ডিং কোড', kGreen, null, Icons.apartment),
      const SourceItem(
          'শ্রম আইন', 'বাংলাদেশ শ্রম আইন', kBrown, null, Icons.gavel),
      const SourceItem('RSC গাইডলাইন', 'টেকনিক্যাল গাইডলাইন', kBlue, 'RSC', null),
      const SourceItem('Nirapon', 'নিরাপত্তা প্রশ্নোত্তর', kRedDark, null,
          Icons.health_and_safety),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 16, 16, 18),
            decoration: const BoxDecoration(
              color: kRed,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: kRed,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kCream, width: 1.5),
                      ),
                      child: const Icon(Icons.local_fire_department,
                          color: kFlame, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Fire Safety Job Prep',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, size: 20, color: Colors.black45),
                      SizedBox(width: 8),
                      Text('প্রশ্ন বা টপিক খুঁজুন',
                          style:
                              TextStyle(color: Colors.black45, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Two hero cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: HeroCard(
                    bg: kAmberBg,
                    iconBg: kAmberLight,
                    fg: kBrown,
                    icon: Icons.work,
                    title: 'চাকরির সার্কুলার',
                    action: 'দেখুন',
                    onTap: () => onGoTab(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HeroCard(
                    bg: kCream,
                    iconBg: kPink,
                    fg: kRed,
                    icon: Icons.assignment_turned_in,
                    title: 'মডেল টেস্ট',
                    action: 'শুরু করুন',
                    onTap: () => _open(context, 'মডেল টেস্ট'),
                  ),
                ),
              ],
            ),
          ),

          // Subjects
          const SectionTitle('বিষয় অনুযায়ী প্রস্তুতি'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final s in subjects)
                  SubjectCard(item: s, onTap: () => _open(context, s.title)),
              ],
            ),
          ),

          // Sources
          const SectionTitle('উৎস অনুযায়ী প্রশ্নোত্তর'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                for (final s in sources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child:
                        SourceRow(item: s, onTap: () => _open(context, s.title)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }
}

class HeroCard extends StatelessWidget {
  final Color bg;
  final Color iconBg;
  final Color fg;
  final IconData icon;
  final String title;
  final String action;
  final VoidCallback onTap;

  const HeroCard({
    super.key,
    required this.bg,
    required this.iconBg,
    required this.fg,
    required this.icon,
    required this.title,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 150,
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -14,
                child: Icon(icon, size: 96, color: fg.withAlpha(34)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: iconBg,
                      child: Icon(icon, color: fg),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: fg)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: fg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(action,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: bg)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 13, color: bg),
                            ],
                          ),
                        ),
                      ],
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

class SubjectItem {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  const SubjectItem(this.title, this.subtitle, this.color, this.icon);
}

class SubjectCard extends StatelessWidget {
  final SubjectItem item;
  final VoidCallback onTap;
  const SubjectCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -12,
              bottom: -12,
              child: Icon(item.icon, size: 84, color: const Color(0x21FFFFFF)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0x2EFFFFFF),
                    child: Icon(item.icon, color: Colors.white, size: 21),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(item.subtitle,
                          style: const TextStyle(
                              color: Color(0xCCFFFFFF), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SourceItem {
  final String title;
  final String subtitle;
  final Color color;
  final String? abbr;
  final IconData? icon;
  const SourceItem(this.title, this.subtitle, this.color, this.abbr, this.icon);
}

class SourceRow extends StatelessWidget {
  final SourceItem item;
  final VoidCallback onTap;
  const SourceRow({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1F000000)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: item.abbr != null
                    ? Text(item.abbr!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))
                    : Icon(item.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.color.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right, color: item.color, size: 20),
              ),
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
          const Text('নিচের তথ্যগুলো শুধু নমুনা। পরে সার্ভার থেকে আসল সার্কুলার আসবে।',
              style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 12),
          for (final it in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAmberBg,
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
                        Text(it[0],
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: kBrown)),
                        const SizedBox(height: 2),
                        Text(it[1],
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('শেষ তারিখ',
                          style:
                              TextStyle(fontSize: 11, color: Colors.black54)),
                      Text(it[2],
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kRed)),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: showBack,
        title: Text(title),
      ),
      body: const Center(
        child: Text('শীঘ্রই আসছে',
            style: TextStyle(fontSize: 18, color: Colors.black54)),
      ),
    );
  }
}
