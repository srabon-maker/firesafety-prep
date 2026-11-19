import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_note.dart';

class NotesService {
  NotesService._();
  static final NotesService instance = NotesService._();

  static const endpoint =
      'https://fire.manobikishwarganj.com/api/notes.php';
  static const timeout = Duration(seconds: 15);

  Future<StudyNotesPage> fetchNotes({
    String search = '',
    int? categoryId,
    int page = 1,
  }) async {
    final query = <String, String>{'page': page.toString()};
    if (search.trim().isNotEmpty) query['search'] = search.trim();
    if (categoryId != null) query['category'] = categoryId.toString();

    final uri = Uri.parse(endpoint).replace(queryParameters: query);
    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    ).timeout(timeout);
    final decoded = _decode(response);

    if (response.statusCode != 200 || decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ?? 'নোট লোড করা যায়নি।',
      );
    }
    return StudyNotesPage.fromJson(decoded);
  }

  Future<StudyNote> fetchNote(int id) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {'action': 'detail', 'id': id.toString()},
    );
    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    ).timeout(timeout);
    final decoded = _decode(response);

    if (response.statusCode != 200 || decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ?? 'নোটের বিস্তারিত পাওয়া যায়নি।',
      );
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw const FormatException('নোটের বিস্তারিত তথ্য সঠিক নয়।');
    }
    return StudyNote.fromJson(Map<String, dynamic>.from(data));
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const FormatException('সার্ভারের response সঠিক JSON নয়।');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('সার্ভারের response format সঠিক নয়।');
    }
    return decoded;
  }
}
