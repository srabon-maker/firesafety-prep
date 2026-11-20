import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/study_note.dart';
import '../services/notes_service.dart';
import '../services/saved_notes_service.dart';

const Color notesMaroon = Color(0xFF650D18);

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  StudyNotesPage? _result;
  Object? _error;
  bool _loading = true;
  int? _selectedCategory;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await NotesService.instance.fetchNotes(
        search: _searchController.text,
        categoryId: _selectedCategory,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _page = result.page;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _page = 1;
      _loadNotes();
    });
  }

  void _selectCategory(int? value) {
    setState(() {
      _selectedCategory = value;
      _page = 1;
    });
    _loadNotes();
  }

  void _changePage(int page) {
    if (_result == null || page < 1 || page > _result!.totalPages) return;
    setState(() => _page = page);
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _result?.categories ?? const <StudyNoteCategory>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('নোট ও রিসোর্স'),
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            onPressed: _loading ? null : () => _loadNotes(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotes(showLoader: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ফায়ার সেফটি স্টাডি নোট',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'অ্যাডমিন প্যানেল থেকে প্রকাশিত নোট ও প্রয়োজনীয় রিসোর্স',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        _searchDebounce?.cancel();
                        _page = 1;
                        _loadNotes();
                      },
                      decoration: InputDecoration(
                        hintText: 'নোটের শিরোনাম বা বিষয় খুঁজুন...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'সার্চ মুছুন',
                                onPressed: () {
                                  _searchController.clear();
                                  _page = 1;
                                  _loadNotes();
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: _selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'ক্যাটাগরি',
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('সব ক্যাটাগরি'),
                          ),
                          ...categories.map(
                            (category) => DropdownMenuItem<int?>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          ),
                        ],
                        onChanged: _selectCategory,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_loading && _result == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _result == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorView(
                  message: _error.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => _loadNotes(),
                ),
              )
            else if (_result != null && _result!.notes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyNotesView(),
              )
            else ...[
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'সর্বশেষ তথ্য লোড হয়নি। আবার চেষ্টা করুন।',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                sliver: SliverList.builder(
                  itemCount: _result?.notes.length ?? 0,
                  itemBuilder: (context, index) {
                    final note = _result!.notes[index];
                    return _NoteCard(
                      note: note,
                      index: index,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoteDetailPage(noteId: note.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if ((_result?.totalPages ?? 1) > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: _page > 1 ? () => _changePage(_page - 1) : null,
                          child: const Text('← আগের'),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$_page / ${_result!.totalPages}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: _page < _result!.totalPages
                              ? () => _changePage(_page + 1)
                              : null,
                          child: const Text('পরের →'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.note,
    required this.index,
    required this.onTap,
  });

  final StudyNote note;
  final int index;
  final VoidCallback onTap;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _saved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await SavedNotesService.instance.isSaved(widget.note.id);
    if (mounted) setState(() { _saved = saved; _loading = false; });
  }

  Future<void> _toggleSaved() async {
    final next = !_saved;
    setState(() => _saved = next);
    try {
      await SavedNotesService.instance.setSaved(widget.note.id, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next ? 'নোটটি সংরক্ষণ করা হয়েছে।' : 'সংরক্ষিত নোট থেকে সরানো হয়েছে।'),
        duration: const Duration(seconds: 1),
      ));
    } catch (_) {
      if (mounted) setState(() => _saved = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFFE4DF),
      const Color(0xFFE4EDFF),
      const Color(0xFFE5F5E8),
    ];
    final iconColors = [notesMaroon, Colors.blue, Colors.green];
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors[widget.index % colors.length],
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            widget.note.fileUrl == null ? Icons.menu_book_outlined : Icons.description_outlined,
            color: iconColors[widget.index % iconColors.length],
          ),
        ),
        title: Text(widget.note.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            [
              if (widget.note.categoryName != null) widget.note.categoryName!,
              if (widget.note.summary != null) widget.note.summary!,
              'বিস্তারিত পড়তে ট্যাপ করুন',
            ].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _saved ? 'সংরক্ষণ থেকে সরান' : 'নোট সংরক্ষণ করুন',
              onPressed: _loading ? null : _toggleSaved,
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border,
                  color: _saved ? notesMaroon : null),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}

class _EmptyNotesView extends StatelessWidget {
  const _EmptyNotesView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 54, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text('এখনো কোনো প্রকাশিত নোট পাওয়া যায়নি।'),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('আবার চেষ্টা করুন'),
              ),
            ],
          ),
        ),
      );
}

class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final int noteId;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late Future<StudyNote> _noteFuture;

  @override
  void initState() {
    super.initState();
    _noteFuture = NotesService.instance.fetchNote(widget.noteId);
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফাইলের লিংকটি সঠিক নয়।')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফাইলটি খোলা যায়নি। পরে আবার চেষ্টা করুন।')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('নোটের বিস্তারিত')),
        body: FutureBuilder<StudyNote>(
          future: _noteFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _ErrorView(
                message: snapshot.error?.toString().replaceFirst('Exception: ', '') ??
                    'নোট পাওয়া যায়নি।',
                onRetry: () => setState(() {
                  _noteFuture = NotesService.instance.fetchNote(widget.noteId);
                }),
              );
            }
            final note = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (note.categoryName != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(note.categoryName!),
                      backgroundColor: const Color(0xFFFFE8E8),
                      labelStyle: const TextStyle(
                        color: notesMaroon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  note.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                if (note.publishedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'প্রকাশিত: ' + note.publishedAt!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (note.summary != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    note.summary!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                    ),
                  ),
                ],
                if (note.content != null) ...[
                  const SizedBox(height: 18),
                  Html(
                    data: note.content!,
                    onLinkTap: (url, attributes, element) {
                      if (url != null) _openFile(url);
                    },
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(16),
                        lineHeight: const LineHeight(1.7),
                      ),
                      'p': Style(margin: Margins.only(bottom: 12)),
                      'h1': Style(
                        fontSize: FontSize(24),
                        fontWeight: FontWeight.w800,
                        color: notesMaroon,
                      ),
                      'h2': Style(
                        fontSize: FontSize(21),
                        fontWeight: FontWeight.w800,
                        color: notesMaroon,
                      ),
                      'h3': Style(
                        fontSize: FontSize(18),
                        fontWeight: FontWeight.w700,
                      ),
                      'img': Style(
                        width: Width(100, Unit.percent),
                        alignment: Alignment.center,
                      ),
                      'table': Style(
                        width: Width(100, Unit.percent),
                        border: Border.all(color: const Color(0xFFD8DDE5)),
                      ),
                      'th': Style(
                        backgroundColor: const Color(0xFFFFE8E8),
                        padding: HtmlPaddings.all(8),
                        fontWeight: FontWeight.w700,
                        border: Border.all(color: const Color(0xFFD8DDE5)),
                      ),
                      'td': Style(
                        padding: HtmlPaddings.all(8),
                        border: Border.all(color: const Color(0xFFD8DDE5)),
                      ),
                      'blockquote': Style(
                        backgroundColor: const Color(0xFFFFF5F3),
                        padding: HtmlPaddings.only(left: 12, top: 8, bottom: 8),
                        border: Border(
                          left: BorderSide(color: notesMaroon, width: 3),
                        ),
                      ),
                      'a': Style(
                        color: notesMaroon,
                        textDecoration: TextDecoration.underline,
                      ),
                    },
                  ),
                ],
                if (note.fileUrl != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openFile(note.fileUrl!),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      note.fileType == 'pdf' ? 'PDF খুলুন / ডাউনলোড' : 'সংযুক্ত ফাইল খুলুন',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: notesMaroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
}
