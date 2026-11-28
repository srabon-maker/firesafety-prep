import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/auth_guard.dart';
import '../services/community_service.dart';
import '../settings/app_settings.dart';

const _maroon = Color(0xFF650D18);

String _tr(BuildContext context, String bn, String en) => AppText.of(context, bn, en);

void _feedback(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _confirmDelete(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(_tr(dialog, 'এটি আর প্রকাশ্যে দেখা যাবে না।', 'This will no longer be publicly visible.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: Text(_tr(dialog, 'বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: Text(_tr(dialog, 'মুছুন', 'Delete'))),
        ],
      ),
    ) == true;

Future<void> _report(BuildContext context, String type, int id) async {
  if (!await AuthGuard.ensureAuthenticated(context) || !context.mounted) return;
  final reasons = {
    'spam': _tr(context, 'স্প্যাম', 'Spam'),
    'harassment': _tr(context, 'হয়রানি', 'Harassment'),
    'misinformation': _tr(context, 'ভুল তথ্য', 'Misinformation'),
    'inappropriate': _tr(context, 'অনুপযুক্ত বিষয়', 'Inappropriate content'),
    'other': _tr(context, 'অন্যান্য', 'Other'),
  };
  final reason = await showDialog<String>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(_tr(dialog, 'রিপোর্টের কারণ', 'Report reason')),
      children: [
        for (final entry in reasons.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, entry.key),
            child: Text(entry.value),
          ),
      ],
    ),
  );
  if (reason == null || !context.mounted) return;
  try {
    await CommunityService.instance.report(targetType: type, targetId: id, reason: reason);
    if (context.mounted) _feedback(context, _tr(context, 'রিপোর্ট জমা হয়েছে।', 'Report submitted.'));
  } catch (error) {
    _feedback(context, error.toString().replaceFirst('Exception: ', ''));
  }
}

class _EditPostDialog extends StatefulWidget {
  const _EditPostDialog({required this.post});
  final CommunityPost post;
  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.post.text);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_tr(context, 'পোস্ট সম্পাদনা', 'Edit post')),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_tr(context, 'ছবি অপরিবর্তিত থাকবে। পরিবর্তিত পোস্ট আবার অনুমোদনের জন্য যাবে।',
            'The photo stays unchanged. Edited posts require approval again.')),
        TextField(
          controller: _controller, minLines: 3, maxLines: 8, maxLength: 3000,
          onChanged: (_) => setState(() {}),
        ),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(_tr(context, 'বাতিল', 'Cancel'))),
      FilledButton(
        onPressed: _controller.text.trim() == widget.post.text ||
            (_controller.text.trim().isEmpty && (widget.post.imageUrl?.isNotEmpty != true))
            ? null : () => Navigator.pop(context, _controller.text.trim()),
        child: Text(_tr(context, 'সংরক্ষণ', 'Save')),
      ),
    ],
  );
}

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

  Future<void> _postAction(BuildContext context, String action) async {
    if (action == 'report') {
      await _report(context, 'post', post.id);
      return;
    }
    if (!await AuthGuard.ensureAuthenticated(context) || !context.mounted) return;
    try {
      if (action == 'edit') {
        final body = await showDialog<String>(
          context: context, builder: (_) => _EditPostDialog(post: post),
        );
        if (body == null || !context.mounted) return;
        await CommunityService.instance.editPost(post.id, body);
        onChanged();
        if (context.mounted) _feedback(context, _tr(context, 'পরিবর্তন অনুমোদনের জন্য জমা হয়েছে।', 'Edit submitted for approval.'));
      } else if (action == 'delete') {
        if (!await _confirmDelete(context, _tr(context, 'পোস্ট মুছবেন?', 'Delete post?')) || !context.mounted) return;
        await CommunityService.instance.deletePost(post.id);
        onChanged();
        if (context.mounted) _feedback(context, _tr(context, 'পোস্ট সরানো হয়েছে।', 'Post removed.'));
      }
    } catch (error) {
      _feedback(context, error.toString().replaceFirst('Exception: ', ''));
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
    final accent = scheme.primary;
    final image = post.imageUrl;
    final photo = post.authorPhoto;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 8, 3),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primaryContainer,
                  foregroundImage: photo != null && photo.startsWith('https://')
                      ? NetworkImage(photo)
                      : null,
                  onForegroundImageError: photo != null && photo.startsWith('https://')
                      ? (error, stack) => debugPrint('Community avatar failed to load')
                      : null,
                  child: Icon(Icons.person_rounded, color: scheme.onPrimaryContainer, size: 22),
                ),
                const SizedBox(width: 9),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 12, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(child: Text(post.time,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ))),
                        ],
                      ),
                    ],
                  ),
                ),
                if (post.status != 'approved')
                  Flexible(child: Text(post.status == 'pending'
                    ? _tr(context, 'অপেক্ষমাণ', 'Pending')
                    : _tr(context, 'প্রত্যাখ্যাত', 'Rejected'),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))),
                if (showActions && post.id > 0)
                  PopupMenuButton<String>(
                    tooltip: _tr(context, 'পোস্ট অপশন', 'Post options'),
                    onSelected: (action) => _postAction(context, action),
                    itemBuilder: (context) => [
                      if (post.isOwner) ...[
                        PopupMenuItem(value: 'edit', child: Text(_tr(context, 'সম্পাদনা', 'Edit post'))),
                        PopupMenuItem(value: 'delete', child: Text(_tr(context, 'মুছুন', 'Delete post'))),
                      ] else
                        PopupMenuItem(value: 'report', child: Text(_tr(context, 'রিপোর্ট', 'Report post'))),
                    ],
                  )
                else
                  Icon(Icons.public_rounded, color: scheme.onSurfaceVariant, size: 22),
              ],
            ),
          ),
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 9),
              child: Text(post.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
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
          if (showActions && post.status == 'approved') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Row(
                children: [
                  Icon(Icons.favorite_rounded,
                      size: 13, color: scheme.primary),
                  const SizedBox(width: 5),
                  Text('${post.likes} ${_tr(context, 'লাইক', 'likes')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      )),
                  const Spacer(),
                  Text('${post.commentCount} ${_tr(context, 'মন্তব্য', 'comments')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            Divider(height: 9, indent: 12, endIndent: 12,
                color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
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
                      label: Text(_tr(context, 'লাইক', 'Like'),
                          style: TextStyle(color: accent, fontSize: 12)),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _openComments(context),
                      icon: Icon(Icons.chat_bubble_outline_rounded,
                          size: 19, color: accent),
                      label: Text(_tr(context, 'মন্তব্য', 'Comment'),
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

  Future<void> _commentAction(Comment comment, String action) async {
    if (action == 'report') {
      await _report(context, 'comment', comment.id);
      return;
    }
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    if (!await _confirmDelete(context, _tr(context, 'মন্তব্য মুছবেন?', 'Delete comment?')) || !mounted) return;
    try {
      await CommunityService.instance.deleteComment(comment.id);
      if (!mounted) return;
      setState(_reload);
      widget.onChanged();
      _feedback(context, _tr(context, 'মন্তব্য সরানো হয়েছে।', 'Comment removed.'));
    } catch (error) {
      if (mounted) _feedback(context, error.toString().replaceFirst('Exception: ', ''));
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
                                Row(
                                  children: [
                                    Expanded(child: Text(comment.author,
                                      style: TextStyle(fontWeight: FontWeight.w800,
                                        color: scheme.primary, fontSize: 12))),
                                    if (comment.id > 0)
                                      PopupMenuButton<String>(
                                        tooltip: _tr(context, 'মন্তব্য অপশন', 'Comment options'),
                                        onSelected: (action) => _commentAction(comment, action),
                                        itemBuilder: (context) => [
                                          if (comment.isOwner)
                                            PopupMenuItem(value: 'delete', child: Text(_tr(context, 'মুছুন', 'Delete comment')))
                                          else
                                            PopupMenuItem(value: 'report', child: Text(_tr(context, 'রিপোর্ট', 'Report comment'))),
                                        ],
                                      ),
                                  ],
                                ),
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
