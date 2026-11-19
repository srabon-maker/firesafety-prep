import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/auth_guard.dart';
import '../services/community_service.dart';

const _maroon = Color(0xFF650D18);

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onChanged,
    this.showActions = true,
  });

  final CommunityPost post;
  final VoidCallback onChanged;
  final bool showActions;

  Future<void> _like(BuildContext context) async {
    if (!await AuthGuard.ensureAuthenticated(context) || !context.mounted) return;
    try {
      await CommunityService.instance.toggleLike(post.id);
      onChanged();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

  void _openComments(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CommentsPage(post: post, onChanged: onChanged),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFB5C0)
        : _maroon;
    final image = post.imageUrl;
    final photo = post.authorPhoto;
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: const Color(0xFFFFE4DD),
                  backgroundImage: photo != null && photo.startsWith('https://')
                      ? NetworkImage(photo)
                      : null,
                  child: photo == null || !photo.startsWith('https://')
                      ? const Icon(Icons.person_rounded, color: _maroon)
                      : null,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          )),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 12, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(post.time,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.public_rounded,
                    color: scheme.onSurfaceVariant, size: 22),
              ],
            ),
          ),
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 9, 15, 13),
              child: Text(post.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.65,
                    color: scheme.onSurface,
                  )),
            ),
          if (image != null && image.isNotEmpty)
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    child: Image.network(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 220,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: Image.network(
                image,
                width: double.infinity,
                fit: BoxFit.cover,
                height: 230,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: scheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          if (showActions) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 3),
              child: Row(
                children: [
                  Icon(Icons.favorite_rounded,
                      size: 13, color: scheme.primary),
                  const SizedBox(width: 5),
                  Text('${post.likes} লাইক',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      )),
                  const Spacer(),
                  Text('${post.commentCount} মন্তব্য',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            Divider(height: 15, indent: 14, endIndent: 14,
                color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 0, 7, 5),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _like(context),
                      icon: Icon(
                        post.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 19,
                        color: post.liked ? scheme.error : accent,
                      ),
                      label: Text('লাইক',
                          style: TextStyle(color: accent, fontSize: 12)),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _openComments(context),
                      icon: Icon(Icons.chat_bubble_outline_rounded,
                          size: 19, color: accent),
                      label: Text('মন্তব্য',
                          style: TextStyle(color: accent, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
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
  final _text = TextEditingController();
  late Future<List<Comment>> _comments;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _comments = CommunityService.instance.comments(widget.post.id);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    setState(() => _sending = true);
    try {
      await CommunityService.instance.comment(widget.post.id, _text.text.trim());
      if (!mounted) return;
      _text.clear();
      setState(_reload);
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('পোস্ট ও মন্তব্য')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                PostCard(
                  post: widget.post,
                  onChanged: widget.onChanged,
                  showActions: false,
                ),
                const SizedBox(height: 7),
                const Text('মন্তব্য',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                FutureBuilder<List<Comment>>(
                  future: _comments,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return TextButton.icon(
                        onPressed: () => setState(_reload),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('মন্তব্য লোড হয়নি — আবার চেষ্টা'),
                      );
                    }
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('এখনো কোনো মন্তব্য নেই। প্রথম মন্তব্য করুন।'),
                      );
                    }
                    return Column(
                      children: [
                        for (final comment in comments)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment.author,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                      fontSize: 12,
                                    )),
                                const SizedBox(height: 5),
                                Text(comment.text,
                                    style: const TextStyle(height: 1.5)),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLength: 1000,
                      maxLines: 1,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'মন্তব্য লিখুন...',
                        counterText: '',
                        filled: true,
                        fillColor: scheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? const SizedBox(width: 17, height: 17,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
