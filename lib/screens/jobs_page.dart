import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/job_circular.dart';
import '../utils/job_notice_sections.dart';
import '../services/job_circular_service.dart';
import '../services/auth_guard.dart';
import '../settings/app_settings.dart';
import 'submit_job_page.dart';
import 'career_page.dart';

const Color _maroon = Color(0xFF650D18);
const Color _deepMaroon = Color(0xFF36060D);

String _dateLabel(DateTime? date) {
  if (date == null) return 'উল্লেখ নেই';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

String _displayLocation(JobCircular job) {
  final saved = job.location.trim();
  if (saved.isNotEmpty && saved.toLowerCase() != 'work at office') {
    return saved;
  }
  final parsed = JobNoticeParser.firstValue(
    JobNoticeParser.parse(job.description), 'jobLocation',
  );
  return parsed ?? (saved.toLowerCase() == 'work at office' ? '' : saved);
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
  const JobsPage({super.key, this.initialSearch = '', this.loadJobs});
  final String initialSearch;
  // Test fixture loader; production retains the existing API service.
  final Future<List<JobCircular>> Function()? loadJobs;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  late Future<List<JobCircular>> _jobs;
  late final _search = TextEditingController(text: widget.initialSearch);
  bool _pinnedOnly = false;
  String _deadline = 'active';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _jobs = widget.loadJobs?.call() ?? JobCircularService.instance.fetchCirculars();
  }

  Future<void> _openSubmit() async {
    final allowed = await AuthGuard.ensureAuthenticated(context);
    if (!mounted || !allowed) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SubmitJobPage()),
    );
    if (mounted) await _refresh();
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

  String _tr(String bn, String en) => AppText.of(context, bn, en);

  List<JobCircular> _filter(List<JobCircular> jobs) {
    final query = _search.text.trim().toLowerCase();
    return jobs.where((job) {
      if (_pinnedOnly && !job.isPinned) return false;
      if (_deadline == 'active' && job.isExpired) return false;
      if (_deadline == 'expired' && !job.isExpired) return false;
      return query.isEmpty ||
          job.title.toLowerCase().contains(query) ||
          job.organization.toLowerCase().contains(query) ||
          _displayLocation(job).toLowerCase().contains(query) ||
          job.category.toLowerCase().contains(query);
    }).toList(growable: false);
  }


  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        backgroundColor: _deepMaroon,
        foregroundColor: Colors.white,
        centerTitle: false,
        leadingWidth: 48,
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
            ),
            child: const Icon(Icons.work_outline, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42,
            color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_tr('চাকরির বিজ্ঞপ্তি', 'Fire & Safety Jobs'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
        actions: [
          _headerAction(
            tooltip: _tr('চাকরির অ্যালার্ট', 'Job Alert'),
            icon: Icons.notifications_active_outlined,
            onPressed: () => CareerPage.open(context, section: 'alerts'),
          ),
          const SizedBox(width: 5),
          _headerAction(
            tooltip: _tr('রিফ্রেশ', 'Refresh'),
            icon: Icons.refresh_rounded,
            onPressed: _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
          children: [
            _submitCallout(context),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, color: accent),
                hintText: _tr('চাকরি খুঁজুন', 'Search jobs'),
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: scheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: _tr('সার্চ মুছুন', 'Clear search'),
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            _filterPanel(context),
            const SizedBox(height: 10),
            FutureBuilder<List<JobCircular>>(
              future: _jobs,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: FsLoadingCards(count: 3),
                  );
                }
                if (snapshot.hasError) {
                  return _notice(
                    context,
                    Icons.wifi_off_outlined,
                    _tr('চাকরির বিজ্ঞপ্তি লোড হয়নি।', 'Could not load jobs.'),
                    _tr('সংযোগ দেখে আবার চেষ্টা করুন।', 'Check your connection and try again.'),
                    onRetry: _refresh,
                  );
                }
                final jobs = _filter(snapshot.data!);
                if (jobs.isEmpty) {
                  return _notice(
                    context,
                    Icons.search_off_outlined,
                    _tr('কোনো বিজ্ঞপ্তি পাওয়া যায়নি', 'No jobs found'),
                    snapshot.data!.isEmpty
                        ? _tr('এখনো কোনো বিজ্ঞপ্তি প্রকাশ হয়নি।', 'No jobs have been published yet.')
                        : _tr('সার্চ বা ফিল্টার পরিবর্তন করুন।', 'Change your search or filters.'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(_tr('চাকরি', 'Jobs'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 8),
                      Flexible(child: Text(
                        _tr('${jobs.length}টি বিজ্ঞপ্তি', '${jobs.length} listings'),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant))),
                    ]),
                    const SizedBox(height: 8),
                    for (final job in jobs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
            const SizedBox(height: 14),
            Text(
              _tr('আবেদনের আগে মূল বিজ্ঞপ্তি, যোগ্যতা ও শেষ তারিখ যাচাই করুন।', 'Verify the original notice, eligibility and deadline before applying.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 48, height: 48,
          child: Center(child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          )),
        ),
      ),
    ),
  );

  Widget _submitCallout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openSubmit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.add_circle_outline_rounded,
                size: 21, color: scheme.primary)),
            const SizedBox(width: 9),
            Expanded(child: Text(_tr('সার্কুলার জমা দিন', 'Submit a circular'),
              style: Theme.of(context).textTheme.titleSmall)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: scheme.primary),
          ]),
        ),
      ),
    );
  }

  Widget _filterPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFilters = _pinnedOnly || _deadline != 'active' ||
        _search.text.trim().isNotEmpty;
    return Wrap(
      spacing: 5, runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _statusOption(_tr('চলমান', 'Active'), 'active'),
        _statusOption(_tr('সবগুলো', 'All'), 'all'),
        _statusOption(_tr('মেয়াদ শেষ', 'Expired'), 'expired'),
        Semantics(
          selected: _pinnedOnly,
          button: true,
          child: IconButton(
            tooltip: _tr('শুধু পিন করা', 'Pinned only'),
            isSelected: _pinnedOnly,
            onPressed: () => setState(() => _pinnedOnly = !_pinnedOnly),
            icon: const Icon(Icons.push_pin_outlined, size: 19),
            selectedIcon: const Icon(Icons.push_pin, size: 19),
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: _pinnedOnly ? scheme.primary : scheme.surface,
              foregroundColor: _pinnedOnly ? scheme.onPrimary : scheme.primary,
              side: BorderSide(color: _pinnedOnly ? scheme.primary : scheme.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        if (hasFilters)
          IconButton(
            tooltip: _tr('ফিল্টার রিসেট', 'Reset filters'),
            onPressed: () => setState(() {
              _search.clear();
              _pinnedOnly = false;
              _deadline = 'active';
            }),
            icon: Icon(Icons.restart_alt_rounded, color: scheme.primary),
          ),
      ],
    );
  }

  Widget _statusOption(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _deadline == value;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _deadline = value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Align(widthFactor: 1, heightFactor: 1,
                child: Text(label, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
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
              label: Text(_tr('আবার চেষ্টা করুন', 'Try again')),
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

  String _tr(BuildContext context, String bn, String en) => AppText.of(context, bn, en);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = _displayLocation(job);
    final accent = scheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.business_center_outlined,
                        color: accent, size: 23),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.title,
                          style: TextStyle(fontSize: 15, height: 1.3,
                            color: scheme.onSurface, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(job.organization.isEmpty
                            ? _tr(context, 'প্রতিষ্ঠান উল্লেখ নেই', 'Organization not specified')
                            : job.organization,
                          style: TextStyle(fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: accent),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  if (job.isPinned) _tag(_tr(context, 'পিন করা', 'Pinned'), accent),
                  if (job.category.isNotEmpty)
                    _tag(job.category, accent),
                  if (location.isNotEmpty)
                    _tag(location, scheme.onSurfaceVariant),
                  _tag(
                    job.isExpired ? _tr(context, 'মেয়াদ শেষ', 'Expired') : _tr(context, 'চলমান', 'Active'),
                    job.isExpired ? scheme.error : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8DDEB2) : const Color(0xFF176B46)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(height: 9, color: scheme.outlineVariant),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _tr(context, 'শেষ তারিখ: ${_dateLabel(job.deadline)}',
                        'Deadline: ${job.deadline == null ? 'Not specified' : _dateLabel(job.deadline)}'),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: Text(
                    _tr(context, 'বিস্তারিত দেখুন', 'View details'),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: accent, fontSize: 12,
                      fontWeight: FontWeight.w700),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
    final parsedLocation = JobNoticeParser.firstValue(sections, 'jobLocation');
    // Respect a manually corrected DB location. Older parser versions saved
    // "Work at office" in the location field, which is not a place.
    final location = job.location.trim().isEmpty ||
            job.location.trim().toLowerCase() == 'work at office'
        ? (parsedLocation ?? (job.location.isEmpty ? 'উল্লেখ নেই' : job.location))
        : job.location;
    final employmentType = job.employmentType.trim().isNotEmpty
        ? job.employmentType
        : (JobNoticeParser.firstValue(sections, 'employmentStatus') ?? '');
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
    final requirementLines = extraRequirements
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().toLowerCase())
        .where((line) => line.length > 10);
    final alreadyInNotice = requirementLines.any(
      (line) => job.description.toLowerCase().contains(line),
    );
    final showExtraRequirements = extraRequirements.isNotEmpty &&
        (!hasStructuredNotice ||
            (extraRequirements.length > 15 && !alreadyInNotice));

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
                  if (job.contactMobile != null)
                    _infoRow(Icons.phone_outlined, 'যোগাযোগের মোবাইল',
                        job.contactMobile!),
                  if (job.contactWhatsapp != null)
                    _infoRow(Icons.chat_outlined, 'WhatsApp নম্বর',
                        job.contactWhatsapp!),
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
          if (job.contactMobile != null || job.contactWhatsapp != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (job.contactMobile != null)
                  OutlinedButton.icon(
                    onPressed: () => _contactAction(
                      context, Uri(scheme: 'tel', path: job.contactMobile!),
                    ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('কল করুন'),
                  ),
                if (job.contactWhatsapp != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      var number = job.contactWhatsapp!.replaceAll('+', '');
                      if (number.startsWith('01') && number.length == 11) {
                        number = '88' + number;
                      }
                      _contactAction(
                        context,
                        Uri.https('wa.me', '/' + number),
                      );
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
              ],
            ),
          ],
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

Future<void> _contactAction(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Show a user-facing error below.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('যোগাযোগের অ্যাপ খোলা যায়নি।')),
    );
  }
}
