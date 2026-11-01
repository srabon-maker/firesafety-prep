
import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/community_post.dart';
import '../widgets/post_card.dart';
import '../services/auth_guard.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color red = Color(0xFFE32636);
const Color cream = Color(0xFFFFF8F4);

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String filter = 'সব পোস্ট';

  Future<bool> _checkLogin() async {
    return await AuthGuard.ensureAuthenticated(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'কমিউনিটি',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search),
        ),
        IconButton(
          onPressed: () => _createPost(context),
          icon: const Icon(
            Icons.add_circle_outline,
            size: 28,
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFE4DD),
                child: Icon(Icons.person, color: maroon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _createPost(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      'ফায়ার সেফটি বিষয়ে পোস্ট লিখুন...',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _createPost(context),
                style: FilledButton.styleFrom(
                  backgroundColor: red,
                ),
                child: const Text('পোস্ট'),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            children: [
              for (final f in [
                'সব পোস্ট',
                'ফায়ার',
                'সেইফটি',
                'কমপ্লায়েন্স',
                'টেকনিক্যাল',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: filter == f,
                    selectedColor: const Color(0xFFFFD9D0),
                    onSelected: (_) {
                      setState(() => filter = f);
                    },
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: Builder(
            builder: (context) {
              final filteredPosts = AppData.posts
                  .where(
                    (p) =>
                        filter == 'সব পোস্ট' ||
                        p.category == filter,
                  )
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: filteredPosts.length,
                itemBuilder: (context, i) {
                  final post = filteredPosts[i];

                  return PostCard(
                    post: post,
                    onChanged: () => setState(() {}),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _createPost(BuildContext context) async {
    // পোস্ট তৈরির আগে Login যাচাই
    final authenticated = await _checkLogin();

    if (!mounted || !authenticated) return;

    final textController = TextEditingController();
    String category = 'ফায়ার';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            22,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'নতুন পোস্ট',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: deepMaroon,
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'বিষয়',
                ),
                items: [
                  'ফায়ার',
                  'সেইফটি',
                  'কমপ্লায়েন্স',
                  'টেকনিক্যাল',
                ].map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ),
                ).toList(),
                onChanged: (v) {
                  setModal(() {
                    category = v ?? 'ফায়ার';
                  });
                },
              ),

              const SizedBox(height: 12),

              TextField(
                controller: textController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'আপনার প্রশ্ন বা অভিজ্ঞতা লিখুন...',
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (textController.text.trim().isNotEmpty) {
                      AppData.posts.insert(
                        0,
                        CommunityPost(
                          author: 'আপনি',
                          time: 'এখনই',
                          category: category,
                          text: textController.text.trim(),
                          comments: [],
                        ),
                      );

                      Navigator.pop(ctx, true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: maroon,
                  ),
                  child: const Text('পোস্ট প্রকাশ করুন'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    textController.dispose();

    if (result == true && mounted) {
      setState(() {});
    }
  }
}
