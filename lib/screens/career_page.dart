import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_guard.dart';
import '../settings/app_settings.dart';
import '../services/auth_service.dart';
import '../services/career_service.dart';
import '../widgets/free_mock_interview_panel.dart';

class CareerPage extends StatelessWidget {
  const CareerPage({super.key});
  static Future<void> open(BuildContext context, {String? section}) async {
    if (!await AuthGuard.ensureAuthenticated(context) || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => section == null ? const CareerPage() : CareerSection(section: section),
    ));
  }
  @override
  Widget build(BuildContext context) {
    String tr(String bn, String en) => AppText.of(context, bn, en);
    final entries = [
      ('alerts', Icons.notifications_active_outlined, tr('চাকরির অ্যালার্ট','Job alerts'), tr('পদ ও কর্মস্থল অনুযায়ী চাকরি','Jobs matching your preferences')),
      ('mock', Icons.record_voice_over_outlined, tr('মক ইন্টারভিউ','Mock interview'), tr('লিখে ও অফলাইন ভয়েসে অনুশীলন','Practice with text and offline voice')),
      ('courses', Icons.school_outlined, tr('প্রশিক্ষণ ও কোর্স','Training & courses'), tr('প্রকাশিত প্রশিক্ষণের তথ্য','Explore published courses')),
      ('directory', Icons.groups_outlined, tr('পেশাজীবী ডিরেক্টরি','Professional directory'), tr('ঐচ্ছিক পেশাগত পরিচিতি','Optional professional profiles')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('ক্যারিয়ার ডেভেলপমেন্ট','Career development'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FsFeatureCard(icon: Icons.trending_up_rounded, title: tr('ক্যারিয়ার গ্রোথ','Career growth'),
          subtitle: tr('চাকরি • দক্ষতা • প্রশিক্ষণ • পরিচিতি','Jobs • Skills • Training • Network')),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
          final columns = constraints.maxWidth < 340 || largeText ? 1 : constraints.maxWidth >= 720 ? 4 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final e in entries) SizedBox(width: width, child: FsFeatureCard(
              vertical: true, icon: e.$2, title: e.$3, subtitle: e.$4,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CareerSection(section: e.$1))),
            )),
          ]);
        }),
      ]),
    );
  }
}

class CareerSection extends StatefulWidget {
  const CareerSection({super.key, required this.section, this.alertRequest, this.loadCourses, this.directoryRequest, this.directoryWrite, this.loadMock});
  final String section;
  final Future<Map<String, dynamic>> Function(Map<String, String> filters)? loadMock;
  // Optional fixture for directory presentation tests only.
  final Future<Map<String, dynamic>> Function(String action, Map<String, String> filters)? directoryRequest;
  final Future<Map<String, dynamic>> Function(String action, Map<String, dynamic> body)? directoryWrite;
  final Future<Map<String, dynamic>> Function(Map<String, String> filters)? loadCourses;
  // Optional alert-only fixture for widget tests. Normal navigation uses CareerService.
  final Future<Map<String, dynamic>> Function(String action, Map<String, dynamic>? body, Map<String, String> filters)? alertRequest;
  @override
  State<CareerSection> createState() => _CareerSectionState();
}

class _CareerSectionState extends State<CareerSection> {
  final _directorySearch = TextEditingController();
  final _courseSearch = TextEditingController();
  final _keyword = TextEditingController(), _location = TextEditingController(),
      _role = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _busy = true, _enabled = false, _mockVoice = false;
  Map<String, dynamic> _ownProfile = {};
  String _directoryQuery = '';
  String? _error, _next;
  String _status = '';
  String get _section => widget.section;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() {
    for (final c in [_directorySearch,_courseSearch,_keyword,_location,_role]) { c.dispose(); }
    super.dispose();
  }
  Future<void> _load({bool more = false}) async {
    setState(() { _busy = true; _error = null; if (!more) { _rows = []; _next = null; } });
    try {
      final mockLoader = _section == 'mock' ? widget.loadMock : null;
      final directoryLoader = _section == 'directory' ? widget.directoryRequest : null;
      final coursesLoader = _section == 'courses' ? widget.loadCourses : null;
      final fixture = _section == 'alerts' ? widget.alertRequest : null;
      final token = fixture == null && coursesLoader == null && directoryLoader == null && mockLoader == null ? await AuthService.instance.getSessionToken() : null;
      final filters = <String, String>{
        if (more && _next != null) 'before_id': _next!,
        if (_section == 'mock') 'role': _role.text.trim(),
        if (_section == 'directory' && _directoryQuery.isNotEmpty) 'q': _directoryQuery,
      };
      final data = await (mockLoader?.call(filters) ?? directoryLoader?.call(_section, filters) ?? coursesLoader?.call(filters) ?? fixture?.call(_section, null, filters) ?? CareerService.request(_section, filters: filters));
      Map<String, dynamic>? profile;
      if (_section == 'directory' && !more) {
        final mine = await (directoryLoader?.call('my_profile', const {}) ?? CareerService.request('my_profile'));
        if (mine['profile'] is Map) profile = Map<String, dynamic>.from(mine['profile'] as Map);
      }
      if (fixture == null && coursesLoader == null && directoryLoader == null && mockLoader == null && await AuthService.instance.getSessionToken() != token) throw const FormatException('Session changed');
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...CareerService.rows(data)];
        _next = data['next_before_id']?.toString();
        if (_section == 'alerts') {
          final p = Map<String, dynamic>.from(data['preferences'] as Map);
          _enabled = p['enabled'] == true; _keyword.text = CareerService.text(p,'keyword'); _location.text = CareerService.text(p,'location');
        }
        if (_section == 'directory' && !more) {
          final p = profile ?? <String,dynamic>{};
          _ownProfile = p;
          _status = CareerService.text(p,'status');
        }
      });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  void _searchDirectory() {
    if (_busy) return;
    _directoryQuery = _directorySearch.text.trim();
    _load();
  }
  Future<void> _openProfileEditor() async {
    if (_busy || _error != null) return;
    final writer = widget.directoryWrite;
    final token = writer == null ? await AuthService.instance.getSessionToken() : null;
    if (!mounted || _busy) return;
    if (writer == null && (token == null || token.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:
        Text(_tr('আবার লগইন করুন।', 'Please sign in again.'))));
      return;
    }
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _ProfessionalProfileEditorPage(
        profile: Map.of(_ownProfile),
        write: (action, body) async {
          if (writer != null) return writer(action, body);
          if (await AuthService.instance.getSessionToken() != token) {
            throw const FormatException('Session changed');
          }
          return CareerService.request(action, body: body);
        },
      ),
    ));
    if (!mounted || changed != true) return;
    await _load();
    if (mounted && _error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:
        Text(_tr('প্রোফাইল আপডেট হয়েছে।', 'Profile updated.'))));
    }
  }

  Future<void> _write(String action, Map<String,dynamic> body) async {
    setState(() { _busy = true; _error = null; });
    try {
      final fixture = _section == 'alerts' ? widget.alertRequest : null;
      final data = await (fixture?.call(action, body, const {}) ?? CareerService.request(action, body: body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'check_alerts'
          ? _tr('নতুন নোটিফিকেশন: ${data['new_alerts']}', 'New notifications: ${data['new_alerts']}') : action == 'save_alerts' ? _tr('সংরক্ষণ হয়েছে', 'Preferences saved') : 'সংরক্ষণ হয়েছে')));
      await _load();
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  void _showProfileDetails(Map<String, dynamic> profile) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ProfessionalProfileDetailsPage(profile: profile),
    ));
  }

  PreferredSizeWidget _directoryAppBar() => AppBar(
    toolbarHeight: 68, titleSpacing: 8, leadingWidth: 48, centerTitle: false,
    backgroundColor: const Color(0xFF36060D), foregroundColor: Colors.white,
    title: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .24))),
        child: const Icon(Icons.groups_outlined, size: 29, color: Colors.white)),
      const SizedBox(width: 9),
      Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
      const SizedBox(width: 9),
      Expanded(child: Text(_tr('পেশাজীবী ডিরেক্টরি', 'Professional Directory'),
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 15.5,
          fontWeight: FontWeight.w500, height: 1.2))),
    ]),
    actions: [
      _alertHeaderAction(Icons.refresh_rounded, _tr('রিফ্রেশ', 'Refresh'), _busy ? null : () => _load()),
      const SizedBox(width: 8),
    ],
  );

  String _tr(String bn, String en) => AppText.of(context, bn, en);

  void _showAlertInfo() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_tr('চাকরির অ্যালার্ট সম্পর্কে', 'About job alerts')),
      content: SingleChildScrollView(child: Text(_tr(
        'গত ৩০ দিনের প্রকাশিত ও মেয়াদ না পেরোনো বিজ্ঞপ্তি থেকে শব্দের মিল। যোগ্যতা নিশ্চিত করে না। নতুন মিল থাকা চাকরি চেক করলে অ্যাপের ইনবক্সে নোটিফিকেশন যোগ হবে; মোবাইল পুশ নয়।',
        'Matches keywords in unexpired jobs published in the last 30 days. A match does not confirm eligibility. Checking new matching jobs adds in-app inbox notifications, not mobile push notifications.',
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
        child: Text(_tr('বন্ধ করুন', 'Close')))],
    ));
  }

  Widget _alertHeaderAction(IconData icon, String label, VoidCallback? onTap) =>
      Tooltip(message: label, child: Material(color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 48, height: 48, child: Center(child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: onTap == null ? Colors.white54 : Colors.white),
          ))),
        ),
      ));

  PreferredSizeWidget _compactCareerAppBar() => AppBar(
    toolbarHeight: 68, titleSpacing: 8, leadingWidth: 48, centerTitle: false,
    backgroundColor: const Color(0xFF36060D), foregroundColor: Colors.white,
    title: LayoutBuilder(builder: (context, constraints) => Row(children: [
      if (constraints.maxWidth >= 125) ...[
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .24))),
          child: Icon(_section == 'mock' ? Icons.record_voice_over_outlined : Icons.notifications_active_outlined, size: 29, color: Colors.white)),
        const SizedBox(width: 9),
        Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
        const SizedBox(width: 9),
      ],
      Expanded(child: Text(_section == 'mock' ? _tr('মক ইন্টারভিউ', 'Mock Interview') : _tr('চাকরির অ্যালার্ট', 'Job Alerts'),
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 15.5,
          fontWeight: FontWeight.w500, height: 1.2))),
    ])),
    actions: [
      _alertHeaderAction(Icons.info_outline_rounded, _section == 'mock' ? _tr('ইন্টারভিউ সম্পর্কে', 'About interview') : _tr('অ্যালার্ট সম্পর্কে', 'About alerts'), _section == 'mock' ? _showMockInfo : _showAlertInfo),
      _alertHeaderAction(Icons.refresh_rounded, _tr('রিফ্রেশ', 'Refresh'), _busy ? null : () => _load()),
      const SizedBox(width: 8),
    ],
  );

  Widget _alertField(TextEditingController controller, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(controller: controller, enabled: !_busy, maxLength: 120,
      decoration: InputDecoration(
        labelText: label, counterText: '', filled: true, fillColor: scheme.surface,
        prefixIcon: Icon(icon, color: scheme.primary, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Widget _alertPreferences() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(margin: EdgeInsets.zero, child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.notifications_active_outlined, color: scheme.primary),
          title: Text(_tr('চাকরির অ্যালার্ট', 'Job Alert'), style: theme.textTheme.titleSmall),
          subtitle: Text(_enabled ? _tr('বর্তমানে চালু', 'Currently on') : _tr('বর্তমানে বন্ধ', 'Currently off'),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          value: _enabled,
          onChanged: _busy ? null : (value) => setState(() => _enabled = value),
        ),
        Divider(height: 14, color: scheme.outlineVariant),
        _alertField(_keyword, _tr('পদ / যোগ্যতা', 'Role / qualification'), Icons.work_outline),
        const SizedBox(height: 8),
        _alertField(_location, _tr('কর্মস্থল', 'Location'), Icons.location_on_outlined),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final save = FilledButton.icon(
            onPressed: _busy ? null : () => _write('save_alerts', {
              'enabled': _enabled, 'keyword': _keyword.text.trim(),
              'location': _location.text.trim(),
            }),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_tr('সংরক্ষণ', 'Save')),
          );
          final check = OutlinedButton.icon(
            onPressed: _busy ? null : () => _write('check_alerts', {}),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text(_tr('চাকরি খুঁজুন', 'Check jobs')),
          );
          if (constraints.maxWidth < 270 || MediaQuery.textScalerOf(context).scale(14) > 19) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [save, const SizedBox(height: 6), check]);
          }
          return Row(children: [Expanded(child: save), const SizedBox(width: 8), Expanded(child: check)]);
        }),
      ]),
    ));
  }

  Widget _alertJobCard(Map<String, dynamic> row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uri = CareerService.safeLink(CareerService.text(row, 'apply_url'));
    final fields = [
      (Icons.business_outlined, CareerService.text(row, 'organization')),
      (Icons.location_on_outlined, CareerService.text(row, 'location')),
      (Icons.description_outlined, CareerService.text(row, 'requirements')),
      (Icons.event_outlined, CareerService.text(row, 'application_deadline')),
    ];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.work_outline, color: scheme.primary, size: 22)),
          const SizedBox(width: 9),
          Expanded(child: Text(CareerService.text(row, 'title'),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
        ]),
        for (final field in fields)
          if (field.$2.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(field.$1, color: scheme.primary, size: 17),
              const SizedBox(width: 6),
              Expanded(child: Text(field.$2, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
            ]),
          ),
        if (uri != null) Align(alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(_tr('বিস্তারিত লিংক', 'View details')),
            onPressed: () async {
              try {
                if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
              } catch (_) {
                // The error is shown below.
              }
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_tr('লিংক খোলা যায়নি', 'Could not open link'))));
            },
          )),
      ]),
    ));
  }

  List<Widget> _alertContent() => [
    _alertPreferences(),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: Text(_tr('মিল থাকা চাকরি', 'Matching jobs'),
        style: Theme.of(context).textTheme.titleMedium)),
      const SizedBox(width: 8),
      Text(_tr('${_rows.length}টি', '${_rows.length} loaded'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
    const SizedBox(height: 8),
    if (!_busy && _error == null && _rows.isEmpty)
      FsStatusCard(icon: Icons.work_outline,
        message: _tr('এখনো মিল থাকা চাকরি নেই।', 'No matching jobs yet.')),
    for (final row in _rows) _alertJobCard(row),
  ];

  void _showCourseInfo() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_tr('প্রশিক্ষণ ও কোর্স সম্পর্কে', 'About training and courses')),
      content: SingleChildScrollView(child: Text(_tr(
        'প্রতিষ্ঠান, তারিখ, ফি ও সনদের তথ্য অফিসিয়াল উৎসে যাচাই করুন। অ্যাপের মাধ্যমে কোর্সে ভর্তি বা পেমেন্ট হয় না।',
        'Verify the provider, dates, fees and certificates with official sources. This app does not enroll users or accept course payments.',
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('বন্ধ করুন', 'Close')))],
    ));
  }

  PreferredSizeWidget _coursesAppBar() => AppBar(
    toolbarHeight: 68, titleSpacing: 8, leadingWidth: 48, centerTitle: false,
    backgroundColor: const Color(0xFF36060D), foregroundColor: Colors.white,
    title: LayoutBuilder(builder: (context, constraints) => Row(children: [
      if (constraints.maxWidth >= 125) ...[
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .24))),
          child: const Icon(Icons.school_outlined, size: 29, color: Colors.white)),
        const SizedBox(width: 9),
        Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
        const SizedBox(width: 9),
      ],
      Expanded(child: Text(_tr('প্রশিক্ষণ ও কোর্স', 'Training & Courses'),
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 15.5,
          fontWeight: FontWeight.w500, height: 1.2))),
    ])),
    actions: [
      _alertHeaderAction(Icons.info_outline_rounded, _tr('কোর্স সম্পর্কে', 'About courses'), _showCourseInfo),
      _alertHeaderAction(Icons.refresh_rounded, _tr('রিফ্রেশ', 'Refresh'), _busy ? null : () => _load()),
      const SizedBox(width: 8),
    ],
  );

  Widget _courseMeta(IconData icon, String value) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: theme.colorScheme.primary, size: 18),
      const SizedBox(width: 6),
      Expanded(child: Text(value, style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant))),
    ]);
  }

  void _showCourseDetails(Map<String, dynamic> row) {
    final uri = CareerService.safeLink(CareerService.text(row, 'course_url'));
    final provider = CareerService.text(row, 'provider');
    final location = CareerService.text(row, 'location');
    final date = CareerService.text(row, 'start_date');
    final description = CareerService.text(row, 'description');
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .82),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(CareerService.text(row, 'title'), style: theme.textTheme.titleLarge),
              if (provider.isNotEmpty) ...[const SizedBox(height: 8), _courseMeta(Icons.business_outlined, provider)],
              if (location.isNotEmpty) ...[const SizedBox(height: 8), _courseMeta(Icons.location_on_outlined, location)],
              if (date.isNotEmpty) ...[const SizedBox(height: 8), _courseMeta(Icons.event_outlined, date)],
              if (description.isNotEmpty) ...[const Divider(height: 24), SelectableText(description)],
              const SizedBox(height: 12),
              if (uri != null)
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(_tr('কোর্সের ওয়েবসাইট', 'Course website')),
                  onPressed: () async {
                    try {
                      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
                    } catch (_) {
                      // Show the failure to the user below.
                    }
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_tr('লিংক খোলা যায়নি', 'Could not open link'))));
                  },
                ),
              const SizedBox(height: 8),
              Text(_tr('ভর্তি, ফি ও সনদের তথ্য অফিসিয়াল উৎসে যাচাই করুন।',
                'Verify enrollment, fees and certificates with official sources.'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        );
      },
    );
  }

  Widget _courseCard(Map<String, dynamic> row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = CareerService.text(row, 'provider');
    final location = CareerService.text(row, 'location');
    final date = CareerService.text(row, 'start_date');
    return Card(margin: const EdgeInsets.only(bottom: 8), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: () => _showCourseDetails(row),
        child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.school_outlined, color: scheme.primary, size: 25)),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(CareerService.text(row, 'title'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (provider.isNotEmpty) Text(provider, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ])),
              Icon(Icons.chevron_right_rounded, color: scheme.primary),
            ]),
            if (date.isNotEmpty || location.isNotEmpty) ...[
              Divider(height: 18, color: scheme.outlineVariant),
              if (date.isNotEmpty) _courseMeta(Icons.event_outlined, date),
              if (date.isNotEmpty && location.isNotEmpty) const SizedBox(height: 6),
              if (location.isNotEmpty) _courseMeta(Icons.location_on_outlined, location),
            ],
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _showCourseDetails(row),
              child: Text(_tr('বিস্তারিত দেখুন', 'View details'))),
          ]),
        ),
      ),
    );
  }

  List<Widget> _coursesContent() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _courseSearch.text.trim().toLowerCase();
    final visible = _rows.where((row) => ['title', 'provider', 'location', 'description']
      .any((field) => CareerService.text(row, field).toLowerCase().contains(query))).toList();
    return [
      TextField(controller: _courseSearch, maxLength: 160,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: _tr('প্রশিক্ষণ বা কোর্স খুঁজুন', 'Search courses'),
          counterText: '', filled: true, fillColor: scheme.surface,
          prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
          suffixIcon: query.isEmpty ? null : IconButton(
            tooltip: _tr('সার্চ মুছুন', 'Clear search'),
            onPressed: () => setState(_courseSearch.clear), icon: const Icon(Icons.close_rounded)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        )),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text(_tr('প্রকাশিত কোর্স', 'Published courses'), style: theme.textTheme.titleMedium)),
        const SizedBox(width: 8),
        Flexible(child: Text(_tr('${visible.length}টি কোর্স${_next != null ? " (লোড হওয়া)" : ""}',
          '${visible.length} courses${_next != null ? " (loaded)" : ""}'),
          textAlign: TextAlign.end, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
      ]),
      const SizedBox(height: 8),
      if (!_busy && _error == null && visible.isEmpty)
        FsStatusCard(icon: query.isEmpty ? Icons.school_outlined : Icons.search_off_rounded,
          message: query.isEmpty ? _tr('এখনো কোনো কোর্স প্রকাশিত হয়নি।', 'No courses published yet.')
            : _tr('লোড হওয়া কোর্সে কোনো মিল নেই।', 'No matches in loaded courses.')),
      for (final row in visible) _courseCard(row),
    ];
  }

  void _showMockInfo() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_tr('মক ইন্টারভিউ সম্পর্কে', 'About mock interview')),
      content: SingleChildScrollView(child: Text(_tr(
        'প্রথমে নিজের উত্তর দিন। নমুনা উত্তরের শব্দ ও দৈর্ঘ্যের মিল দেখে ফোনেই অনুশীলনের সূচক তৈরি হয়। এটি AI বা পরীক্ষকের মূল্যায়ন নয় এবং তথ্যের সত্যতা বা পেশাগত যোগ্যতা যাচাই করে না। ভয়েস ইনপুটের জন্য Android 12+ ও ইনস্টল করা অফলাইন ভাষা মডেল প্রয়োজন। প্রশ্ন শোনার জন্য অফলাইন TTS ভয়েস প্রয়োজন। ভয়েস বা উত্তর সার্ভারে পাঠানো হয় না।',
        'Answer first. Your device compares words and length with the sample answer. This is not AI or examiner assessment and cannot verify facts or professional competence. Voice input needs Android 12+ and an installed offline language model. Reading questions aloud needs offline TTS. Voice and answers are not sent to a server.',
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
        child: Text(_tr('বন্ধ করুন', 'Close')))],
    ));
  }

  Widget _mockModeTile(bool voice, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _mockVoice == voice;
    return Semantics(key: ValueKey(voice ? 'mock-voice-mode' : 'mock-text-mode'), button: true, selected: selected, child: Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : () => setState(() => _mockVoice = voice),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: selected ? scheme.onPrimaryContainer : scheme.primary, size: 25),
            const SizedBox(height: 5),
            Text(title, textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: FontWeight.w700)),
            Text(subtitle, textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    ));
  }

  List<Widget> _mockContent() => [
    Card(margin: EdgeInsets.zero, child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_tr('ইন্টারভিউ মোড', 'Interview mode'),
          style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final text = _mockModeTile(false, Icons.edit_note_rounded,
            _tr('টেক্সট', 'Text'), _tr('লিখে উত্তর দিন', 'Type an answer'));
          final voice = _mockModeTile(true, Icons.mic_none_rounded,
            _tr('ভয়েস', 'Voice'), _tr('বলে উত্তর দিন', 'Speak an answer'));
          if (constraints.maxWidth < 240 || MediaQuery.textScalerOf(context).scale(14) > 19) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 8), voice]);
          }
          return Row(children: [Expanded(child: text), const SizedBox(width: 8), Expanded(child: voice)]);
        }),
        const SizedBox(height: 10),
        _alertField(_role, _tr('পদের নাম (ঐচ্ছিক)', 'Exact role (optional)'), Icons.work_outline),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: Text(_tr('ইন্টারভিউ শুরু করুন', 'Start interview'))),
      ]),
    )),
    const SizedBox(height: 10),
    if (_error == null || _rows.isNotEmpty)
      FreeMockInterviewPanel(
        questions: _rows,
        role: _role.text.trim(),
        voiceMode: _mockVoice,
        onRestart: _busy ? null : () => _load(),
      ),
    const SizedBox(height: 8),
    Text(_tr('সম্পূর্ণ বিনামূল্যে অনুশীলন', 'Free practice'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ];

  List<Widget> _content() {
    if (_section == 'alerts') return _alertContent();
    if (_section == 'mock') return _mockContent();
    if (_section == 'courses') return _coursesContent();
    final query = _directoryQuery;
    final visibleProfiles = _rows;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return [
      TextField(
        controller: _directorySearch,
        enabled: !_busy,
        maxLength: 160,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _searchDirectory(),
        decoration: InputDecoration(
          prefixIcon: IconButton(onPressed: _busy ? null : _searchDirectory,
            icon: Icon(Icons.search_rounded, color: scheme.primary),
            tooltip: _tr('খুঁজুন', 'Search')),
          hintText: _tr('পেশাজীবী খুঁজুন', 'Search professionals'),
          filled: true, fillColor: scheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          counterText: '',
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _busy || _error != null ? null : _openProfileEditor,
        icon: Icon(_status.isEmpty ? Icons.person_add_alt_1 : Icons.edit_outlined, size: 20),
        label: Text(_status.isEmpty ? _tr('প্রোফাইল যোগ করুন', 'Add profile') : _tr('প্রোফাইল সম্পাদনা', 'Edit profile')),
      )),
      if (_status.isNotEmpty) Card(child: ListTile(
        leading: Icon(_status == 'approved' ? Icons.verified_outlined : Icons.hourglass_top,
          color: _status == 'approved' ? Colors.green : null),
        title: Text(_tr('আপনার প্রোফাইলের অবস্থা', 'Your profile status')),
        subtitle: Text(({'pending':_tr('অনুমোদনের অপেক্ষায়','Pending approval'),'approved':_tr('প্রকাশিত','Published'),'hidden':_tr('লুকানো','Hidden')})[_status] ?? _status),
      )),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Text(_tr('পেশাজীবী','Professionals'), 
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        Text(_tr('${visibleProfiles.length} জন','${visibleProfiles.length} loaded'), style: Theme.of(context).textTheme.bodySmall),
      ]),
      const SizedBox(height: 8),
      if (!_busy && _error == null && visibleProfiles.isEmpty)
        FsStatusCard(icon: Icons.groups_outlined,
          message: query.isEmpty ? _tr('এখনো কোনো প্রোফাইল নেই।', 'No profiles yet.')
            : _tr('কোনো প্রোফাইল পাওয়া যায়নি।', 'No matching profiles.')),
      for (final row in visibleProfiles) Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showProfileDetails(row),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              _PrivateProfileAvatar(
                key: ValueKey(CareerService.text(row,'id')),
                photoKey: CareerService.text(row,'photo_path'),
                radius: 26,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(CareerService.text(row,'display_name'),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(CareerService.text(row,'role_name'),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                if (CareerService.text(row,'organization').isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(children: [const Icon(Icons.business_outlined,size:16),const SizedBox(width:5),
                    Expanded(child: Text(CareerService.text(row,'organization')))]),
                ],
                if (CareerService.text(row,'city').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [const Icon(Icons.location_on_outlined,size:16),const SizedBox(width:5),
                    Expanded(child: Text(CareerService.text(row,'city')))]),
                ],
              ])),
              const SizedBox(width: 6),
              Tooltip(message: _tr('বিস্তারিত দেখুন', 'View details'), child: Icon(Icons.chevron_right, color: scheme.primary)),
            ]),
          ),
        ),
      ),
    ];
  }
  @override
  Widget build(BuildContext context) {
    String tr(String bn, String en) => AppText.of(context, bn, en);
    final titles = {
      'alerts': tr('চাকরির অ্যালার্ট', 'Job Alerts'),
      'mock': tr('মক ইন্টারভিউ', 'Mock Interview'),
      'courses': tr('প্রশিক্ষণ ও কোর্স', 'Training & Courses'),
      'directory': tr('পেশাজীবী ডিরেক্টরি', 'Professional Directory'),
    };
    return Scaffold(
    appBar: _section == 'directory' ? _directoryAppBar() : _section == 'courses' ? _coursesAppBar() : (_section == 'alerts' || _section == 'mock') ? _compactCareerAppBar() : AppBar(
      title: Row(
        children: [
          if (_section == 'directory') ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.groups_outlined,
                color: Theme.of(context).colorScheme.primary, size: 23),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              titles[_section] ?? tr('ক্যারিয়ার', 'Career'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
          tooltip: tr('রিফ্রেশ', 'Refresh'),
        ),
      ],
    ),
    body: ListView(padding: (_section == 'alerts' || _section == 'courses' || _section == 'directory' || _section == 'mock') ? const EdgeInsets.fromLTRB(14, 10, 14, 22) : const EdgeInsets.all(16),children:[
      if(_busy) const LinearProgressIndicator(),
      if(_error != null) Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(!_busy || _rows.isNotEmpty) ..._content(),
      if(_section!='directory'&&_section!='alerts'&&_section!='courses'&&_section!='mock'&&!_busy&&_error==null&&_rows.isEmpty) const Padding(padding:EdgeInsets.all(12),child:Text('এখন কোনো তথ্য পাওয়া যায়নি।')),
      if(_next!=null) OutlinedButton(onPressed:_busy?null:()=>_load(more:true),child:Text((_section == 'alerts' || _section == 'courses' || _section == 'directory') ? _tr('আরও দেখুন', 'Load more') : 'আরও দেখুন')),
    ]));
  }
}


class _ProfessionalProfileEditorPage extends StatefulWidget {
  const _ProfessionalProfileEditorPage({required this.profile, required this.write});
  final Map<String, dynamic> profile;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) write;
  @override
  State<_ProfessionalProfileEditorPage> createState() => _ProfessionalProfileEditorPageState();
}

class _ProfessionalProfileEditorPageState extends State<_ProfessionalProfileEditorPage> {
  late final _name = TextEditingController(text: CareerService.text(widget.profile, 'display_name'));
  late final _role = TextEditingController(text: CareerService.text(widget.profile, 'role_name'));
  late final _organization = TextEditingController(text: CareerService.text(widget.profile, 'organization'));
  late final _city = TextEditingController(text: CareerService.text(widget.profile, 'city'));
  late final _bio = TextEditingController(text: CareerService.text(widget.profile, 'bio'));
  String get _status => CareerService.text(widget.profile, 'status');
  String get _photoPath => CareerService.text(widget.profile, 'photo_path');
  Uint8List? _photo;
  bool _removePhoto = false, _consent = false, _busy = false, _picking = false;
  String? _error;
  bool get _blocked => _busy || _picking;
  String _tr(String bn, String en) => AppText.of(context, bn, en);

  @override
  void dispose() {
    for (final controller in [_name, _role, _organization, _city, _bio]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showInfo() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_tr('প্রোফাইল সম্পর্কে', 'About profiles')),
      content: SingleChildScrollView(child: Text(_tr(
        'অ্যাডমিন অনুমোদনের পর নিবন্ধিত ব্যবহারকারীরা প্রোফাইল দেখতে পারবেন। ফোন নম্বর, ইমেইল বা ব্যক্তিগত লিংক দেবেন না। এটি পেশাগত সনদ যাচাই নয়। ছবি স্বয়ংক্রিয়ভাবে ছোট করা হবে; নির্বাচনের পর ছবির আকার ২ MB-এর মধ্যে থাকতে হবে।',
        'Registered users can view profiles after admin approval. Do not include phone numbers, email or personal links. Approval is not verification of professional certificates. Photos are resized automatically; selected image bytes must be within 2 MB.',
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
        child: Text(_tr('বন্ধ করুন','Close')))],
    ));
  }

  Future<void> _pickPhoto() async {
    if (_blocked) return;
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery,
        imageQuality: 82, maxWidth: 720, maxHeight: 720);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 2097152) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:
          Text(_tr('ছবির আকার ২ MB-এর মধ্যে রাখুন','Keep the image within 2 MB.'))));
        return;
      }
      setState(() { _photo = bytes; _removePhoto = false; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:
        Text(_tr('ছবি নির্বাচন করা যায়নি','Could not select photo.'))));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_blocked || !_consent || _name.text.trim().isEmpty || _role.text.trim().isEmpty) return;
    await _send('save_profile', {
      'consent': true, 'display_name': _name.text, 'role_name': _role.text,
      'organization': _organization.text, 'city': _city.text, 'bio': _bio.text,
      if (_photo != null) 'photo_base64': base64Encode(_photo!),
      if (_removePhoto) 'remove_photo': true,
    });
  }

  Future<void> _send(String action, Map<String, dynamic> body) async {
    if (_blocked) return;
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; });
    try {
      await widget.write(action, body);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.toString(); });
    }
  }

  Future<void> _hide() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_tr('পরিচিতি লুকাবেন?', 'Hide profile?')),
      content: Text(_tr('আপনার পরিচিতি অন্য ব্যবহারকারীরা আর দেখতে পাবেন না।',
        'Other users will no longer see your profile.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr('বাতিল','Cancel'))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_tr('লুকান','Hide'))),
      ],
    ));
    if (mounted && confirmed == true) await _send('hide_profile', {});
  }

  Widget _field(TextEditingController controller, IconData icon, String label, int max) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(controller: controller, enabled: !_blocked, maxLength: max,
      textInputAction: TextInputAction.next, onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, counterText: '',
        prefixIcon: Icon(icon, size: 20, color: scheme.primary),
        filled: true, fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSubmit = !_blocked && _consent && _name.text.trim().isNotEmpty && _role.text.trim().isNotEmpty;
    return PopScope(canPop: !_busy, child: Scaffold(
      appBar: AppBar(toolbarHeight: 68, titleSpacing: 8, leadingWidth: 48,
        centerTitle: false, backgroundColor: const Color(0xFF36060D), foregroundColor: Colors.white,
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .24))),
            child: Icon(_status.isEmpty ? Icons.person_add_alt_1 : Icons.edit_outlined,
              size: 26, color: Colors.white)),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_status.isEmpty ? _tr('প্রোফাইল তৈরি করুন','Create profile')
            : _tr('প্রোফাইল সম্পাদনা','Edit profile'), maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: Colors.white))),
        ]),
        actions: [IconButton(onPressed: _busy ? null : _showInfo,
          tooltip: _tr('প্রোফাইল সম্পর্কে','About profiles'), icon: const Icon(Icons.info_outline, size: 22))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 24), children: [
        if (_busy || _picking) const LinearProgressIndicator(),
        Center(child: _photo != null
          ? CircleAvatar(radius: 38, backgroundImage: MemoryImage(_photo!))
          : _PrivateProfileAvatar(photoKey: _removePhoto ? '' : _photoPath, radius: 38)),
        Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
          TextButton.icon(onPressed: _blocked ? null : _pickPhoto,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(_tr('ছবি নির্বাচন করুন','Choose photo'))),
          if (_photo != null || (!_removePhoto && _photoPath.isNotEmpty))
            TextButton.icon(onPressed: _blocked ? null : () => setState(() {
              _photo = null; _removePhoto = true;
            }), icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(_tr('ছবি সরান','Remove photo'))),
        ]),
        Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_tr('পেশাগত তথ্য','Professional information'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _field(_name, Icons.person_outline, _tr('প্রদর্শিত নাম *','Display name *'), 100),
            const SizedBox(height: 8),
            _field(_role, Icons.work_outline, _tr('পদ / পেশা *','Position / profession *'), 120),
            const SizedBox(height: 8),
            _field(_organization, Icons.business_outlined, _tr('প্রতিষ্ঠান (ঐচ্ছিক)','Organization (optional)'), 120),
            const SizedBox(height: 8),
            _field(_city, Icons.location_on_outlined, _tr('শহর (ঐচ্ছিক)','City (optional)'), 100),
            const SizedBox(height: 8),
            TextField(controller: _bio, enabled: !_blocked, minLines: 3, maxLines: 7,
              maxLength: 2000, textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _tr('বিস্তারিত পরিচিতি (ঐচ্ছিক)','Professional summary (optional)'),
                alignLabelWithHint: true, filled: true, fillColor: scheme.surface,
                prefixIcon: Icon(Icons.description_outlined, size: 20, color: scheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              )),
            Text(_tr('ফোন নম্বর, ইমেইল বা ব্যক্তিগত লিংক লিখবেন না।',
              'Do not include phone numbers, email or personal links.'),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        )),
        const SizedBox(height: 8),
        CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
          value: _consent, onChanged: _blocked ? null : (value) => setState(() => _consent = value == true),
          title: Text(_tr('আমার তথ্য নিবন্ধিত ব্যবহারকারীদের দেখাতে সম্মত।',
            'I consent to showing my information to registered users.'), style: theme.textTheme.bodyMedium)),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text(_error!, style: TextStyle(color: scheme.error))),
        FilledButton.icon(onPressed: canSubmit ? _submit : null,
          icon: const Icon(Icons.send_outlined, size: 18),
          label: Text(_tr('জমা দিন','Submit'))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.info_outline, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(child: Text(_tr('অ্যাডমিন অনুমোদনের পর প্রকাশিত হবে','Published after admin approval'),
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
        ]),
        if (_status.isNotEmpty && _status != 'hidden') ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _blocked ? null : _hide,
            child: Text(_tr('আমার পরিচিতি লুকান','Hide my profile'))),
        ],
      ]),
    ));
  }
}

class _ProfessionalProfileDetailsPage extends StatelessWidget {
  const _ProfessionalProfileDetailsPage({required this.profile});
  final Map<String, dynamic> profile;

  Widget _detail(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ])),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    String tr(String bn, String en) => AppText.of(context, bn, en);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = CareerService.text(profile, 'display_name');
    final role = CareerService.text(profile, 'role_name');
    final organization = CareerService.text(profile, 'organization');
    final city = CareerService.text(profile, 'city');
    final bio = CareerService.text(profile, 'bio');
    return Scaffold(
      appBar: AppBar(toolbarHeight: 68, titleSpacing: 8, leadingWidth: 48,
        centerTitle: false, backgroundColor: const Color(0xFF36060D),
        foregroundColor: Colors.white,
        title: Text(tr('পেশাগত পরিচিতি','Professional profile'),
          style: const TextStyle(fontSize: 15.5, color: Colors.white))),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 16, 14, 24), children: [
        Center(child: _PrivateProfileAvatar(photoKey: CareerService.text(profile, 'photo_path'), radius: 48)),
        const SizedBox(height: 12),
        Text(name, textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (role.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(role, textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
        ],
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, size: 17, color: scheme.primary),
          const SizedBox(width: 5),
          Flexible(child: Text(tr('অনুমোদিত প্রোফাইল','Approved profile'),
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall)),
        ]),
        const SizedBox(height: 16),
        if (role.isNotEmpty || organization.isNotEmpty || city.isNotEmpty)
          Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (role.isNotEmpty) _detail(context, Icons.work_outline, tr('পদবি','Position'), role),
              if (organization.isNotEmpty) ...[
                if (role.isNotEmpty) Divider(height: 12, color: scheme.outlineVariant),
                _detail(context, Icons.business_outlined, tr('প্রতিষ্ঠান','Organization'), organization),
              ],
              if (city.isNotEmpty) ...[
                if (role.isNotEmpty || organization.isNotEmpty) Divider(height: 12, color: scheme.outlineVariant),
                _detail(context, Icons.location_on_outlined, tr('কর্মস্থল / শহর','Workplace / city'), city),
              ],
            ]),
          )),
        if (bio.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.description_outlined, color: scheme.primary, size: 21),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('বিস্তারিত পরিচিতি','Professional summary'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
              SelectableText(bio, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
            ]),
          )),
        ],
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: scheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(tr(
            'অ্যাডমিন অনুমোদিত পরিচিতি। এটি পেশাগত সনদ যাচাইয়ের বিকল্প নয়।',
            'Admin-approved profile. This is not a verification of professional certificates.'),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
        ]),
      ]),
    );
  }
}

class _PrivateProfileAvatar extends StatefulWidget {
  const _PrivateProfileAvatar({super.key, required this.photoKey, required this.radius});
  final String photoKey;
  final double radius;
  @override
  State<_PrivateProfileAvatar> createState() => _PrivateProfileAvatarState();
}

class _PrivateProfileAvatarState extends State<_PrivateProfileAvatar> {
  late Future<Uint8List?> _photo;
  @override
  void initState() {
    super.initState();
    _photo = CareerService.photoBytes(widget.photoKey);
  }
  @override
  void didUpdateWidget(covariant _PrivateProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoKey != widget.photoKey) {
      _photo = CareerService.photoBytes(widget.photoKey);
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _photo,
    builder: (context, snapshot) {
      final bytes = snapshot.connectionState == ConnectionState.done ? snapshot.data : null;
      return CircleAvatar(
        radius: widget.radius,
        child: bytes == null
          ? Icon(Icons.person_outline, size: widget.radius)
          : ClipOval(child: Image.memory(bytes, width: widget.radius * 2, height: widget.radius * 2,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person_outline, size: widget.radius))),
      );
    },
  );
}
