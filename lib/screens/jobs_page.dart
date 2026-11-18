import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/job_circular.dart';
import '../utils/job_notice_sections.dart';
import '../services/job_circular_service.dart';

const Color _maroon = Color(0xFF650D18);
const Color _deepMaroon = Color(0xFF36060D);

String _dateLabel(DateTime? date) {
  if (date == null) return 'উল্লেখ নেই';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

Future<void> _openOfficialLink(BuildContext context, String? url) async {
  if (url == null) return;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Show an actionable error rather than silently ignoring broken links.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('লিংকটি খোলা যায়নি। পরে আবার চেষ্টা করুন।')),
    );
  }
}

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  late Future<List<JobCircular>> _jobs;
  final _search = TextEditingController();
  bool _pinnedOnly = false;
  String _deadline = 'active';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _jobs = JobCircularService.instance.fetchCirculars();
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _jobs;
    } catch (_) {
      // The FutureBuilder shows an error with a retry action.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<JobCircular> _filter(List<JobCircular> jobs) {
    final query = _search.text.trim().toLowerCase();
    return jobs.where((job) {
      if (_pinnedOnly && !job.isPinned) return false;
      if (_deadline == 'active' && job.isExpired) return false;
      if (_deadline == 'expired' && !job.isExpired) return false;
      return query.isEmpty ||
          job.title.toLowerCase().contains(query) ||
          job.organization.toLowerCase().contains(query) ||
          job.location.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: _deepMaroon,
          foregroundColor: Colors.white,
          title: const Text('চাকরির সার্কুলার'),
          actions: [
            IconButton(
              tooltip: 'রিফ্রেশ',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_deepMaroon, _maroon],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.work_outline, color: Colors.white, size: 38),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fire & Safety Jobs',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'সর্বশেষ প্রকাশিত চাকরির বিজ্ঞপ্তি',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'পদ, প্রতিষ্ঠান বা লোকেশন খুঁজুন',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('সব সার্কুলার'),
                    selected: !_pinnedOnly,
                    onSelected: (_) => setState(() => _pinnedOnly = false),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.push_pin_outlined, size: 16),
                    label: const Text('পিন করা'),
                    selected: _pinnedOnly,
                    onSelected: (_) => setState(() => _pinnedOnly = true),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('চলমান'),
                    selected: _deadline == 'active',
                    onSelected: (_) => setState(() => _deadline = 'active'),
                  ),
                  ChoiceChip(
                    label: const Text('সব বিজ্ঞপ্তি'),
                    selected: _deadline == 'all',
                    onSelected: (_) => setState(() => _deadline = 'all'),
                  ),
                  ChoiceChip(
                    label: const Text('মেয়াদ শেষ'),
                    selected: _deadline == 'expired',
                    onSelected: (_) => setState(() => _deadline = 'expired'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<JobCircular>>(
                future: _jobs,
                builder: (context, snapshot) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 70),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _notice(
                      context,
                      Icons.wifi_off_outlined,
                      'চাকরির বিজ্ঞপ্তি লোড করা যায়নি।',
                      'সার্ভার সংযোগ ও Jobs API যাচাই করুন।',
                      onRetry: _refresh,
                    );
                  }
                  final jobs = _filter(snapshot.data!);
                  if (jobs.isEmpty) {
                    return _notice(
                      context,
                      Icons.search_off_outlined,
                      'কোনো বিজ্ঞপ্তি পাওয়া যায়নি',
                      snapshot.data!.isEmpty
                          ? 'এখনো কোনো চাকরির বিজ্ঞপ্তি প্রকাশ করা হয়নি।'
                          : 'সার্চ বা ফিল্টার পরিবর্তন করে দেখুন।',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${jobs.length}টি বিজ্ঞপ্তি পাওয়া গেছে',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final job in jobs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _JobCard(
                            job: job,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => JobCircularDetailsPage(job: job),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'আবেদনের আগে নিয়োগদাতার মূল বিজ্ঞপ্তি, যোগ্যতা ও শেষ তারিখ যাচাই করুন।',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _notice(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 48, color: _maroon),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('আবার চেষ্টা করুন'),
            ),
          ],
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final JobCircular job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7E7E9),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.business_center_outlined,
                        color: _maroon, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.organization.isEmpty
                            ? 'প্রতিষ্ঠান উল্লেখ নেই' : job.organization,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 5),
                        Text(
                          job.title,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.3,
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _maroon),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 7,
                children: [
                  if (job.isPinned) _tag('পিন করা', _maroon),
                  if (job.category.isNotEmpty)
                    _tag(job.category, _maroon),
                  if (job.location.isNotEmpty)
                    _tag(job.location, scheme.onSurfaceVariant),
                  _tag(
                    job.isExpired ? 'মেয়াদ শেষ' : 'চলমান',
                    job.isExpired ? scheme.error : const Color(0xFF27815A),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'শেষ তারিখ: ${_dateLabel(job.deadline)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Text(
                    'বিস্তারিত দেখুন',
                    style: TextStyle(
                      color: _maroon,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class JobCircularDetailsPage extends StatelessWidget {
  const JobCircularDetailsPage({super.key, required this.job});

  final JobCircular job;

  @override
  Widget build(BuildContext context) {
    final sections = JobNoticeParser.parse(job.description);
    final location = JobNoticeParser.firstValue(sections, 'jobLocation') ??
        (job.location.isEmpty ? 'উল্লেখ নেই' : job.location);
    final employmentType =
        JobNoticeParser.firstValue(sections, 'employmentStatus') ??
            job.employmentType;
    final workplace = JobNoticeParser.firstValue(sections, 'workplace');
    final salary = job.salary.trim();
    // Earlier admin parsers accidentally saved this heading as a salary.
    final validSalary = salary.toLowerCase() == '& other benefits' ? '' : salary;

    final visibleSections = sections.where((section) =>
        section.key != 'jobLocation' &&
        section.key != 'employmentStatus' &&
        section.key != 'workplace').toList();

    final hasStructuredNotice =
        sections.any((section) => section.key != 'overview');
    final extraRequirements = job.requirements.trim();
    final showExtraRequirements = extraRequirements.isNotEmpty &&
        (!hasStructuredNotice ||
            (extraRequirements.length > 15 &&
                !job.description.toLowerCase().contains(
                      extraRequirements.toLowerCase(),
                    )));

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('নিয়োগ বিজ্ঞপ্তি'),
        backgroundColor: _deepMaroon,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_deepMaroon, _maroon],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.organization.isEmpty
                      ? 'প্রতিষ্ঠান উল্লেখ নেই'
                      : job.organization,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  job.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (job.isPinned) _headerChip('পিন করা', Icons.push_pin),
                    _headerChip(
                      job.deadline == null
                          ? 'শেষ তারিখ উল্লেখ নেই'
                          : job.isExpired
                              ? 'আবেদনের সময় শেষ'
                              : 'আবেদন চলছে',
                      Icons.event_outlined,
                    ),
                    if (job.category.isNotEmpty)
                      _headerChip(job.category, Icons.category_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(Icons.location_on_outlined, 'কর্মস্থল', location),
                  if (workplace != null && workplace.isNotEmpty)
                    _infoRow(Icons.business_outlined, 'কর্মপরিবেশ', workplace),
                  if (employmentType.isNotEmpty)
                    _infoRow(
                      Icons.schedule_outlined,
                      'চাকরির ধরন',
                      employmentType,
                    ),
                  if (job.vacancies.isNotEmpty)
                    _infoRow(Icons.groups_outlined, 'পদসংখ্যা', job.vacancies),
                  if (validSalary.isNotEmpty)
                    _infoRow(Icons.payments_outlined, 'বেতন', validSalary),
                  _infoRow(
                    Icons.event_available_outlined,
                    'আবেদনের শেষ তারিখ',
                    _dateLabel(job.deadline),
                  ),
                  _infoRow(
                    Icons.calendar_today_outlined,
                    'প্রকাশের তারিখ',
                    _dateLabel(job.publishedAt),
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (visibleSections.isNotEmpty)
            for (final section in visibleSections)
              _sectionCard(context, section.title, section.content,
                  _sectionIcon(section.key))
          else if (job.description.trim().isNotEmpty)
            _sectionCard(
              context,
              'চাকরির বিবরণ',
              job.description,
              Icons.description_outlined,
            ),
          if (showExtraRequirements)
            _sectionCard(
              context,
              'অতিরিক্ত যোগ্যতা ও অভিজ্ঞতা',
              extraRequirements,
              Icons.school_outlined,
            ),
          if (job.description.trim().isEmpty && !showExtraRequirements)
            _sectionCard(
              context,
              'বিস্তারিত তথ্য',
              'আবেদনের আগে নিয়োগদাতার মূল বিজ্ঞপ্তি যাচাই করুন।',
              Icons.info_outline,
            ),
          if (job.circularUrl != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openOfficialLink(context, job.circularUrl),
              icon: const Icon(Icons.description_outlined),
              label: const Text('মূল বিজ্ঞপ্তি দেখুন'),
            ),
          ],
          if (job.applyUrl == null) ...[
            const SizedBox(height: 12),
            const Text(
              'এই বিজ্ঞপ্তির আবেদনের লিংক এখনো দেওয়া হয়নি।',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'আবেদনের আগে নিয়োগদাতার মূল বিজ্ঞপ্তি, যোগ্যতা ও শেষ তারিখ যাচাই করুন।',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
      bottomNavigationBar: job.applyUrl == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: job.isExpired
                      ? null
                      : () => _openOfficialLink(context, job.applyUrl),
                  style: FilledButton.styleFrom(
                    backgroundColor: _maroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    job.isExpired ? 'আবেদনের সময় শেষ' : 'আবেদন করুন',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _headerChip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: _maroon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  IconData _sectionIcon(String key) {
    switch (key) {
      case 'education':
        return Icons.school_outlined;
      case 'experience':
        return Icons.history_edu_outlined;
      case 'additionalRequirements':
        return Icons.fact_check_outlined;
      case 'responsibilities':
        return Icons.assignment_outlined;
      case 'skills':
      case 'otherSkills':
        return Icons.verified_outlined;
      case 'benefits':
        return Icons.card_giftcard_outlined;
      case 'gender':
        return Icons.person_outline;
      default:
        return Icons.description_outlined;
    }
  }

  Widget _sectionCard(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 21, color: _maroon),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lines.length > 1) ...[
                      const Text('• ', style: TextStyle(color: _maroon)),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        line.replaceFirst(
                          RegExp(r'^(?:[-•●▪]\s*|\d+[.)]\s*)'),
                          '',
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
