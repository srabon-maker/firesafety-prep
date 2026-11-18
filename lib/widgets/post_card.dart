import 'package:flutter/material.dart';
import '../models/community_post.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color red = Color(0xFFE32636);
const Color ink = Color(0xFF27191B);

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onChanged,
  });

  final CommunityPost post;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).dividerColor),
      boxShadow: [
        BoxShadow(
          color: maroon.withOpacity(.035),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFFE1DA),
              child: Icon(Icons.person, color: maroon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    post.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                post.category,
                style: const TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          post.text,
          style: const TextStyle(
            fontSize: 15,
            height: 1.55,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Divider(height: 24),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                post.liked = !post.liked;
                post.likes += post.liked ? 1 : -1;
                onChanged();
              },
              icon: Icon(
                post.liked ? Icons.favorite : Icons.favorite_border,
                color: post.liked ? red : maroon,
              ),
              label: Text('${post.likes}'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsPage(
                      post: post,
                      onChanged: onChanged,
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.mode_comment_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text('${post.comments.length} মন্তব্য'),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsPage(
                      post: post,
                      onChanged: onChanged,
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.post,
    required this.onChanged,
  });

  final CommunityPost post;
  final VoidCallback onChanged;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('পোস্ট ও মন্তব্য'),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PostCard(
                post: widget.post,
                onChanged: () {
                  setState(() {});
                  widget.onChanged();
                },
              ),
              const Text(
                'মন্তব্য',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.post.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'এখনো কোনো মন্তব্য নেই। প্রথম মন্তব্যটি করুন।',
                  ),
                ),
              for (final c in widget.post.comments)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.author,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(c.text),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'মন্তব্য লিখুন...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      setState(() {
                        widget.post.comments.add(
                          Comment(
                            author: 'আপনি',
                            text: controller.text.trim(),
                          ),
                        );
                        controller.clear();
                      });
                      widget.onChanged();
                    }
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: maroon,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
