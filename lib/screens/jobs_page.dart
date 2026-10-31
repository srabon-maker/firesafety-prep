
import 'package:flutter/material.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color ink = Color(0xFF27191B);

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  final jobs = const [
    (
      'ফায়ার সার্ভিস ও সিভিল ডিফেন্স',
      'ফায়ারফাইটার / সংশ্লিষ্ট পদ',
      'নিয়োগ বিজ্ঞপ্তি প্রকাশিত',
    ),
    (
      'Ha-Meem Group',
      'Fire Safety / Safety Officer',
      'যোগ্যতা ও অভিজ্ঞতা বিজ্ঞপ্তি অনুযায়ী',
    ),
    (
      'বাংলাদেশ রপ্তানি প্রক্রিয়াকরণ এলাকা',
      'Fire & Safety পদ',
      'সর্বশেষ বিজ্ঞপ্তি যাচাই করুন',
    ),
    (
      'বিভিন্ন শিল্পপ্রতিষ্ঠান',
      'Fire Safety Professional',
      'আবেদনের শেষ তারিখ বিজ্ঞপ্তিতে দেখুন',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        title: const Text('চাকরির সার্কুলার'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'ফায়ার ও সেফটি চাকরি',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: deepMaroon,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'আবেদনের আগে মূল বিজ্ঞপ্তি ও শেষ তারিখ যাচাই করুন।',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),

          for (final job in jobs)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFF0E3DE),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5DF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.work_outline,
                      color: maroon,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.$2,
                          style: const TextStyle(
                            color: maroon,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.$3,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: maroon,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
