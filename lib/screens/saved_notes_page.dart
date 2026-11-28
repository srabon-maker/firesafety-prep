import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/app_settings.dart';

import '../models/study_note.dart';
import '../services/notes_service.dart';
import '../services/saved_notes_service.dart';
import 'notes_page.dart';

class SavedNotesPage extends StatefulWidget {
  const SavedNotesPage({super.key, this.openedFromNotes = false});

  final bool openedFromNotes;

  @override
  State<SavedNotesPage> createState() => _SavedNotesPageState();
}

class _SavedNotesPageState extends State<SavedNotesPage> {
  late Future<List<StudyNote>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<StudyNote>> _load() async {
    final ids = await SavedNotesService.instance.getSavedIds();
    if (ids.isEmpty) return [];
    final notes = await Future.wait(ids.map((id) async {
      try { return await NotesService.instance.fetchNote(id); }
      catch (_) { return null; }
    }));
    return notes.whereType<StudyNote>().toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _remove(StudyNote note) async {
    await SavedNotesService.instance.setSaved(note.id, false);
    if (mounted) await _refresh();
  }

  Future<void> _browseNotes() async {
    if (widget.openedFromNotes && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const NotesPage(),
    ));
    if (mounted) await _refresh();
  }

  PreferredSizeWidget _header(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canGoBack = ModalRoute.of(context)?.canPop ?? false;
    return AppBar(
      toolbarHeight: 68,
      titleSpacing: 8,
      centerTitle: false,
      backgroundColor: dark ? const Color(0xFF36060D) : const Color(0xFF650D18),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      automaticallyImplyLeading: false,
      leadingWidth: canGoBack ? 48 : 0,
      leading: canGoBack
          ? IconButton(
              tooltip: AppText.of(context, 'ফিরে যান', 'Back'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            )
          : null,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
            ),
            child: const Icon(Icons.bookmarks_outlined, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppText.of(context, 'সংরক্ষিত নোট', 'Saved notes'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15.5,
                    fontWeight: FontWeight.w500, height: 1.2),
                ),
                Text(
                  AppText.of(context, 'আপনার বুকমার্ক', 'Your bookmarks'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Tooltip(
          message: AppText.of(context, 'রিফ্রেশ', 'Refresh'),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _refresh,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(AppText.of(context, 'রিফ্রেশ', 'Refresh'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10,
                        height: 1.1, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _header(context),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<StudyNote>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
              SizedBox(height: 180),
              Center(child: Text('সংরক্ষিত নোট লোড করা যায়নি। আবার চেষ্টা করুন।')),
            ]);
          }
          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            final scheme = Theme.of(context).colorScheme;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              children: [
                Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bookmark_border_rounded, size: 30,
                        color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 12),
                    Text(AppText.of(context, 'কোনো সংরক্ষিত নোট নেই', 'No saved notes'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(AppText.of(context, 'প্রয়োজনীয় নোট বুকমার্ক করুন।', 'Bookmark notes you need.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _browseNotes,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text(AppText.of(context, 'নোট দেখুন', 'Browse notes')),
                    ),
                  ],
                )),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.bookmark, color: Color(0xFF650D18)),
                  title: Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(note.categoryName == null ? 'স্টাডি নোট' : note.displayCategory(Localizations.localeOf(context).languageCode)),
                  trailing: IconButton(
                    tooltip: 'সংরক্ষণ থেকে সরান',
                    icon: const Icon(Icons.bookmark_remove_outlined),
                    onPressed: () => _remove(note),
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NoteDetailPage(noteId: note.id),
                  )),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
