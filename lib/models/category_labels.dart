// Canonical keys are never localized. Only these display strings change.
String categoryDisplayName(String canonical, String? bn, String? en, String language) {
  final preferred = (language == 'en' ? en : bn)?.trim() ?? '';
  return preferred.isNotEmpty ? preferred : canonical;
}
String categoryDisplayFromRow(Map<String,dynamic> row, String key, String language) =>
    categoryDisplayName(row[key]?.toString() ?? '', row['category_name_bn']?.toString(),
      row['category_name_en']?.toString(), language);
bool categoryMatches(Map<String,dynamic> row, String key, String query) =>
    [row[key],row['category_name_bn'],row['category_name_en']]
      .any((v) => (v?.toString() ?? '').toLowerCase().contains(query.trim().toLowerCase()));
