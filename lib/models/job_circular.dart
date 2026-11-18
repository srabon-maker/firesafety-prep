/// A published job circular supplied by the Fire Safety BD jobs API.
/// Never show fabricated vacancies when the backend is empty or unavailable.
class JobCircular {
  const JobCircular({
    required this.id,
    required this.organization,
    required this.title,
    required this.publishedAt,
    this.location = '',
    this.jobType = '',
    this.employmentType = '',
    this.description = '',
    this.requirements = '',
    this.salary = '',
    this.deadline,
    this.applyUrl,
    this.circularUrl,
  });

  final int id;
  final String organization;
  final String title;
  final DateTime publishedAt;
  final String location;
  final String jobType;
  final String employmentType;
  final String description;
  final String requirements;
  final String salary;
  final DateTime? deadline;
  final String? applyUrl;
  final String? circularUrl;

  bool get isExpired {
    final end = deadline;
    if (end == null) return false;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).isAfter(
      DateTime(end.year, end.month, end.day),
    );
  }

  bool get isGovernment => jobType.toLowerCase() == 'government';

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String? _httpsUrl(dynamic value) {
    final text = _text(value);
    final uri = Uri.tryParse(text);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? text
        : null;
  }

  factory JobCircular.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(_text(json['id']));
    final organization = _text(json['organization']);
    final title = _text(json['title']);
    if (id == null || id <= 0 || organization.isEmpty || title.isEmpty) {
      throw const FormatException('চাকরির বিজ্ঞপ্তির তথ্য অসম্পূর্ণ।');
    }
    final publishedAt = DateTime.tryParse(_text(json['published_at']));
    if (publishedAt == null) {
      throw const FormatException('চাকরির প্রকাশের তারিখ সঠিক নয়।');
    }
    final deadlineText = _text(json['application_deadline']);
    final deadline = deadlineText.isEmpty
        ? null
        : DateTime.tryParse(deadlineText);
    if (deadlineText.isNotEmpty && deadline == null) {
      throw const FormatException('আবেদনের শেষ তারিখ সঠিক নয়।');
    }
    return JobCircular(
      id: id,
      organization: organization,
      title: title,
      publishedAt: publishedAt,
      location: _text(json['location']),
      jobType: _text(json['job_type']),
      employmentType: _text(json['employment_type']),
      description: _text(json['description']),
      requirements: _text(json['requirements']),
      salary: _text(json['salary']),
      deadline: deadline,
      applyUrl: _httpsUrl(json['apply_url']),
      circularUrl: _httpsUrl(json['circular_url']),
    );
  }
}
