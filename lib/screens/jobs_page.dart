import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/job_circular.dart';
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
  String _sector = 'all';
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
      if (_sector == 'government' && !job.isGovernment) return false;
      if (_sector == 'private' && job.isGovernment) return false;
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
                    label: const Text('সব চাকরি'),
                    selected: _sector == 'all',
                    onSelected: (_) => setState(() => _sector = 'all'),
                  ),
                  ChoiceChip(
                    label: const Text('সরকারি'),
                    selected: _sector == 'government',
                    onSelected: (_) => setState(() => _sector = 'government'),
                  ),
                  ChoiceChip(
                    label: const Text('বেসরকারি'),
                    selected: _sector == 'private',
                    onSelected: (_) => setState(() => _sector = 'private'),
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
                        Text(job.organization,
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
                  _tag(job.isGovernment ? 'সরকারি' : 'বেসরকারি', _maroon),
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('নিয়োগ বিজ্ঞপ্তি'),
          backgroundColor: _deepMaroon,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              job.organization,
              style: const TextStyle(
                fontSize: 14,
                color: _maroon,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              job.title,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _fact(Icons.location_on_outlined, 'কর্মস্থল',
                job.location.isEmpty ? 'উল্লেখ নেই' : job.location),
            _fact(Icons.work_outline, 'চাকরির ধরন',
                job.isGovernment ? 'সরকারি' : 'বেসরকারি'),
            if (job.employmentType.isNotEmpty)
              _fact(Icons.schedule_outlined, 'নিয়োগের ধরন',
                  job.employmentType),
            _fact(Icons.calendar_today_outlined, 'প্রকাশের তারিখ',
                _dateLabel(job.publishedAt)),
            _fact(Icons.event_available_outlined, 'আবেদনের শেষ তারিখ',
                _dateLabel(job.deadline)),
            if (job.salary.isNotEmpty)
              _fact(Icons.payments_outlined, 'বেতন', job.salary),
            if (job.description.isNotEmpty)
              _section('চাকরির বিবরণ', job.description),
            if (job.requirements.isNotEmpty)
              _section('যোগ্যতা ও অভিজ্ঞতা', job.requirements),
            if (job.description.isEmpty && job.requirements.isEmpty)
              _section(
                'বিস্তারিত তথ্য',
                'আবেদনের আগে নিয়োগদাতার মূল বিজ্ঞপ্তি দেখুন।',
              ),
            const SizedBox(height: 12),
            if (job.circularUrl != null)
              OutlinedButton.icon(
                onPressed: () => _openOfficialLink(context, job.circularUrl),
                icon: const Icon(Icons.description_outlined),
                label: const Text('মূল বিজ্ঞপ্তি দেখুন'),
              ),
            const SizedBox(height: 8),
            Text(
              'নিয়োগদাতার মূল বিজ্ঞপ্তি ও ওয়েবসাইট থেকে তথ্য যাচাই করুন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottomNavigationBar: job.applyUrl == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: FilledButton.icon(
                    onPressed: job.isExpired
                        ? null
                        : () => _openOfficialLink(context, job.applyUrl),
                    style: FilledButton.styleFrom(
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(job.isExpired
                        ? 'আবেদনের সময় শেষ'
                        : 'আবেদন করুন'),
                  ),
                ),
              ),
      );

  Widget _fact(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _maroon, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label: $value',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _section(String title, String text) => Padding(
        padding: const EdgeInsets.only(top: 17, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 14, height: 1.6)),
          ],
        ),
      );
}
