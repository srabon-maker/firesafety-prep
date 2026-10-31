
import 'package:flutter/material.dart';

import 'jobs_page.dart';
import 'tests_page.dart';
import 'notes_page.dart';
import 'topic_page.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color red = Color(0xFFE32636);
const Color cream = Color(0xFFFFF8F4);
const Color ink = Color(0xFF27191B);

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
      SliverToBoxAdapter(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 12,
            20,
            22,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepMaroon, maroon, Color(0xFF8D1723)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/fire_safety_job_prep_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Fire Safety Job Prep',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'প্রশ্ন, টপিক বা বিষয় খুঁজুন...',
                  prefixIcon: Icon(Icons.search),
                  fillColor: Colors.white,
                ),
                onSubmitted: (v) {},
              ),
            ],
          ),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: maroon, size: 24),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'ক্যাটাগরি',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: deepMaroon,
                  ),
                ),
              ),
              Text(
                '৬টি বিষয়',
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final c = categories[i];

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (i == 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const JobsPage(),
                      ),
                    );
                  } else if (i == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TestsPage(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TopicPage(
                          title: c.$1,
                          icon: c.$2,
                          color: c.$4,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: c.$3,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: c.$4.withOpacity(.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          c.$2,
                          color: c.$4,
                          size: 25,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.$1,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: c.$4,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: categories.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: const [
              Icon(Icons.bolt, color: maroon),
              SizedBox(width: 8),
              Text(
                'দ্রুত প্রস্তুতি',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: deepMaroon,
                ),
              ),
            ],
          ),
        ),
      ),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _quickButton(
                  context,
                  'মডেল টেস্ট শুরু',
                  Icons.play_circle_fill,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TestsPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickButton(
                  context,
                  'নোট পড়ুন',
                  Icons.menu_book,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotesPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: const [
              Icon(Icons.campaign_outlined, color: maroon),
              SizedBox(width: 8),
              Text(
                'সাম্প্রতিক আপডেট',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: deepMaroon,
                ),
              ),
            ],
          ),
        ),
      ),

      SliverList(
        delegate: SliverChildListDelegate([
          _updateTile(
            Icons.local_fire_department,
            red,
            'ফায়ার সেফটি প্রস্তুতি',
            'গুরুত্বপূর্ণ টপিক ও ইন্টারভিউ প্রশ্ন',
          ),
          _updateTile(
            Icons.assignment_outlined,
            Colors.blue,
            'মডেল টেস্ট',
            'নিজের প্রস্তুতি যাচাই করুন',
          ),
          _updateTile(
            Icons.menu_book_outlined,
            Colors.green,
            'নতুন নোট',
            'NFPA ও BNBC বিষয়ভিত্তিক নোট',
          ),
          const SizedBox(height: 20),
        ]),
      ),
    ],
  );

  static Widget _quickButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) =>
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: FlexibleText(title),
      );

  static Widget _updateTile(
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) =>
      Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF0E4DF),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: maroon),
          ],
        ),
      );
}

class FlexibleText extends StatelessWidget {
  const FlexibleText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
