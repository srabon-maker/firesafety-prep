import 'package:flutter/material.dart';

const Color maroon = Color(0xFF650D18);

class TopicPage extends StatelessWidget {
  const TopicPage({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.primaryContainer
                    : color.withOpacity(.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 38, color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primary
                      : color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$title প্রস্তুতি',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final item in [
              'মৌলিক ধারণা ও গুরুত্বপূর্ণ সংজ্ঞা',
              'প্রয়োজনীয় নিয়ম ও চেকলিস্ট',
              'ইন্টারভিউ প্রশ্নোত্তর',
              'মডেল প্রশ্ন',
            ])
              Card(
                color: Theme.of(context).cardColor,
                child: ListTile(
                  title: Text(item),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'আপনার কনটেন্ট যুক্ত করলে এখানে খুলবে।',
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
}
