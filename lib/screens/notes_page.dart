import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/study_note.dart';
import '../services/notes_service.dart';
import '../services/saved_notes_service.dart';
import '../services/auth_guard.dart';
import '../settings/app_settings.dart';
import 'question_browser_page.dart';
import 'premium_page.dart';
import 'saved_notes_page.dart';

const Color notesMaroon = Color(0xFF650D18);

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, this.initialSearch = '', this.loadNotes});
  final String initialSearch;
  final Future<StudyNotesPage> Function(String search, int? categoryId, int page)? loadNotes;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final TextEditingController _searchController = TextEditingController(text: widget.initialSearch);
  Timer? _searchDebounce;
  StudyNotesPage? _result;
  Object? _error;
  bool _loading = true;
  int? _selectedCategory;
  int _page = 1;
  int _requestEpoch = 0;

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
    final epoch=++_requestEpoch;
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final loader = widget.loadNotes;
      final result = await (loader != null
        ? loader(_searchController.text, _selectedCategory, _page)
        : NotesService.instance.fetchNotes(
        search: _searchController.text,
        categoryId: _selectedCategory,
        page: _page,
      ));
      if (!mounted || epoch!=_requestEpoch) return;
      setState(() {
        _result = result;
        _page = result.page;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || epoch!=_requestEpoch) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _requestEpoch++;
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

  String _tr(String bn, String en) => AppText.of(context, bn, en);

  Widget _headerAction(IconData icon, String tooltip, VoidCallback? onTap) =>
      Tooltip(message: tooltip, child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 48, height: 48, child: Center(
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20,
                color: onTap == null ? Colors.white54 : Colors.white),
            ),
          )),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = _result?.categories ?? const <StudyNoteCategory>[];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        leadingWidth: 48,
        centerTitle: false,
        backgroundColor: const Color(0xFF36060D),
        foregroundColor: Colors.white,
        title: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24))),
            child: const Icon(Icons.menu_book_outlined, color: Colors.white, size: 29)),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_tr('নোট ও রিসোর্স', 'Notes & resources'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
        actions: [
          _headerAction(Icons.bookmarks_outlined, _tr('সংরক্ষিত নোট', 'Saved notes'),
            () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SavedNotesPage()))),
          const SizedBox(width: 5),
          _headerAction(Icons.refresh_rounded, _tr('রিফ্রেশ', 'Refresh'),
            _loading ? null : () => _loadNotes()),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotes(showLoader: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        hintText: _tr('নোট খুঁজুন', 'Search notes'),
                        prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: _tr('সার্চ মুছুন', 'Clear search'),
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  _searchController.clear();
                                  _page = 1;
                                  _loadNotes();
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        fillColor: scheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        value: _selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.grid_view_rounded, color: scheme.primary, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: scheme.outlineVariant),
                          ),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(_tr('সব ক্যাটাগরি', 'All categories')),
                          ),
                          ...categories.map(
                            (category) => DropdownMenuItem<int?>(
                              value: category.id,
                              child: Text(category.displayName(Localizations.localeOf(context).languageCode),overflow: TextOverflow.ellipsis),
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
            if (_result != null)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Row(children: [
                  Expanded(child: Text(_tr('স্টাডি নোট', 'Study notes'),
                    style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(_tr('${_result!.total}টি নোট', '${_result!.total} notes'),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
                ]),
              )),
            if (_loading && _result == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: FsLoadingCards(count: 3),
              )
            else if (_error != null && _result == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorView(
                  message: _error is NotesLoadException
                      ? (_error as NotesLoadException).message(english: Localizations.localeOf(context).languageCode == 'en')
                      : _error.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => _loadNotes(),
                ),
              )
            else if (_result != null && _result!.notes.isEmpty && _error == null)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _EmptyNotesView(filtered: _searchController.text.trim().isNotEmpty || _selectedCategory != null),
              ))
            else ...[
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _tr('সর্বশেষ তথ্য লোড হয়নি। আবার চেষ্টা করুন।', 'Latest notes could not be loaded. Try again.'),
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
                      key: ValueKey(note.id),
                      note: note,
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
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8, runSpacing: 4,
                      children: [
                        OutlinedButton(
                          onPressed: _page > 1 ? () => _changePage(_page - 1) : null,
                          child: Text(_tr('← আগের', '← Previous')),
                        ),
                        Text(
                          '$_page / ${_result!.totalPages}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        OutlinedButton(
                          onPressed: _page < _result!.totalPages
                              ? () => _changePage(_page + 1)
                              : null,
                          child: Text(_tr('পরের →', 'Next →')),
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
    super.key,
    required this.note,
    required this.onTap,
  });

  final StudyNote note;
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
        content: Text(next ? AppText.of(context, 'নোটটি সংরক্ষণ করা হয়েছে।', 'Note saved.') : AppText.of(context, 'সংরক্ষিত নোট থেকে সরানো হয়েছে।', 'Note removed from bookmarks.')),
        duration: const Duration(seconds: 1),
      ));
    } catch (_) {
      if (mounted) setState(() => _saved = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.note.locked ? Icons.lock_outline : (widget.note.privatePdf || widget.note.fileUrl != null) ? Icons.description_outlined : Icons.menu_book_outlined,
            color: scheme.primary, size: 23,
          ),
        ),
        title: Text(widget.note.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            [
              if(widget.note.locked || widget.note.premiumOnly) 'Premium',
              if (widget.note.categoryName != null) widget.note.displayCategory(Localizations.localeOf(context).languageCode),
              if (widget.note.summary != null) widget.note.summary!,
            ].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _saved ? AppText.of(context, 'সংরক্ষণ থেকে সরান', 'Remove bookmark') : AppText.of(context, 'নোট সংরক্ষণ করুন', 'Bookmark note'),
              onPressed: _loading ? null : _toggleSaved,
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border,
                  color: _saved ? scheme.primary : scheme.onSurfaceVariant),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}

class _EmptyNotesView extends StatelessWidget {
  const _EmptyNotesView({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(filtered ? Icons.search_off_rounded : Icons.menu_book_outlined,
            size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(filtered
            ? AppText.of(context, 'কোনো নোট পাওয়া যায়নি।', 'No matching notes.')
            : AppText.of(context, 'এখনো কোনো নোট নেই।', 'No notes published yet.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
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
                label: Text(AppText.of(context, 'আবার চেষ্টা করুন', 'Try again')),
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
  double _readerFontSize = 16;
  final _readerScroll = ScrollController();
  final _readerProgress = ValueNotifier<double>(0);

  void _updateReaderProgress() {
    if (!_readerScroll.hasClients) return;
    final position = _readerScroll.position;
    if (position.hasContentDimensions && position.maxScrollExtent > 0) {
      _readerProgress.value = (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0).toDouble();
    }
  }

  @override
  void dispose() {
    _readerScroll.dispose();
    _readerProgress.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _noteFuture = NotesService.instance.fetchNote(widget.noteId);
    _readerScroll.addListener(_updateReaderProgress);
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
              return const FsLoadingCards(count: 3);
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
            if(note.locked)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline,size:48),Text(note.title,textAlign:TextAlign.center),const Text('এই নোটটি Premium সদস্যদের জন্য।'),FilledButton(onPressed:() async {if(!await AuthGuard.ensureAuthenticated(context)||!context.mounted)return;await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const PremiumPage()));if(mounted)setState(()=>_noteFuture=NotesService.instance.fetchNote(widget.noteId));},child:const Text('Premium সদস্যপদ দেখুন'))])));
            final dark = Theme.of(context).brightness == Brightness.dark;
            return Column(children: [
              ValueListenableBuilder<double>(
                valueListenable: _readerProgress,
                builder: (context, progress, _) => LinearProgressIndicator(
                  value: progress, semanticsLabel: 'Reading progress'),
              ),
              Expanded(child: ListView(
              controller: _readerScroll,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  const Icon(Icons.text_fields_rounded),
                  IconButton(tooltip: 'Decrease text size', onPressed: _readerFontSize <= 14 ? null : () => setState(() => _readerFontSize -= 2), icon: const Icon(Icons.remove_circle_outline)),
                  Text(_readerFontSize.toStringAsFixed(0)),
                  IconButton(tooltip: 'Increase text size', onPressed: _readerFontSize >= 24 ? null : () => setState(() => _readerFontSize += 2), icon: const Icon(Icons.add_circle_outline)),
                ]),
                const SizedBox(height: 10),
                if (note.categoryName != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(note.displayCategory(Localizations.localeOf(context).languageCode)),
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
                    style: TextStyle(
                      fontSize: _readerFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                    ),
                  ),
                ],
                if (note.content != null) ...[
                  const SizedBox(height: 18),
                  HtmlWidget(
                    note.content!,
                    onTapUrl: (url) async {
                      await _openFile(url);
                      return true;
                    },
                    textStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: _readerFontSize,
                      height: 1.7,
                    ),
                    customStylesBuilder: (element) {
                      switch (element.localName) {
                        case 'h1':
                        case 'h2':
                          return {
                            'color': dark ? '#FFB3BC' : '#650D18',
                            'font-weight': '800',
                          };
                        case 'h3':
                          return {'font-weight': '700'};
                        case 'a':
                          return {
                            'color': dark ? '#FFB3BC' : '#650D18',
                            'text-decoration': 'underline',
                          };
                        case 'th':
                          return {
                            'background-color': dark ? '#383037' : '#FFE8E8',
                            'font-weight': '700',
                          };
                        case 'blockquote':
                          return {
                            'background-color': dark ? '#342C32' : '#FFF5F3',
                            'border-left': dark ? '3px solid #FFB3BC' : '3px solid #650D18',
                            'padding': '8px 12px',
                          };
                        default:
                          return null;
                      }
                    },
                  ),
                ],
                const SizedBox(height:24),
                OutlinedButton.icon(
                  onPressed:() async {
                    if(!await AuthGuard.ensureAuthenticated(context)||!context.mounted)return;
                    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>QuestionBrowserPage(noteId:note.id)));
                  },
                  icon:const Icon(Icons.quiz_outlined),
                  label:const Text('সংশ্লিষ্ট বিভাগের প্রশ্ন অনুশীলন করুন'),
                ),
                if(note.privatePdf)...[
                  const SizedBox(height:24),
                  FilledButton.icon(onPressed:() async {
                    try{final uri=await NotesService.instance.privatePdfLink(note.id);if(!context.mounted)return;if(!await launchUrl(uri,mode:LaunchMode.externalApplication))throw const FormatException('Download failed');}
                    catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PDF ডাউনলোড হয়নি। আবার চেষ্টা করুন।')));}
                  },icon:const Icon(Icons.picture_as_pdf_outlined),label:const Text('Premium PDF ডাউনলোড')),
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
            )),
            ]);
          },
        ),
      );
}
