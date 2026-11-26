import 'category_labels.dart';

class StudyNote {
  const StudyNote({
    required this.id,
    required this.title,
    this.categoryId,
    this.categoryName,
    this.categoryNameBn,
    this.categoryNameEn,
    this.summary,
    this.content,
    this.fileUrl,
    this.fileType = 'none',
    this.publishedAt,
    this.locked=false,
    this.premiumOnly=false,
    this.privatePdf=false,
  });

  final int id;
  final int? categoryId;
  final String title;
  final String? categoryName;
  final String? categoryNameBn, categoryNameEn;
  String displayCategory(String language) => categoryDisplayName(categoryName ?? '',categoryNameBn,categoryNameEn,language);
  final String? summary;
  final String? content;
  final String? fileUrl;
  final String fileType;
  final String? publishedAt;
  final bool locked,premiumOnly,privatePdf;

  factory StudyNote.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic value) =>
        value == null ? null : int.tryParse(value.toString());
    String? asText(dynamic value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    return StudyNote(
      id: asInt(json['id']) ?? 0,
      categoryId: asInt(json['category_id']),
      title: asText(json['title']) ?? 'শিরোনাম নেই',
      categoryName: asText(json['category_name']),
      categoryNameBn: asText(json['category_name_bn']),
      categoryNameEn: asText(json['category_name_en']),
      summary: asText(json['summary']),
      content: asText(json['content']),
      fileUrl: asText(json['file_url']),
      fileType: asText(json['file_type']) ?? 'none',
      publishedAt: asText(json['published_at']),
      locked:json['locked']==true,
      premiumOnly:json['premium_only']==true,
      privatePdf:json['private_pdf']==true,
    );
  }
}

class StudyNoteCategory {
  const StudyNoteCategory({required this.id, required this.name, this.nameBn, this.nameEn});
  final int id;
  final String name;
  final String? nameBn, nameEn;
  String displayName(String language) => categoryDisplayName(name,nameBn,nameEn,language);

  factory StudyNoteCategory.fromJson(Map<String, dynamic> json) =>
      StudyNoteCategory(
        id: int.tryParse(json['id'].toString()) ?? 0,
        name: json['name']?.toString() ?? '',
        nameBn: json['category_name_bn']?.toString(),
        nameEn: json['category_name_en']?.toString(),
      );
}

class StudyNotesPage {
  const StudyNotesPage({
    required this.notes,
    required this.categories,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<StudyNote> notes;
  final List<StudyNoteCategory> categories;
  final int page;
  final int totalPages;
  final int total;

  factory StudyNotesPage.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['data'];
    final rawCategories = json['categories'];
    final pagination = json['pagination'];
    if (rawNotes is! List || pagination is! Map) {
      throw const FormatException('নোট তালিকার তথ্য সঠিক নয়।');
    }
    int number(dynamic value, [int fallback = 0]) =>
        int.tryParse(value.toString()) ?? fallback;

    return StudyNotesPage(
      notes: rawNotes
          .whereType<Map>()
          .map((item) => StudyNote.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      categories: rawCategories is List
          ? rawCategories
              .whereType<Map>()
              .map((item) => StudyNoteCategory.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
      page: number(pagination['page'], 1),
      totalPages: number(pagination['total_pages'], 1),
      total: number(pagination['total']),
    );
  }
}
