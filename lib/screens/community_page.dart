import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/community_post.dart';
import '../services/auth_guard.dart';
import '../services/community_service.dart';
import '../widgets/post_card.dart';

const _maroon = Color(0xFF650D18);
const _deepMaroon = Color(0xFF36060D);

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late Future<List<CommunityPost>> _feed;
  String _sort = 'latest';
  bool _searchVisible = false;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _feed = CommunityService.instance.feed(sort: _sort);
  }

  Future<void> _refresh() async {
    setState(_reload);
    try { await _feed; } catch (_) {}
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFFFB5C0) : _maroon;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: _deepMaroon,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('কমিউনিটি',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('ফায়ার সেফটি নিয়ে শিখুন, জানুন ও শেয়ার করুন',
                style: TextStyle(fontSize: 11, color: Color(0xFFF0CCD2))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'পোস্ট খুঁজুন',
            icon: Icon(_searchVisible ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searchVisible = !_searchVisible;
              if (!_searchVisible) _search.clear();
            }),
          ),
          IconButton(
            tooltip: 'নতুন পোস্ট',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 27),
            onPressed: _openComposer,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 16, 15, 26),
          children: [
            Material(
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _openComposer,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFFFFE4DD),
                            child: Icon(Icons.person_rounded, color: _maroon),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'আপনার অভিজ্ঞতা বা প্রশ্ন শেয়ার করুন...',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Icon(Icons.edit_square, size: 21, color: accent),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 20, color: accent),
                          const SizedBox(width: 7),
                          Text('ছবি যোগ করুন',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: accent)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 8),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text('পোস্ট লিখুন',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_searchVisible) ...[
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'পোস্ট বা লেখকের নাম খুঁজুন',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: Text('আলোচনা ও অভিজ্ঞতা',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      )),
                ),
                _sortButton('সর্বশেষ', 'latest'),
                const SizedBox(width: 7),
                _sortButton('জনপ্রিয়', 'popular'),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<CommunityPost>>(
              future: _feed,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 70),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _message(
                    Icons.wifi_off_outlined,
                    'কমিউনিটি লোড করা যায়নি',
                    'সার্ভারে নতুন Community API আপলোড হয়েছে কি না দেখুন।',
                    retry: _refresh,
                  );
                }
                final query = _search.text.trim().toLowerCase();
                final posts = (snapshot.data ?? []).where((post) =>
                    query.isEmpty ||
                    post.text.toLowerCase().contains(query) ||
                    post.author.toLowerCase().contains(query)).toList();
                if (posts.isEmpty) {
                  return _message(
                    Icons.forum_outlined,
                    query.isNotEmpty ? 'কোনো মিল পাওয়া যায়নি' : 'এখনো পোস্ট নেই',
                    query.isNotEmpty
                        ? 'অন্য শব্দ দিয়ে খুঁজুন।'
                        : 'প্রথম পোস্টটি করুন। অ্যাডমিন অনুমোদনের পর এখানে দেখা যাবে।',
                  );
                }
                return Column(
                  children: [
                    for (final post in posts)
                      PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        onChanged: _refresh,
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

  Widget _sortButton(String label, String value) {
    final selected = _sort == value;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (selected) return;
        setState(() {
          _sort = value;
          _reload();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _maroon : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _maroon : scheme.outlineVariant,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            )),
      ),
    );
  }

  Widget _message(IconData icon, String title, String subtitle,
      {Future<void> Function()? retry}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 58, horizontal: 18),
      child: Column(
        children: [
          Icon(icon, size: 42, color: scheme.primary),
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
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('আবার চেষ্টা করুন'),
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

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

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
          const SnackBar(content: Text('ছবি সর্বোচ্চ ৫ MB হতে পারবে।')),
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
        const SnackBar(content: Text('ছবি নির্বাচন করা যায়নি।')),
      );
    }
  }

  Future<void> _publish() async {
    if (_sending || (_text.text.trim().isEmpty && _photo == null)) return;
    setState(() => _sending = true);
    try {
      await CommunityService.instance.createPost(
        body: _text.text.trim(),
        image: _photo,
        imageName: _photoName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'পোস্ট জমা হয়েছে। অ্যাডমিন অনুমোদনের পর প্রকাশিত হবে।',
        )),
      );
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('নতুন পোস্ট',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: _sending ||
                    (_text.text.trim().isEmpty && _photo == null)
                ? null
                : _publish,
            child: _sending
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('জমা দিন',
                    style: TextStyle(fontWeight: FontWeight.w800)),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('আপনার নতুন পোস্ট',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('অ্যাডমিন অনুমোদনের পর সবাই দেখতে পাবেন',
                        style: TextStyle(fontSize: 11)),
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
              hintText: 'আপনার প্রশ্ন, অভিজ্ঞতা বা ফায়ার সেফটি টিপস লিখুন...',
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
                      tooltip: 'ছবি সরান',
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
            label: Text(_photo == null ? 'গ্যালারি থেকে ছবি যোগ করুন' : 'ছবি পরিবর্তন করুন'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _sending ||
                    (_text.text.trim().isEmpty && _photo == null)
                ? null
                : _publish,
            icon: const Icon(Icons.send_rounded),
            label: Text(_sending ? 'জমা হচ্ছে...' : 'পোস্ট জমা দিন'),
            style: FilledButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'JPG, PNG বা WebP ছবি ব্যবহার করুন (সর্বোচ্চ ৫ MB)।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
