import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import '../models/category_labels.dart';
import '../services/homepage_service.dart';
import '../settings/app_settings.dart';
import 'tests_page.dart';
import '../services/premium_service.dart';
import 'premium_page.dart';

import 'question_browser_page.dart';

class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key, this.initialSearch = '', this.loadCategories});
  final String initialSearch;
  // Optional fixture loader for presentation tests.
  final Future<Map<String, dynamic>> Function()? loadCategories;

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  late final TextEditingController _search =
      TextEditingController(text: widget.initialSearch);
  late Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() =>
      widget.loadCategories?.call() ?? HomepageService.fetch('question_categories');

  String _tr(String bn, String en) => AppText.of(context, bn, en);

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _data = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder displays the error and retry action.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.push(
    context, MaterialPageRoute<void>(builder: (_) => page),
  );

  Widget _shortcut(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: scheme.primary, size: 24),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _shortcuts() => LayoutBuilder(builder: (context, constraints) {
    final scale = MediaQuery.textScalerOf(context).scale(14);
    final columns = constraints.maxWidth < 280 || scale > 19 ? 1 : 3;
    final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      SizedBox(width: width, child: _shortcut(Icons.search_rounded,
        _tr('প্রশ্ন খুঁজুন', 'Find questions'),
        () => _open(QuestionBrowserPage(initialSearch: _search.text.trim())))),
      SizedBox(width: width, child: _shortcut(Icons.bookmark_outline,
        _tr('বুকমার্ক', 'Bookmarks'),
        () => _open(const QuestionBrowserPage(savedOnly: true)))),
      SizedBox(width: width, child: _shortcut(Icons.insights_rounded,
        _tr('আমার প্রস্তুতি', 'My progress'),
        () => _open(const PracticeDashboardPage()))),
    ]);
  });

  IconData _categoryIcon(String key) {
    final value = key.toLowerCase();
    if (value.contains('fire') || value.contains('আগুন') || value.contains('অগ্নি')) {
      return Icons.local_fire_department_outlined;
    }
    if (value.contains('electrical') || value.contains('বিদ্যুৎ')) return Icons.bolt_outlined;
    if (value.contains('first aid') || value.contains('প্রাথমিক চিকিৎসা')) return Icons.medical_services_outlined;
    if (value.contains('safety') || value.contains('নিরাপত্তা')) return Icons.health_and_safety_outlined;
    return Icons.quiz_outlined;
  }

  Widget _categoryCard(Map<String, dynamic> row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final key = HomepageService.text(row, 'category');
    final label = categoryDisplayFromRow(row, 'category', Localizations.localeOf(context).languageCode);
    final count = row['question_count'];
    final locked = row['locked_count'];
    final hasLocked = (locked as num? ?? 0) > 0;
    final countLabel = _tr('${count}টি প্রশ্ন', '$count questions');
    final premiumLabel = hasLocked ? _tr(' · ${locked}টি Premium', ' · $locked Premium') : '';
    void browse() => _open(QuestionBrowserPage(category: key, categoryLabel: label));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
        leading: Container(width: 42, height: 42,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(_categoryIcon(key), color: scheme.primary, size: 24)),
        title: Text(label, style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurface, fontWeight: FontWeight.w700)),
        subtitle: Text('$countLabel$premiumLabel',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        trailing: IconButton(
          tooltip: _tr('এই বিভাগের প্রশ্ন দেখুন', 'Browse questions in this category'),
          icon: Icon(Icons.list_alt_outlined, color: scheme.primary, size: 22),
          onPressed: browse,
        ),
        onTap: () => row['locked_count'] == row['question_count']
            ? browse()
            : _open(SubjectPracticePage(subject: key, subjectLabel: label)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        backgroundColor: const Color(0xFF36060D),
        foregroundColor: Colors.white,
        centerTitle: false,
        leadingWidth: 48,
        title: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24))),
            child: const Icon(Icons.menu_book_outlined, color: Colors.white, size: 29)),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_tr('প্রশ্ন ব্যাংক', 'Question Bank'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
        actions: [
          Tooltip(message: _tr('রিফ্রেশ', 'Refresh'), child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: _refresh, borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 48, height: 48,
                child: Center(child: Container(width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white))))))),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, snapshot) {
            final rows = HomepageService.rows(snapshot.data?['data']);
            final query = _search.text.trim().toLowerCase();
            final filtered = rows.where((row) => categoryMatches(row, 'category', query)).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
                    hintText: _tr('প্রশ্নের বিভাগ খুঁজুন', 'Search categories'),
                    filled: true, fillColor: scheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    suffixIcon: _search.text.isEmpty ? null : IconButton(
                      tooltip: _tr('সার্চ মুছুন', 'Clear search'),
                      onPressed: () => setState(_search.clear),
                      icon: const Icon(Icons.close_rounded)),
                  ),
                ),
                const SizedBox(height: 10),
                _shortcuts(),
                const SizedBox(height: 14),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const FsLoadingCards(count: 3)
                else if (snapshot.hasError || !snapshot.hasData)
                  FsStatusCard(icon: Icons.error_outline,
                    message: _tr('প্রশ্নের বিভাগ লোড হয়নি।', 'Could not load categories.'),
                    onRetry: _refresh)
                else ...[
                  Row(children: [
                    Icon(Icons.grid_view_rounded, color: scheme.primary, size: 20),
                    const SizedBox(width: 7),
                    Expanded(child: Text(_tr('বিষয়সমূহ', 'Subjects'),
                      style: theme.textTheme.titleMedium)),
                    Flexible(child: Text(_tr('${filtered.length}টি বিভাগ', '${filtered.length} categories'),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
                  ]),
                  const SizedBox(height: 8),
                  for (final row in filtered) _categoryCard(row),
                  if (filtered.isEmpty)
                    FsStatusCard(icon: Icons.search_off_outlined,
                      message: _tr('কোনো বিভাগ পাওয়া যায়নি।', 'No categories found.')),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class InterviewPage extends StatefulWidget {
  const InterviewPage({super.key, this.initialSearch = ''});
  final String initialSearch;
  @override
  State<InterviewPage> createState() => _InterviewPageState();
}

class _InterviewPageState extends State<InterviewPage> {
  late final TextEditingController _search = TextEditingController(text: widget.initialSearch);
  String _role = '', _industry = '';
  int _page = 1;
  bool _english = false;
  List<String> _roles = [], _industries = [];
  late final _premiumService=PremiumService();
  late Future<Map<String, dynamic>> _data = _fetch();
  Future<Map<String, dynamic>> _fetch() => _premiumService.interviews({
    'search': _search.text.trim(), 'role': _role, 'industry': _industry, 'page': '$_page'
  });
  void _load({int page = 1}) => setState(() { _page = page; _data = _fetch(); });
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ইন্টারভিউ প্রস্তুতি'), actions: [
      IconButton(tooltip: 'রিফ্রেশ', onPressed: () => _load(), icon: const Icon(Icons.refresh))
    ]),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final data = waiting ? null : snapshot.data;
        if (data != null) {
          _roles = HomepageService.strings(data['roles']);
          _industries = HomepageService.strings(data['industries']);
        }
        final rows = data == null ? <Map<String,dynamic>>[] : HomepageService.rows(data['data']);
        return ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _search, textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(), maxLength: 120,
            decoration: InputDecoration(hintText: 'প্রশ্ন, পদ বা ইন্ডাস্ট্রি খুঁজুন', suffixIcon: IconButton(onPressed: () => _load(), icon: const Icon(Icons.search)))),
          DropdownButtonFormField<String>(initialValue: _roles.contains(_role) ? _role : '',
            isExpanded: true, decoration: const InputDecoration(labelText: 'পদ'),
            items: [const DropdownMenuItem(value: '', child: Text('সব পদ')), for(final v in _roles) DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))],
            onChanged: waiting ? null : (v) { _role=v??''; _load(); }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: _industries.contains(_industry) ? _industry : '',
            isExpanded: true, decoration: const InputDecoration(labelText: 'ইন্ডাস্ট্রি'),
            items: [const DropdownMenuItem(value: '', child: Text('সব ইন্ডাস্ট্রি')), for(final v in _industries) DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))],
            onChanged: waiting ? null : (v) { _industry=v??''; _load(); }),
          SwitchListTile(title: const Text('English answer (যদি থাকে)'), value: _english, onChanged: (v)=>setState(()=>_english=v)),
          if (waiting) const FsLoadingCards(count: 2)
          else if (snapshot.hasError || data == null) const Text('ইন্টারভিউ প্রশ্ন লোড হয়নি। রিফ্রেশ করুন।')
          else if (rows.isEmpty) const Text('এই বিভাগে প্রকাশিত প্রশ্ন পাওয়া যায়নি।')
          else ...[
            for (final row in rows)
              if(row['locked']==true)
                Card(child:ListTile(leading:const Icon(Icons.lock_outline),title:Text(_english&&HomepageService.text(row,'title_en').isNotEmpty?HomepageService.text(row,'title_en'):HomepageService.text(row,'title')),
                  subtitle:const Text('Premium উত্তর • সদস্যপদ দেখুন'),trailing:const Icon(Icons.workspace_premium_outlined),onTap:() async {
                    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const PremiumPage()));
                    if(mounted)_load(page:_page);
                  }))
              else Card(child: ExpansionTile(
                key: ValueKey('${row['id']}-$_english'),
                title: Text(_english && HomepageService.text(row,'title_en').isNotEmpty ? HomepageService.text(row,'title_en') : HomepageService.text(row,'title')),
                subtitle: Text([row['role_name'],row['industry'],row['difficulty']].where((v)=>v!=null&&v.toString().isNotEmpty).join(' • ')),
                childrenPadding: const EdgeInsets.all(16),
                children: [Align(alignment: Alignment.centerLeft,child: SelectableText(_english && HomepageService.text(row,'body_en').isNotEmpty ? HomepageService.text(row,'body_en') : HomepageService.text(row,'body')))],
              )),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,children:[
              TextButton(onPressed: _page>1 ? ()=>_load(page:_page-1):null,child:const Text('আগের পেজ')),
              Text('$_page'),
              TextButton(onPressed: data['has_more']==true ? ()=>_load(page:_page+1):null,child:const Text('পরের পেজ')),
            ]),
          ],
        ]);
      },
    ),
  );
}
