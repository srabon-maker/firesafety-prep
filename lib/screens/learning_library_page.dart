import 'package:flutter/material.dart';
import '../services/homepage_service.dart';
import 'tests_page.dart';

class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key, this.initialSearch = ''});
  final String initialSearch;
  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  late final TextEditingController _search = TextEditingController(text: widget.initialSearch);
  late Future<Map<String, dynamic>> _data = HomepageService.fetch('question_categories');
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('প্রশ্ন ব্যাংক'), actions: [
      IconButton(onPressed: () => setState(() => _data = HomepageService.fetch('question_categories')), icon: const Icon(Icons.refresh)),
    ]),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('প্রশ্নের বিভাগ লোড হয়নি। রিফ্রেশ করুন।'));
        final rows = HomepageService.rows(snapshot.data!['data']);
        final query = _search.text.trim().toLowerCase();
        final filtered = rows.where((row) => HomepageService.text(row, 'category').toLowerCase().contains(query));
        return ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'প্রশ্নের বিভাগ খুঁজুন')),
          const SizedBox(height: 12),
          const Text('বিষয় নির্বাচন করে প্রকাশিত MCQ অনুশীলন করুন।'),
          for (final row in filtered)
            Card(child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text(HomepageService.text(row, 'category')),
              subtitle: Text('${row['question_count']}টি প্রকাশিত প্রশ্ন'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SubjectPracticePage(subject: HomepageService.text(row, 'category')))),
            )),
          if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('কোনো বিভাগ পাওয়া যায়নি।')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PracticeDashboardPage())), icon: const Icon(Icons.insights), label: const Text('আমার প্রস্তুতি')),
        ]);
      },
    ),
  );
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
  late Future<Map<String, dynamic>> _data = _fetch();
  Future<Map<String, dynamic>> _fetch() => HomepageService.fetch('interviews', filters: {
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
          if (waiting) const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError || data == null) const Text('ইন্টারভিউ প্রশ্ন লোড হয়নি। রিফ্রেশ করুন।')
          else if (rows.isEmpty) const Text('এই বিভাগে প্রকাশিত প্রশ্ন পাওয়া যায়নি।')
          else ...[
            for (final row in rows)
              Card(child: ExpansionTile(
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
