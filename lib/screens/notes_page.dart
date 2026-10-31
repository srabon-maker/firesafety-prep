
import 'package:flutter/material.dart';
import '../data/app_data.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color red = Color(0xFFE32636);
const Color ink = Color(0xFF27191B);

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('নোট ও রিসোর্স'),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Text(
              'ফায়ার সেফটি স্টাডি নোট',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: deepMaroon,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'গুরুত্বপূর্ণ স্ট্যান্ডার্ড ও ইন্টারভিউ প্রস্তুতি',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < AppData.notes.length; i++)
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: Color(0xFFF0E3DE),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: [
                        const Color(0xFFFFE4DF),
                        const Color(0xFFE4EDFF),
                        const Color(0xFFE5F5E8),
                      ][i % 3],
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: [
                        red,
                        Colors.blue,
                        Colors.green,
                      ][i % 3],
                    ),
                  ),
                  title: Text(
                    AppData.notes[i],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  subtitle: const Text('স্টাডি নোট • পড়তে ট্যাপ করুন'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: maroon,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteDetailPage(
                        title: AppData.notes[i],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('নোট'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: deepMaroon,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'এখানে আপনার বিস্তারিত বাংলা নোট, ব্যাখ্যা, চেকলিস্ট এবং ইন্টারভিউ প্রশ্নোত্তর যুক্ত করুন।',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'নোটের বিষয়বস্তু বর্তমানে ডেমো হিসেবে রাখা হয়েছে। আপনার বিদ্যমান নোট/PDF যুক্ত করলে সেগুলো এখানে দেখানো যাবে।',
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
}
