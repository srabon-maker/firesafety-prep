import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import 'package:image_picker/image_picker.dart';

import '../models/community_post.dart';
import '../services/auth_guard.dart';
import '../services/community_service.dart';
import '../settings/app_settings.dart';
import '../widgets/post_card.dart';

const _maroon = Color(0xFF650D18);
const _deepMaroon = Color(0xFF36060D);

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, this.loadFeed});

  // Optional fixture loader for UI tests; production uses the existing service.
  final Future<List<CommunityPost>> Function(String sort)? loadFeed;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late Future<List<CommunityPost>> _feed;
  // Last loaded posts. They stay on screen while the feed reloads, so the
  // page never turns into a spinner (and never jumps) after a like.
  List<CommunityPost>? _lastPosts;
  String _sort = 'latest';
  int _feedEpoch = 0;
  bool _searchVisible = false;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  String _tr(String bn, String en) => AppText.of(context, bn, en);

  Future<List<CommunityPost>> _loadFeed(String sort) =>
      widget.loadFeed?.call(sort) ?? CommunityService.instance.feed(sort: sort);

  void _reload() {
    final sortAtStart = _sort;
    final epoch = ++_feedEpoch;
    _feed = _loadFeed(sortAtStart).then((posts) {
      if (mounted && epoch == _feedEpoch && sortAtStart == _sort) {
        _lastPosts = posts;
      }
      return posts;
    });
    // A fast failure or a disposed page may have no FutureBuilder listener.
    _feed.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  // Pull-to-refresh and retry: old posts stay visible while loading.
  Future<void> _refresh() async {
    setState(_reload);
    try { await _feed; } catch (_) {}
  }

  // Used after a like, comment, etc. Loads fresh data in the background and
  // swaps it in without any loading indicator.
  Future<void> _silentRefresh() async {
    final sortAtStart = _sort;
    final epoch = ++_feedEpoch;
    try {
      final posts = await _loadFeed(sortAtStart);
      // Ignore the result if the user changed the sort meanwhile.
      if (!mounted || epoch != _feedEpoch || sortAtStart != _sort) return;
      setState(() {
        _lastPosts = posts;
        _feed = Future.value(posts);
      });
    } catch (_) {
      // Keep showing the current posts if the background refresh fails.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openComposer() async {
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateCommunityPostPage()),
    );
    if (saved == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        backgroundColor: _deepMaroon,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
            ),
            child: const Icon(Icons.forum_outlined, size: 29, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42,
            color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_tr('কমিউনিটি', 'Community'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
        actions: [
          _headerAction(
            tooltip: _searchVisible
                ? _tr('সার্চ বন্ধ করুন', 'Close search')
                : _tr('পোস্ট খুঁজুন', 'Search posts'),
            icon: _searchVisible ? Icons.close_rounded : Icons.search_rounded,
            onPressed: () => setState(() {
              _searchVisible = !_searchVisible;
              if (!_searchVisible) _search.clear();
            }),
          ),
          const SizedBox(width: 5),
          _headerAction(
            tooltip: _tr('নতুন পোস্ট', 'New post'),
            icon: Icons.add_circle_outline_rounded,
            onPressed: _openComposer,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: accent,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
          children: [
            if (_searchVisible) ...[
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _tr('পোস্ট বা লেখকের নাম খুঁজুন', 'Search posts or author name'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Material(
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(children: [
                Expanded(child: InkWell(
                  onTap: _openComposer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(Icons.person_rounded, size: 20,
                          color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(_tr('পোস্ট লিখুন', 'Write a post'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant))),
                    ]),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: IconButton(
                    tooltip: _tr('ছবি যোগ করুন', 'Add photo'),
                    icon: Icon(Icons.add_photo_alternate_outlined, color: accent, size: 23),
                    onPressed: _openComposer,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _feedFilters(),
            const SizedBox(height: 8),
            FutureBuilder<List<CommunityPost>>(
              future: _feed,
              builder: (context, snapshot) {
                // New data if ready, otherwise the last loaded posts.
                final loaded = _lastPosts ?? (snapshot.connectionState == ConnectionState.done ? snapshot.data : null);
                if (loaded == null) {
                  if (snapshot.hasError) {
                    return _message(
                      Icons.wifi_off_outlined,
                      _tr('কমিউনিটি লোড করা যায়নি',
                          'Could not load the community'),
                      _tr('ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।',
                          'Check your internet connection and try again.'),
                      retry: _refresh,
                    );
                  }
                  // First load only.
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const FsLoadingCards(count: 3),
                  );
                }
                final query = _search.text.trim().toLowerCase();
                final posts = loaded.where((post) =>
                    query.isEmpty ||
                    post.text.toLowerCase().contains(query) ||
                    post.author.toLowerCase().contains(query)).toList();
                if (posts.isEmpty) {
                  return _message(
                    Icons.forum_outlined,
                    query.isNotEmpty
                        ? _tr('কোনো মিল পাওয়া যায়নি', 'No matches found')
                        : _tr('এখনো পোস্ট নেই', 'No posts yet'),
                    query.isNotEmpty
                        ? _tr('অন্য শব্দ দিয়ে খুঁজুন।',
                            'Try searching with other words.')
                        : _tr(
                            'প্রথম পোস্টটি করুন। অ্যাডমিন অনুমোদনের পর এখানে দেখা যাবে।',
                            'Make the first post. It will appear here after admin approval.'),
                  );
                }
                return Column(
                  children: [
                    for (final post in posts)
                      PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        // Silent: no spinner, no jump after a like.
                        onChanged: _silentRefresh,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48, height: 48,
          child: Center(child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          )),
        ),
      ),
    ),
  );

  Future<void> _selectSort(String value) async {
    if (value == _sort) return;
    if (value == 'mine' &&
        (!await AuthGuard.ensureAuthenticated(context) || !mounted)) return;
    if (!mounted) return;
    setState(() {
      _sort = value;
      _lastPosts = null;
      _reload();
    });
  }

  Widget _feedFilters() {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
      final heading = Text(_tr('পোস্ট', 'Posts'),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: scheme.onSurface, fontWeight: FontWeight.w800));
      final filters = Wrap(spacing: 5, runSpacing: 4, children: [
        _sortButton(_tr('সর্বশেষ', 'Latest'), 'latest'),
        _sortButton(_tr('জনপ্রিয়', 'Popular'), 'popular'),
        _sortButton(_tr('আমার পোস্ট', 'My posts'), 'mine'),
      ]);
      if (constraints.maxWidth < 340 || largeText) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 4), filters]);
      }
      return Row(children: [
        heading, const SizedBox(width: 8),
        Expanded(child: Align(alignment: Alignment.centerRight, child: filters)),
      ]);
    });
  }

  Widget _sortButton(String label, String value) {
    final selected = _sort == value;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectSort(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
            ),
            child: Align(
              widthFactor: 1, heightFactor: 1,
              child: Text(label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String subtitle,
      {Future<void> Function()? retry}) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 14),
      child: Column(
        children: [
          Icon(icon, size: 42, color: accent),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          if (retry != null) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: retry,
              style: TextButton.styleFrom(foregroundColor: accent),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tr('আবার চেষ্টা করুন', 'Try again')),
            ),
          ],
        ],
      ),
    );
  }
}

class CreateCommunityPostPage extends StatefulWidget {
  const CreateCommunityPostPage({super.key});

  @override
  State<CreateCommunityPostPage> createState() => _CreateCommunityPostPageState();
}

class _CreateCommunityPostPageState extends State<CreateCommunityPostPage> {
  final _text = TextEditingController();
  Uint8List? _photo;
  String? _photoName;
  bool _sending = false;
  // Set after a successful submit, so leaving does not ask for confirmation.
  bool _published = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _tr(String bn, String en) => AppText.of(context, bn, en);

  bool get _hasContent => _text.text.trim().isNotEmpty || _photo != null;

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_tr('ছবি সর্বোচ্চ ৫ MB হতে পারবে।',
                  'The image can be 5 MB at most.'))),
        );
        return;
      }
      setState(() {
        _photo = bytes;
        _photoName = file.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_tr('ছবি নির্বাচন করা যায়নি।',
                'Could not select the image.'))),
      );
    }
  }

  Future<void> _publish() async {
    if (_sending || !_hasContent) return;
    setState(() => _sending = true);
    try {
      await CommunityService.instance.createPost(
        body: _text.text.trim(),
        image: _photo,
        imageName: _photoName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_tr(
          'পোস্ট জমা হয়েছে। অ্যাডমিন অনুমোদনের পর প্রকাশিত হবে।',
          'Post submitted. It will be published after admin approval.',
        ))),
      );
      setState(() => _published = true);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          error.toString().replaceFirst('Exception: ', ''),
        )),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Asks before throwing away a written post.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('পোস্টটি বাতিল করবেন?', 'Discard this post?')),
        content: Text(_tr('আপনার লেখা বা ছবি মুছে যাবে।',
            'Your text and photo will be lost.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('লিখতে থাকুন', 'Keep writing')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('বাতিল করুন', 'Discard')),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _published = true); // allow leaving without asking again
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _published || !_hasContent,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          // Fixed colours: the white "Submit" text is always readable.
          backgroundColor: _deepMaroon,
          foregroundColor: Colors.white,
          title: Text(_tr('নতুন পোস্ট', 'New post'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white54,
              ),
              onPressed: _sending || !_hasContent ? null : _publish,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_tr('জমা দিন', 'Submit'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 7),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFE4DD),
                  child: Icon(Icons.person_rounded, color: _maroon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tr('আপনার নতুন পোস্ট', 'Your new post'),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                          _tr('অ্যাডমিন অনুমোদনের পর সবাই দেখতে পাবেন',
                              'Everyone can see it after admin approval'),
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 12,
              maxLength: 3000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _tr(
                    'আপনার প্রশ্ন, অভিজ্ঞতা বা ফায়ার সেফটি টিপস লিখুন...',
                    'Write your question, experience or fire safety tip...'),
                alignLabelWithHint: true,
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  children: [
                    Image.memory(_photo!, width: double.infinity,
                        height: 245, fit: BoxFit.cover),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton.filled(
                        tooltip: _tr('ছবি সরান', 'Remove photo'),
                        onPressed: () => setState(() {
                          _photo = null;
                          _photoName = null;
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _sending ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_photo == null
                  ? _tr('গ্যালারি থেকে ছবি যোগ করুন', 'Add photo from gallery')
                  : _tr('ছবি পরিবর্তন করুন', 'Change photo')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _sending || !_hasContent ? null : _publish,
              icon: const Icon(Icons.send_rounded),
              label: Text(_sending
                  ? _tr('জমা হচ্ছে...', 'Submitting...')
                  : _tr('পোস্ট জমা দিন', 'Submit post')),
              style: FilledButton.styleFrom(
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _tr('JPG, PNG বা WebP ছবি ব্যবহার করুন (সর্বোচ্চ ৫ MB)।',
                  'Use a JPG, PNG or WebP image (5 MB at most).'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
