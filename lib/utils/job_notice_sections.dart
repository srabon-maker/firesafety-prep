/// Converts the existing plain-text job notice into display-only sections.
///
/// This does not change the API or database. Unrecognised text is preserved
/// inside the nearest section instead of being discarded.
class JobNoticeSection {
  const JobNoticeSection({
    required this.key,
    required this.title,
    required this.content,
  });

  final String key;
  final String title;
  final String content;
}

class JobNoticeParser {
  const JobNoticeParser._();

  static const Map<String, String> _titles = {
    'overview': 'চাকরির বিবরণ',
    'education': 'শিক্ষাগত যোগ্যতা',
    'experience': 'অভিজ্ঞতা',
    'additionalRequirements': 'অন্যান্য যোগ্যতা',
    'responsibilities': 'দায়িত্ব ও কাজের বিবরণ',
    'skills': 'দক্ষতা',
    'otherSkills': 'অন্যান্য দক্ষতা',
    'benefits': 'অন্যান্য সুবিধা',
    'workplace': 'কাজের ধরন',
    'employmentStatus': 'চাকরির ধরন',
    'gender': 'আবেদনের শর্ত',
    'jobLocation': 'কর্মস্থল',
  };

  static const Map<String, String> _headings = {
    'education': 'education',
    'educational requirements': 'education',
    'শিক্ষাগত যোগ্যতা': 'education',
    'experience': 'experience',
    'work experience': 'experience',
    'অভিজ্ঞতা': 'experience',
    'additional requirements': 'additionalRequirements',
    'additional requirement': 'additionalRequirements',
    'অন্যান্য যোগ্যতা': 'additionalRequirements',
    'responsibilities & context': 'responsibilities',
    'responsibilities and context': 'responsibilities',
    'job responsibilities': 'responsibilities',
    'responsibilities': 'responsibilities',
    'দায়িত্ব ও কর্তব্য': 'responsibilities',
    'skills & expertise': 'skills',
    'skills and expertise': 'skills',
    'skills': 'skills',
    'দক্ষতা': 'skills',
    'other relevant skills': 'otherSkills',
    'other skills': 'otherSkills',
    'compensation & other benefits': 'benefits',
    'compensation and other benefits': 'benefits',
    'compensation & benefits': 'benefits',
    'other benefits': 'benefits',
    'অন্যান্য সুবিধা': 'benefits',
    'workplace': 'workplace',
    'employment status': 'employmentStatus',
    'employment type': 'employmentStatus',
    'gender': 'gender',
    'job location': 'jobLocation',
    'location': 'jobLocation',
    'কর্মস্থল': 'jobLocation',
  };

  static String _cleanHeading(String line) => line
      .trim()
      .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceFirst(RegExp(r'\s*[:：]\s*$'), '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  static List<JobNoticeSection> parse(String raw) {
    if (raw.trim().isEmpty) return const [];

    final result = <JobNoticeSection>[];
    var key = 'overview';
    final buffer = <String>[];

    void flush() {
      final content = buffer.join('\n').trim();
      if (content.isNotEmpty) {
        result.add(JobNoticeSection(
          key: key,
          title: _titles[key] ?? 'বিস্তারিত',
          content: content,
        ));
      }
      buffer.clear();
    }

    for (final line in raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      final cleaned = _cleanHeading(line);
      final directKey = _headings[cleaned];
      if (directKey != null) {
        flush();
        key = directKey;
        continue;
      }

      // Support "Job Location: Gazipur" without treating "Salary Review:
      // Yearly" as a salary field or inventing missing information.
      final inline = RegExp(r'^(.{2,55}?)\s*[:：]\s*(.+)$').firstMatch(line.trim());
      if (inline != null) {
        final inlineKey = _headings[_cleanHeading(inline.group(1)!)];
        if (inlineKey != null) {
          flush();
          key = inlineKey;
          buffer.add(inline.group(2)!.trim());
          continue;
        }
      }

      // "Requirements" is a container heading, not a qualification itself.
      if (cleaned == 'requirements' || cleaned == 'যোগ্যতা') continue;
      buffer.add(line.trimRight());
    }
    flush();
    return result;
  }

  static String? firstValue(List<JobNoticeSection> sections, String key) {
    for (final section in sections) {
      if (section.key == key && section.content.trim().isNotEmpty) {
        return section.content.trim().split('\n').first.trim();
      }
    }
    return null;
  }
}
