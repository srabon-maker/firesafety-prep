import 'package:flutter/material.dart';

import '../models/study_note.dart';
import '../services/notes_service.dart';
import '../services/saved_notes_service.dart';
import 'notes_page.dart';

class SavedNotesPage extends StatefulWidget {
  const SavedNotesPage({super.key});

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('সংরক্ষিত নোট'),
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<StudyNote>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(children: const [
              SizedBox(height: 180),
              Center(child: Text('সংরক্ষিত নোট লোড করা যায়নি। আবার চেষ্টা করুন।')),
            ]);
          }
          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 150),
              Icon(Icons.bookmark_border, size: 56),
              SizedBox(height: 12),
              Center(child: Text('এখনো কোনো নোট সংরক্ষণ করেননি।')),
              SizedBox(height: 8),
              Center(child: Text('নোট ও রিসোর্স থেকে বুকমার্ক আইকনে চাপ দিন।')),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.bookmark, color: Color(0xFF650D18)),
                  title: Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(note.categoryName ?? 'স্টাডি নোট'),
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
