
import 'package:flutter/material.dart';

import '../services/auth_guard.dart';
import 'jobs_page.dart';
import 'tests_page.dart';
import 'notes_page.dart';
import 'topic_page.dart';
import 'marketplace_page.dart';
import 'notification_inbox_page.dart';

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

  Future<void> _openCategory(BuildContext context, int i) async {
    // Published job circulars are public; login is needed only to submit.
    if (i != 0) {
      final authenticated =
          await AuthGuard.ensureAuthenticated(context);
      if (!context.mounted || !authenticated) return;
    }

    final c = categories[i];

    Widget page;

    if (i == 0) {
      page = const JobsPage();
    } else if (i == 1) {
      page = const TestsPage();
    } else {
      page = TopicPage(
        title: c.$1,
        icon: c.$2,
        color: c.$4,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _openNotes(BuildContext context) async {
    final authenticated =
        await AuthGuard.ensureAuthenticated(context);

    if (!context.mounted || !authenticated) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotesPage(),
      ),
    );
  }

  Future<void> _openTests(BuildContext context) async {
    final authenticated =
        await AuthGuard.ensureAuthenticated(context);

    if (!context.mounted || !authenticated) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TestsPage(),
      ),
    );
  }

  void _openMarketplace(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MarketplacePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      // Header
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
                      'Fire Safety BD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'নোটিফিকেশন',
                    onPressed: () async {
                      final authenticated = await AuthGuard.ensureAuthenticated(context);
                      if (!context.mounted || !authenticated) return;
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const NotificationInboxPage(),
                      ));
                    },
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

      // Categories heading
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Icon(
                Icons.grid_view_rounded,
                color: maroon,
                size: 24,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'ক্যাটাগরি',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '৬টি বিষয়',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),

      // Categories grid
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final c = categories[i];

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openCategory(context, i),
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
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
        ),
      ),

      // Marketplace section
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 5),
        sliver: SliverToBoxAdapter(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openMarketplace(context),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [deepMaroon, maroon],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fire Safety Marketplace',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'ফায়ার সেফটি পণ্য ও সার্ভিস দেখুন',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Quick preparation heading
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 8),
              Text(
                'দ্রুত প্রস্তুতি',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),

      // Quick buttons
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _quickButton(
                  'মডেল টেস্ট শুরু',
                  Icons.play_circle_fill,
                  () => _openTests(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickButton(
                  'নোট পড়ুন',
                  Icons.menu_book,
                  () => _openNotes(context),
                ),
              ),
            ],
          ),
        ),
      ),

      // Recent updates heading
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 8),
              Text(
                'সাম্প্রতিক আপডেট',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),

      // Recent updates
      SliverList(
        delegate: SliverChildListDelegate([
          _updateTile(
            context,
            Icons.local_fire_department,
            red,
            'ফায়ার সেফটি প্রস্তুতি',
            'গুরুত্বপূর্ণ টপিক ও ইন্টারভিউ প্রশ্ন',
          ),
          _updateTile(
            context,
            Icons.assignment_outlined,
            Colors.blue,
            'মডেল টেস্ট',
            'নিজের প্রস্তুতি যাচাই করুন',
          ),
          _updateTile(
            context,
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
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) =>
      Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
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
