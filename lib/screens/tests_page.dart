
import 'package:flutter/material.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color red = Color(0xFFE32636);
const Color ink = Color(0xFF27191B);

class TestsPage extends StatelessWidget {
  const TestsPage({super.key});

  final tests = const [
    (
      'ফায়ার সেফটি (সেট ০১)',
      '৫০টি প্রশ্ন • ৪৫ মিনিট',
      Icons.local_fire_department,
      red
    ),
    (
      'সেইফটি (সেট ০২)',
      '৫০টি প্রশ্ন • ৪৫ মিনিট',
      Icons.health_and_safety,
      Colors.green
    ),
    (
      'কমপ্লায়েন্স (সেট ০১)',
      '৪০টি প্রশ্ন • ৩০ মিনিট',
      Icons.verified_user,
      Colors.deepPurple
    ),
    (
      'টেকনিক্যাল (সেট ০১)',
      '৫০টি প্রশ্ন • ৬০ মিনিট',
      Icons.settings,
      Colors.blue
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('মডেল টেস্ট'),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [deepMaroon, maroon],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.track_changes,
                    color: Colors.orangeAccent,
                    size: 36,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'নিজেকে যাচাই করুন',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'নিয়মিত মডেল টেস্ট দিয়ে প্রস্তুতি আরও মজবুত করুন।',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final t in tests)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor:
                          (t.$4 as Color).withOpacity(.12),
                      child: Icon(
                        t.$3,
                        color: t.$4 as Color,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.$1,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            t.$2,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'টেস্ট প্রশ্ন যুক্ত করলে এখানে পরীক্ষা শুরু হবে।',
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: maroon,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('শুরু করুন'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
