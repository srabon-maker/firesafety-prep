import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import '../models/category_labels.dart';
import '../services/auth_guard.dart';
import '../services/model_test_service.dart';
import 'premium_page.dart';

const Color _maroon = Color(0xFF650D18);
const Color _deepMaroon = Color(0xFF36060D);

class TestsPage extends StatefulWidget {
  const TestsPage({super.key, this.loadTests, this.loadActiveAttempts});
  final Future<List<Map<String, dynamic>>> Function()? loadTests;
  final Future<List<Map<String, dynamic>>> Function()? loadActiveAttempts;
  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  late Future<List<Map<String,dynamic>>> _tests;
  String? _categoryFilter;
  String _tr(String bn, String en) => Localizations.localeOf(context).languageCode == 'en' ? en : bn;
  Future<List<Map<String, dynamic>>> _fetchTests() =>
      widget.loadTests?.call() ?? ModelTestService.instance.listTests();
  String _categoryKey(Map<String,dynamic> test) => test['category_id']?.toString() ?? 'mixed';
  String _categoryLabel(Map<String,dynamic> test) {
    final language = Localizations.localeOf(context).languageCode;
    final name = categoryDisplayFromRow(test,'category_name',language).trim();
    return name.isNotEmpty ? name : (language == 'en' ? 'Mixed / Other' : 'সমন্বিত / অন্যান্য');
  }
  Map<int, Map<String, dynamic>> _activeAttempts = {};
  bool _loadingActiveAttempts = false;
  final Set<int> _startingTestIds = <int>{};
  @override
  void initState(){
    super.initState();
    _tests=_fetchTests();
    _loadActiveAttempts();
  }
  Future<void> _loadActiveAttempts() async {
    if (_loadingActiveAttempts) return;
    _loadingActiveAttempts = true;
    try {
      final rows = await (widget.loadActiveAttempts?.call() ?? ModelTestService.instance.activeAttempts());
      if (!mounted) return;
      setState(() {
        _activeAttempts = {
          for (final row in rows) (row['test_id'] as num).toInt(): row,
        };
      });
    } catch (_) {
      // A signed-out student can still browse published tests.
      if (mounted) setState(() => _activeAttempts = {});
    } finally {
      _loadingActiveAttempts = false;
    }
  }
  Future<void> _refresh() async {
    final next = _fetchTests();
    setState(() => _tests = next);
    try {
      await Future.wait([next, _loadActiveAttempts()]);
    } catch (_) {
      // FutureBuilder displays the load error and retry action.
    }
  }
  Future<void> _start(Map<String,dynamic> test) async {
    final testId = (test['id'] as num).toInt();
    if (_startingTestIds.contains(testId)) return;
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    if(test['locked']==true&&!_activeAttempts.containsKey(testId)){
      await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const PremiumPage()));
      if(mounted)await _refresh();
      return;
    }
    setState(() => _startingTestIds.add(testId));
    try {
      final attempt = await ModelTestService.instance.start(testId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ExamRunner(attempt: attempt)),
      );
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF8B1726),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _startingTestIds.remove(testId));
    }
  }
  Widget _headerAction(IconData icon, String label, VoidCallback onTap) =>
      Tooltip(message: label, child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 48, height: 48,
            child: Center(child: Container(width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: Colors.white),
            )),
          ),
        ),
      ));

  Future<void> _openProtected(Widget page) async {
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _meta(IconData icon, String label) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 17, color: theme.colorScheme.primary),
      const SizedBox(width: 5),
      Flexible(child: Text(label, style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant))),
    ]);
  }

  Widget _testCard(Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final testId = (t['id'] as num).toInt();
    final starting = _startingTestIds.contains(testId);
    final active = _activeAttempts.containsKey(testId);
    final locked = t['locked'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(locked && !active ? Icons.lock_outline : Icons.assignment_outlined,
                color: scheme.primary, size: 24)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['title']?.toString() ?? _tr('মডেল টেস্ট', 'Model test'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(_categoryLabel(t), style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant)),
            ])),
          ]),
          if ((t['description'] ?? '').toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(t['description'].toString())),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 6, children: [
            if (locked) _meta(Icons.lock_outline, 'Premium'),
            _meta(Icons.help_outline, _tr('${t['question_count']} প্রশ্ন', '${t['question_count']} questions')),
            _meta(Icons.timer_outlined, _tr('${t['duration_minutes']} মিনিট', '${t['duration_minutes']} min')),
            _meta(Icons.grade_outlined, _tr('${t['total_marks']} নম্বর', '${t['total_marks']} marks')),
            if (t['pass_marks'] != null) _meta(Icons.flag_outlined, _tr('পাস ${t['pass_marks']}', 'Pass ${t['pass_marks']}')),
            if (((t['negative_marks_per_question'] as num?)?.toDouble() ?? 0) > 0)
              _meta(Icons.remove_circle_outline, _tr('ভুলে -${t['negative_marks_per_question']}', 'Wrong -${t['negative_marks_per_question']}')),
            if (t['randomize_questions'] == true) _meta(Icons.shuffle, _tr('প্রশ্নের ক্রম এলোমেলো', 'Randomized questions')),
            if (((t['max_attempts'] as num?)?.toInt() ?? 0) > 0)
              _meta(Icons.replay, _tr('সর্বোচ্চ ${t['max_attempts']} বার', 'Max ${t['max_attempts']} attempts')),
          ]),
          if ((t['exam_instructions'] ?? '').toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(
              _tr('নির্দেশনা: ${t['exam_instructions']}', 'Instructions: ${t['exam_instructions']}'),
              maxLines: 3, overflow: TextOverflow.ellipsis)),
          Divider(height: 18, color: scheme.outlineVariant),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: starting ? null : () => _start(t),
            icon: starting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(active ? Icons.play_circle_outline : locked ? Icons.lock_outline : Icons.play_arrow, size: 20),
            label: Text(starting ? _tr('প্রস্তুত হচ্ছে…', 'Preparing…')
              : active ? _tr('পরীক্ষা চালিয়ে যান', 'Resume test')
              : locked ? _tr('Premium দেখুন', 'View Premium')
              : _tr('পরীক্ষা শুরু করুন', 'Start test')),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _unfinished(List<Map<String, dynamic>> tests) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.pending_actions, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_tr('অসমাপ্ত পরীক্ষা', 'Unfinished tests'),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 4),
          for (final entry in _activeAttempts.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value['title']?.toString() ?? _tr('মডেল টেস্ট', 'Model test')),
              subtitle: Text(_tr(
                'বাকি সময়: ${((entry.value['remaining_seconds'] as num?)?.toInt() ?? 0) ~/ 60} মিনিট',
                'Time left: ${((entry.value['remaining_seconds'] as num?)?.toInt() ?? 0) ~/ 60} min'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              trailing: Icon(Icons.play_circle_outline, color: scheme.primary),
              onTap: () {
                final test = tests.firstWhere(
                  (t) => (t['id'] as num).toInt() == entry.key,
                  orElse: () => <String, dynamic>{},
                );
                if (test.isNotEmpty) _start(test);
              },
            ),
        ]),
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
        leadingWidth: 48,
        centerTitle: false,
        backgroundColor: _deepMaroon,
        foregroundColor: Colors.white,
        title: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 140;
          return Row(children: [
            if (!compact) ...[
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: .24))),
                child: const Icon(Icons.assignment_outlined, size: 29, color: Colors.white)),
              const SizedBox(width: 9),
              Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
              const SizedBox(width: 9),
            ],
            Expanded(child: Text(_tr('মডেল টেস্ট', 'Model Tests'),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15.5,
                fontWeight: FontWeight.w500, height: 1.2))),
          ]);
        }),
        actions: [
          _headerAction(Icons.history_rounded, _tr('আমার ফলাফল', 'My results'),
            () => _openProtected(const MyTestResultsPage())),
          _headerAction(Icons.insights_rounded, _tr('প্র্যাকটিস ড্যাশবোর্ড', 'Practice dashboard'),
            () => _openProtected(const PracticeDashboardPage())),
          _headerAction(Icons.refresh_rounded, _tr('রিফ্রেশ', 'Refresh'), _refresh),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _tests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const FsLoadingCards(count: 3);
            if (snapshot.hasError) return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              children: [FsStatusCard(icon: Icons.error_outline,
                message: _tr('পরীক্ষার তালিকা লোড হয়নি।', 'Could not load tests.'),
                onRetry: _refresh)],
            );
            final tests = snapshot.data ?? [];
            final categories = <String, String>{
              for (final test in tests) _categoryKey(test): _categoryLabel(test),
            };
            final selected = categories.containsKey(_categoryFilter) ? _categoryFilter : null;
            final visibleTests = selected == null ? tests : tests.where((test) => _categoryKey(test) == selected).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
              children: [
                if (_activeAttempts.isNotEmpty && tests.isNotEmpty) _unfinished(tests),
                Row(children: [
                  Icon(Icons.grid_view_rounded, color: scheme.primary, size: 20),
                  const SizedBox(width: 7),
                  Expanded(child: Text(_tr('ক্যাটাগরি', 'Categories'), style: theme.textTheme.titleMedium)),
                  Flexible(child: Text(_tr('${visibleTests.length}টি পরীক্ষা', '${visibleTests.length} tests'),
                    textAlign: TextAlign.end, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
                ]),
                const SizedBox(height: 6),
                if (tests.isEmpty)
                  FsStatusCard(icon: Icons.assignment_outlined,
                    message: _tr('এখন কোনো প্রকাশিত পরীক্ষা নেই।', 'No tests published yet.'))
                else ...[
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    ChoiceChip(label: Text(_tr('সব (${tests.length})', 'All (${tests.length})')),
                      selected: selected == null,
                      onSelected: (_) => setState(() => _categoryFilter = null)),
                    for (final entry in categories.entries)
                      ChoiceChip(label: Text(entry.value), selected: selected == entry.key,
                        onSelected: (value) => setState(() => _categoryFilter = value ? entry.key : null)),
                  ]),
                  const SizedBox(height: 10),
                  for (final t in visibleTests) _testCard(t),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExamRunner extends StatefulWidget {
  final Map<String,dynamic> attempt;
  const _ExamRunner({required this.attempt});
  @override
  State<_ExamRunner> createState()=>_ExamRunnerState();
}
class _ExamRunnerState extends State<_ExamRunner> with WidgetsBindingObserver {
  late final List<Map<String,dynamic>> _questions;
  late final int _attemptId,_testId;
  late int _remaining,_index=0;
  late DateTime _expiresAt;
  Timer? _timer;
  bool _cacheReady = false;
  bool _networkUnavailable = false;
  String get _answerCacheKey => 'model_test_answers_$_attemptId';
  bool _submitting=false;
  String? _saveError;
  Future<void> _saveQueue=Future<void>.value();
  final Map<int,String> _answers={};
  @override
  void initState(){
    super.initState();
    _attemptId=(widget.attempt['attempt_id'] as num).toInt();
    _testId=(widget.attempt['test_id'] as num).toInt();
    _questions=(widget.attempt['questions'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    for(final q in _questions){final a=q['selected_answer'];if(a!=null)_answers[(q['id'] as num).toInt()]=a.toString();}
    final expiresRaw = widget.attempt['expires_at']?.toString();
    _expiresAt = expiresRaw != null
        ? DateTime.tryParse(expiresRaw.replaceFirst(' ', 'T'))?.toLocal() ??
            DateTime.now().add(Duration(seconds: (widget.attempt['remaining_seconds'] as num?)?.toInt() ?? 0))
        : DateTime.now().add(Duration(seconds: (widget.attempt['remaining_seconds'] as num?)?.toInt() ?? 0));
    _remaining = _expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 86400);
    WidgetsBinding.instance.addObserver(this);
    _restoreLocalAnswers();
    _startClock();
  }
  @override
  void dispose(){_timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}

  Future<void> _restoreLocalAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_answerCacheKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final id = int.tryParse(entry.key.toString());
            final answer = entry.value.toString().toUpperCase();
            if (id != null && ['A','B','C','D'].contains(answer) &&
                _questions.any((q) => (q['id'] as num).toInt() == id)) {
              _answers.putIfAbsent(id, () => answer);
            }
          }
        }
      }
    } catch (_) {
      // A corrupt local cache must never prevent the student from taking the test.
    }
    _cacheReady = true;
    if (mounted) setState(() {});
  }

  Future<void> _persistLocalAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_answerCacheKey, jsonEncode(
      _answers.map((key, value) => MapEntry(key.toString(), value)),
    ));
  }

  Future<void> _clearLocalAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_answerCacheKey);
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _submitting) return;
      final seconds = _expiresAt.difference(DateTime.now()).inSeconds;
      if (seconds <= 0) {
        setState(() => _remaining = 0);
        _finish(auto: true);
      } else {
        setState(() => _remaining = seconds);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_submitting) {
      final seconds = _expiresAt.difference(DateTime.now()).inSeconds;
      setState(() => _remaining = seconds.clamp(0, 86400));
      if (seconds <= 0) _finish(auto: true);
    }
  }
  String get _clock=>'${(_remaining~/60).toString().padLeft(2,'0')}:${(_remaining%60).toString().padLeft(2,'0')}';
  Future<void> _choose(String answer) async {
    final q=_questions[_index];final id=(q['id'] as num).toInt();
    setState(()=>_answers[id]=answer);
    try {
      await _persistLocalAnswers();
    } catch (_) {
      if (mounted) setState(() => _saveError = 'এই ডিভাইসে উত্তর সংরক্ষণ করা যায়নি। ইন্টারনেট চালু রেখে পরীক্ষা চালিয়ে যান।');
    }
    final pending=_saveQueue.catchError((_){}).then((_)=>ModelTestService.instance.saveAnswer(attemptId:_attemptId,testId:_testId,questionId:id,answer:answer));
    _saveQueue=pending;
    try {
      await pending;
      if (mounted) setState(() {_saveError=null;_networkUnavailable=false;});
    } catch (_) {
      if (mounted) setState(() {
        _networkUnavailable = true;
        _saveError = 'ইন্টারনেট সংযোগ নেই বা উত্তর সার্ভারে পৌঁছায়নি। উত্তর এই ডিভাইসে রাখা হয়েছে; সংযোগ ফিরলে আবার সংরক্ষণ করুন।';
      });
    }
  }
  Future<void> _finish({bool auto=false}) async {
    if(_submitting)return;
    if(!auto){
      final unanswered = _questions.length - _answers.length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('পরীক্ষা জমা দেওয়ার আগে'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('উত্তর দিয়েছেন: ${_answers.length}টি'),
              Text('উত্তর বাকি: $unansweredটি'),
              const SizedBox(height: 10),
              Text(
                unanswered > 0
                    ? 'কিছু প্রশ্নের উত্তর দেওয়া হয়নি। তারপরও কি জমা দিতে চান?'
                    : 'সব প্রশ্নের উত্তর দেওয়া হয়েছে। জমা দেওয়ার পর আর পরিবর্তন করা যাবে না।',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ফিরে যান'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('জমা দিন'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(()=>_submitting=true);_timer?.cancel();
    try{
      await _saveQueue.catchError((_) {});
      // Flush the locally cached answers before submitting while the server
      // deadline is still open. If the deadline passed offline, the server
      // remains authoritative and accepts only answers saved before expiry.
      if (_expiresAt.isAfter(DateTime.now())) {
        for (final entry in _answers.entries) {
          await ModelTestService.instance.saveAnswer(
            attemptId: _attemptId, testId: _testId,
            questionId: entry.key, answer: entry.value,
          );
        }
      }
      final response=await ModelTestService.instance.submit(attemptId:_attemptId,testId:_testId);
      await _clearLocalAnswers();
      if(!mounted)return;
      if(response['result_released']==true && response['result'] is Map){
        await Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>_ExamResult(result:Map<String,dynamic>.from(response['result'] as Map))));
      }else{
        await Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const _ResultPending()));
      }
    }catch(e){if(mounted){setState(()=>_submitting=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('জমা দেওয়া যায়নি। ইন্টারনেট সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।')));if(auto){setState(()=>_networkUnavailable=true);}else{_startClock();}}}
  }
  @override
  Widget build(BuildContext context){
    if(_questions.isEmpty)return const Scaffold(body:Center(child:Text('এই পরীক্ষায় প্রশ্ন পাওয়া যায়নি।')));
    final q=_questions[_index];final options=Map<String,dynamic>.from(q['options'] as Map);
    return PopScope(canPop:false,onPopInvokedWithResult:(didPop,result){if(!didPop)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('পরীক্ষা জমা দিতে Submit বাটন ব্যবহার করুন।')));},child:Scaffold(
      appBar:AppBar(title:Text(widget.attempt['title']?.toString()??'পরীক্ষা'),automaticallyImplyLeading:false,actions:[Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Center(child:Text(_clock,style:TextStyle(fontWeight:FontWeight.bold,color:_remaining<60?Colors.red:null))))]),
      body:Column(children:[
        LinearProgressIndicator(value:(_index+1)/_questions.length),
        if((widget.attempt['instructions']??'').toString().isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF0D7D3)),
            ),
            child: Text(widget.attempt['instructions'].toString()),
          ),
        if(((widget.attempt['negative_marks_per_question'] as num?)?.toDouble() ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'প্রতি ভুল উত্তরে ${widget.attempt['negative_marks_per_question']} নম্বর কাটা হবে।',
              style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600),
            ),
          ),
        Padding(padding:const EdgeInsets.all(16),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('প্রশ্ন ${_index+1}/${_questions.length}',style:const TextStyle(fontWeight:FontWeight.bold)),Text('উত্তর: ${_answers.length}/${_questions.length}') ])),
        Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
          Text(q['question']?.toString()??'',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:18),
          for(final letter in ['A','B','C','D'])Card(color: _answers[(q['id'] as num).toInt()] == letter ? Theme.of(context).colorScheme.primaryContainer : null, child:RadioListTile<String>(value:letter,groupValue:_answers[(q['id'] as num).toInt()],title:Text('$letter. ${options[letter]??''}'),onChanged:_submitting?null:(v)=>v==null?null:_choose(v))),
          if(!_cacheReady)
            const Padding(padding:EdgeInsets.all(8),child:LinearProgressIndicator()),
          if(_saveError!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_saveError!,style:const TextStyle(color:Colors.red))),
          if(_networkUnavailable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting ? null : () async {
                  if (_remaining <= 0) {
                    await _finish(auto: true);
                    return;
                  }
                  try {
                    for (final entry in _answers.entries) {
                      await ModelTestService.instance.saveAnswer(
                        attemptId: _attemptId, testId: _testId,
                        questionId: entry.key, answer: entry.value,
                      );
                    }
                    if (mounted) setState(() {_networkUnavailable=false;_saveError=null;});
                  } catch (_) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('সংরক্ষণ হয়নি। ইন্টারনেট সংযোগ পরীক্ষা করুন।')),
                    );
                  }
                },
                icon: Icon(_remaining <= 0 ? Icons.send : Icons.sync),
                label: Text(_remaining <= 0
                    ? 'পরীক্ষা জমা দেওয়ার চেষ্টা করুন'
                    : 'উত্তর আবার সংরক্ষণ করুন'),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('প্রশ্ন তালিকা', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('উত্তর বাকি: ${_questions.length - _answers.length}টি',
                style: TextStyle(
                  color: _questions.length == _answers.length ? Colors.green : Colors.deepOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_questions.length, (i) {
              final questionId = (_questions[i]['id'] as num).toInt();
              final answered = _answers.containsKey(questionId);
              final current = i == _index;
              return Tooltip(
                message: 'প্রশ্ন ${i + 1}: ${answered ? 'উত্তর দেওয়া হয়েছে' : 'উত্তর দেওয়া হয়নি'}',
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => setState(() => _index = i),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: current
                        ? _maroon
                        : answered ? Colors.green.shade50 : Colors.white,
                    foregroundColor: current
                        ? Colors.white
                        : answered ? Colors.green.shade800 : Colors.black87,
                    side: BorderSide(
                      color: current ? _maroon : answered ? Colors.green : Colors.grey.shade400,
                    ),
                    minimumSize: const Size(42, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text('${i + 1}'),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _QuestionLegend(color: Colors.green, label: 'উত্তর দেওয়া'),
              _QuestionLegend(color: Colors.grey, label: 'উত্তর বাকি'),
              _QuestionLegend(color: _maroon, label: 'বর্তমান'),
            ],
          )
        ])),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _index > 0 ? () => setState(() => _index--) : null,
                      child: const Text('আগেরটি'),
                    ),
                    const Spacer(),
                    if (_index < _questions.length - 1)
                      FilledButton(
                        onPressed: () => setState(() => _index++),
                        child: const Text('পরেরটি'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : () => _finish(),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(_submitting ? 'জমা হচ্ছে...' : 'পরীক্ষা জমা দিন'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      ])
    ));
  }
}

class _QuestionLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _QuestionLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _ExamResult extends StatelessWidget{
  final Map<String,dynamic> result;
  const _ExamResult({required this.result});
  @override
  Widget build(BuildContext context){
    final score=(result['score'] as num?)?.toDouble()??0;
    final total=(result['total_marks'] as num?)?.toDouble()??0;
    final questions=(result['questions'] as List? ??[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    return Scaffold(appBar:AppBar(title:const Text('পরীক্ষার ফলাফল'),automaticallyImplyLeading:false),body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[
        Text('${score.toStringAsFixed(2)} / ${total.toStringAsFixed(2)}',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold,color:_maroon)),
        Text(total>0?'${(score/total*100).clamp(0,100).toStringAsFixed(1)}%':'—'),
        const SizedBox(height:12),Wrap(alignment:WrapAlignment.center,spacing:14,children:[
          Text('সঠিক: ${result['correct_count']}'),Text('ভুল: ${result['incorrect_count']}'),Text('উত্তর নেই: ${result['unanswered_count']}')
        ]),
        const SizedBox(height:8),Text(result['passed']==null?'পাস নম্বর নির্ধারিত ছিল না.':(result['passed']==true?'অভিনন্দন! আপনি পাস করেছেন।':'আপনি পাস করতে পারেননি।'),style:const TextStyle(fontWeight:FontWeight.bold))
      ]))),
      const SizedBox(height:12),
      if (questions.any((q) =>
          q['selected_answer'] != null &&
          q['selected_answer'].toString().toUpperCase() != q['correct_answer'].toString().toUpperCase()))
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _WrongAnswerPracticePage(questions: questions),
            )),
            icon: const Icon(Icons.psychology_alt_outlined),
            label: const Text('ভুল প্রশ্নগুলো আবার অনুশীলন করুন'),
            style: FilledButton.styleFrom(backgroundColor: _maroon),
          ),
        ),
      if ((result['subject_performance'] as List? ?? []).isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text('বিষয়ভিত্তিক পারফরম্যান্স',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final item in (result['subject_performance'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['subject']?.toString() ?? 'অন্যান্য',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text('সঠিক ${item['correct_count']}')),
                    Expanded(child: Text('ভুল ${item['incorrect_count']}')),
                    Expanded(child: Text('ফাঁকা ${item['unanswered_count']}')),
                    Text('${((item['accuracy'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _maroon)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (((item['accuracy'] as num?)?.toDouble() ?? 0) / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      color: _maroon,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('স্কোর: ${((item['score'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} / ${((item['total_marks'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final subject = item['subject']?.toString() ?? 'অন্যান্য';
                        final subjectQuestions = questions.where((q) =>
                          (q['category']?.toString().trim().isNotEmpty == true
                              ? q['category'].toString().trim() : 'অন্যান্য') == subject
                        ).toList();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SubjectPracticePage(
                            subject: subject,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('এই বিষয়ে অনুশীলন'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      const SizedBox(height:12),const Text('প্রশ্নভিত্তিক পর্যালোচনা',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      for(final q in questions)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('বিষয়: ${q['category'] ?? 'অন্যান্য'}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text('${q['order']}. ${q['question']}',style:const TextStyle(fontWeight:FontWeight.bold)),
        for(final letter in ['A','B','C','D'])Padding(padding:const EdgeInsets.only(top:4),child:Text('$letter. ${(q['options'] as Map)[letter]}')),
        const SizedBox(height:6),Text('তোমার উত্তর: ${q['selected_answer']??'উত্তর দাওনি'}'),Text('সঠিক উত্তর: ${q['correct_answer']}',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.bold)),
        if((q['explanation']??'').toString().isNotEmpty)Text('ব্যাখ্যা: ${q['explanation']}')
      ]))),
      const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.popUntil(context,(r)=>r.isFirst),child:const Text('পরীক্ষার তালিকায় ফিরুন'))
    ]));
  }
}


class SubjectPracticePage extends StatefulWidget {
  final String subject;
  final String? subjectLabel;
  const SubjectPracticePage({super.key, required this.subject,this.subjectLabel});

  @override
  State<SubjectPracticePage> createState() => _SubjectPracticePageState();
}

class _SubjectPracticePageState extends State<SubjectPracticePage> {
  List<Map<String, dynamic>> _questions = [];
  String _difficulty = 'all';
  bool _loading = true;
  String? _loadError;
  int _index = 0;
  String? _selected;
  bool _checked = false;
  int _correct = 0;
  final Set<int> _answered = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {_loading = true; _loadError = null;});
    try {
      final rows = await ModelTestService.instance.practiceQuestions(
        category: widget.subject,
        difficulty: _difficulty,
        limit: 15,
      );
      if (!mounted) return;
      setState(() {
        _questions = rows;
        _index = 0;
        _selected = null;
        _checked = false;
        _correct = 0;
        _answered.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {_loadError = e.toString().replaceFirst('Exception: ', ''); _loading = false;});
    }
  }

  void _checkAnswer(String correct) {
    if (_selected == null || _checked) return;
    setState(() {
      _checked = true;
      _answered.add(_index);
      if (_selected == correct) _correct++;
    });
  }

  Future<void> _completePractice() async {
    try {
      await ModelTestService.instance.savePracticeSession(
        category: widget.subject,
        difficulty: _difficulty,
        totalQuestions: _questions.length,
        correctCount: _correct,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('প্র্যাকটিসের ফলাফল সংরক্ষণ হয়নি: ${e.toString().replaceFirst('Exception: ', '')}'),
        ));
      }
      return;
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('অনুশীলন সম্পন্ন'),
        content: Text('${_questions.length}টি প্রশ্নের মধ্যে $_correctটি সঠিক উত্তর দিয়েছেন।'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('শেষ করুন'),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (_index >= _questions.length - 1) return;
    setState(() {
      _index++;
      _selected = null;
      _checked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.subjectLabel ?? widget.subject} অনুশীলন')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.subjectLabel ?? widget.subject} অনুশীলন')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadQuestions, child: const Text('আবার চেষ্টা করুন')),
          ]),
        )),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.subjectLabel ?? widget.subject} অনুশীলন')),
        body: const Center(child: Text('এই বিষয়ে Question Bank-এ প্রকাশিত প্রশ্ন পাওয়া যায়নি।')),
      );
    }
    final q = _questions[_index];
    final options = Map<String, dynamic>.from(q['options'] as Map? ?? {});
    final correct = q['correct_answer']?.toString().toUpperCase() ?? '';
    final explanation = q['explanation']?.toString() ?? '';
    final isLast = _index == _questions.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.subjectLabel ?? widget.subject} অনুশীলন')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LinearProgressIndicator(value: (_index + 1) / _questions.length),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _difficulty,
            decoration: const InputDecoration(labelText: 'প্রশ্নের কঠিনতার মাত্রা'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('সব স্তর')),
              DropdownMenuItem(value: 'easy', child: Text('সহজ')),
              DropdownMenuItem(value: 'medium', child: Text('মাঝারি')),
              DropdownMenuItem(value: 'hard', child: Text('কঠিন')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _difficulty = value);
              _loadQuestions();
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('প্রশ্ন ${_index + 1} / ${_questions.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: _maroon))),
            Text('সঠিক: $_correct',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ]),
          const SizedBox(height: 16),
          Text(q['question']?.toString() ?? '',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          for (final letter in ['A', 'B', 'C', 'D'])
            Card(
              color: _checked && letter == correct
                  ? Colors.green.shade50
                  : _checked && letter == _selected && _selected != correct
                      ? Colors.red.shade50 : null,
              child: RadioListTile<String>(
                value: letter,
                groupValue: _selected,
                onChanged: _checked ? null : (value) => setState(() => _selected = value),
                title: Text('$letter. ${options[letter] ?? ''}'),
              ),
            ),
          if (!_checked)
            FilledButton(
              onPressed: _selected == null ? null : () => _checkAnswer(correct),
              style: FilledButton.styleFrom(backgroundColor: _maroon),
              child: const Text('উত্তর যাচাই করুন'),
            )
          else ...[
            Card(
              color: _selected == correct ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_selected == correct ? 'সঠিক উত্তর! ভালো করেছেন।' : 'সঠিক উত্তর: $correct',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selected == correct ? Colors.green.shade800 : Colors.deepOrange,
                    )),
                  if (explanation.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('ব্যাখ্যা: $explanation'),
                  ],
                ]),
              ),
            ),
            FilledButton.icon(
              onPressed: isLast ? _completePractice : _next,
              style: FilledButton.styleFrom(backgroundColor: _maroon),
              icon: Icon(isLast ? Icons.done : Icons.arrow_forward),
              label: Text(isLast ? 'ফলাফল দেখুন' : 'পরের প্রশ্ন'),
            ),
          ],
          const SizedBox(height: 8),
          Text('এটি অনুশীলন মোড; আপনার অফিসিয়াল পরীক্ষার ফলাফল পরিবর্তন হবে না।',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class PracticeDashboardPage extends StatefulWidget {
  const PracticeDashboardPage({super.key, this.loadDashboard});

  // Optional loader allows deterministic UI tests without a live account.
  final Future<Map<String, dynamic>> Function()? loadDashboard;

  @override
  State<PracticeDashboardPage> createState() => _PracticeDashboardPageState();
}

class _PracticeDashboardPageState extends State<PracticeDashboardPage> {
  late Future<Map<String, dynamic>> _data;
  bool _savingTarget = false;

  String _tr(String bn, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : bn;

  Future<Map<String, dynamic>> _load() =>
      widget.loadDashboard?.call() ??
      ModelTestService.instance.practiceDashboard();

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final next = _load();
    setState(() => _data = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder presents the retry state.
    }
  }

  Future<void> _chooseTarget(int current) async {
    if (_savingTarget) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _tr('দৈনিক অনুশীলনের লক্ষ্য', 'Daily practice goal'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final value in [5, 10, 15, 20, 30, 50])
              ListTile(
                title: Text(_tr('${value}টি প্রশ্ন', '$value questions')),
                trailing: value == current
                    ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, value),
              ),
          ]),
        ),
      ),
    );
    if (!mounted || selected == null || selected == current) return;
    setState(() => _savingTarget = true);
    try {
      await ModelTestService.instance.updatePracticeTarget(selected);
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _savingTarget = false);
    }
  }

  int _count(dynamic value) => ((value as num?)?.toInt() ?? 0)
      .clamp(0, 2147483647).toInt();

  Widget _heading(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 20, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: theme.textTheme.titleMedium)),
    ]);
  }

  Widget _panel(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );

  Widget _progress(double value, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: 7,
        color: color ?? scheme.primary,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _dashboardMetric(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 6),
          Text(value, textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 19, color: scheme.onSurface)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _metricGrid(int total, double accuracy, int streak) {
    return LayoutBuilder(builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
      final columns = constraints.maxWidth < 300 || largeText ? 1 : 3;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        SizedBox(width: width, child: _dashboardMetric(
          Icons.menu_book_outlined, _tr('মোট প্রশ্ন', 'Questions'), '$total')),
        SizedBox(width: width, child: _dashboardMetric(
          Icons.track_changes_rounded, _tr('সঠিকের হার', 'Accuracy'),
          '${accuracy.toStringAsFixed(1)}%')),
        SizedBox(width: width, child: _dashboardMetric(
          Icons.local_fire_department_outlined, _tr('ধারাবাহিকতা', 'Streak'),
          _tr('$streak দিন', '$streak days'))),
      ]);
    });
  }

  Widget _weeklyChart(List<Map<String, dynamic>> weekly) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxDaily = weekly.fold<int>(1, (max, row) {
      final count = _count(row['questions']);
      return count > max ? count : max;
    });
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(Icons.bar_chart_rounded, _tr('সাপ্তাহিক অগ্রগতি', 'Weekly progress')),
      const SizedBox(height: 14),
      if (weekly.isEmpty)
        Text(_tr('এখনো কোনো অনুশীলনের রেকর্ড নেই।', 'No practice recorded yet.'),
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
      else ...[
        LayoutBuilder(builder: (context, constraints) {
          // The API provides only recorded dates, not the server's current date.
          // Plot actual records rather than inventing dates or zero values.
          final width = (constraints.maxWidth / weekly.length).clamp(58.0, 104.0).toDouble();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final day in weekly)
                SizedBox(
                  width: width,
                  child: Semantics(
                    label: '${day['date'] ?? ''}: ${_count(day['questions'])}',
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${_count(day['questions'])}',
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurface)),
                      const SizedBox(height: 5),
                      Container(
                        height: 74,
                        width: 22,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6)),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 74 * _count(day['questions']) / maxDaily,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _shortDate(day['date']),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Text(_tr('গত ৭ দিনের রেকর্ড করা দিন', 'Recorded days in the last 7 days'),
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    ]));
  }

  String _shortDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return raw?.toString() ?? '—';
    return MaterialLocalizations.of(context).formatShortDate(date);
  }

  Widget _subjectCard(List<Map<String, dynamic>> subjects) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(Icons.auto_stories_outlined, _tr('বিষয়ভিত্তিক দক্ষতা', 'Subject performance')),
      const SizedBox(height: 8),
      if (subjects.isEmpty)
        Text(_tr('বিষয়ভিত্তিক ফলাফলের জন্য অনুশীলন করুন।',
          'Complete practice to see subject results.'),
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      for (var index = 0; index < subjects.length; index++) ...[
        if (index > 0) const Divider(height: 20),
        Builder(builder: (context) {
          final subject = subjects[index];
          final accuracy = ((subject['accuracy'] as num?)?.toDouble() ?? 0)
              .clamp(0.0, 100.0).toDouble();
          final category = categoryDisplayFromRow(
            subject, 'category', Localizations.localeOf(context).languageCode);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(category.isEmpty ? _tr('অন্যান্য', 'Other') : category,
                style: theme.textTheme.titleSmall)),
              const SizedBox(width: 8),
              Text('${accuracy.toStringAsFixed(0)}%',
                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
            ]),
            const SizedBox(height: 7),
            _progress(accuracy / 100),
            const SizedBox(height: 6),
            Text(_tr('${_count(subject['questions'])} প্রশ্ন · ${_count(subject['sessions'])} সেশন',
              '${_count(subject['questions'])} questions · ${_count(subject['sessions'])} sessions'),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]);
        }),
      ],
    ]));
  }

  Widget _achievement(String label, bool unlocked, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = unlocked
        ? (dark ? const Color(0xFFA5E8B6) : const Color(0xFF185B31))
        : scheme.onSurfaceVariant;
    final background = unlocked
        ? (dark ? const Color(0xFF193A2A) : const Color(0xFFE3F4E8))
        : scheme.surfaceContainerHighest;
    return Semantics(
      label: '$label, ${unlocked ? _tr('অর্জিত', 'Unlocked') : _tr('অনর্জিত', 'Locked')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: unlocked ? foreground.withValues(alpha: .35) : scheme.outlineVariant),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: foreground),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground)),
          const SizedBox(height: 5),
          Icon(unlocked ? Icons.check_circle_outline : Icons.lock_outline,
            size: 15, color: foreground),
        ]),
      ),
    );
  }

  Widget _achievements(int total, int streak, bool goalReached) {
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(Icons.emoji_events_outlined, _tr('আপনার অর্জন', 'Achievements')),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
        final columns = constraints.maxWidth < 240 || largeText ? 2 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(width: width, child: _achievement(_tr('প্রথম পদক্ষেপ', 'First step'), total >= 1, Icons.flag_outlined)),
          SizedBox(width: width, child: _achievement(_tr('৫০ প্রশ্ন', '50 questions'), total >= 50, Icons.school_outlined)),
          SizedBox(width: width, child: _achievement(_tr('১০০ প্রশ্ন', '100 questions'), total >= 100, Icons.workspace_premium_outlined)),
          SizedBox(width: width, child: _achievement(_tr('৭ দিনের স্ট্রিক', '7-day streak'), streak >= 7, Icons.local_fire_department_outlined)),
          SizedBox(width: width, child: _achievement(_tr('লক্ষ্য পূরণ', 'Goal reached'), goalReached, Icons.task_alt)),
        ]);
      }),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canGoBack = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        backgroundColor: _deepMaroon,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leadingWidth: canGoBack ? 48 : 0,
        leading: canGoBack ? IconButton(
          tooltip: _tr('ফিরে যান', 'Back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        ) : null,
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
            ),
            child: const Icon(Icons.insights_rounded, size: 29, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_tr('প্র্যাকটিস ড্যাশবোর্ড', 'Practice Dashboard'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
        actions: [
          IconButton(tooltip: _tr('রিফ্রেশ', 'Refresh'), onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: FsStatusCard(icon: Icons.error_outline,
                message: _tr('প্র্যাকটিস রিপোর্ট লোড হয়নি।', 'Could not load practice report.'),
                onRetry: _refresh),
            ));
          }
          final data = snapshot.data ?? {};
          final today = Map<String, dynamic>.from(data['today'] as Map? ?? {});
          final overall = Map<String, dynamic>.from(data['overall'] as Map? ?? {});
          final rawTarget = (data['daily_target'] as num?)?.toInt() ?? 10;
          final target = rawTarget > 0 ? rawTarget : 10;
          final done = _count(today['questions']);
          final weekly = (data['weekly'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final weak = (data['weak_subjects'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final totalQuestions = _count(overall['questions']);
          final totalCorrect = _count(overall['correct']);
          final streak = _count(overall['streak']);
          final accuracy = totalQuestions == 0 ? 0.0 : totalCorrect / totalQuestions * 100;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
              children: [
                _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final heading = _heading(Icons.flag_outlined, _tr('আজকের লক্ষ্য', 'Today’s goal'));
                    final edit = TextButton.icon(
                      onPressed: _savingTarget ? null : () => _chooseTarget(target),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(_tr('পরিবর্তন', 'Edit')),
                    );
                    if (constraints.maxWidth < 230 ||
                        MediaQuery.textScalerOf(context).scale(14) > 19) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [heading, edit]);
                    }
                    return Row(children: [Expanded(child: heading), edit]);
                  }),
                  const SizedBox(height: 5),
                  Text(_tr('$done / $target প্রশ্ন', '$done / $target questions'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: scheme.primary)),
                  const SizedBox(height: 12),
                  _progress(done / target),
                  const SizedBox(height: 8),
                  Text(done >= target
                    ? _tr('আজকের লক্ষ্য পূরণ হয়েছে।', 'Today’s goal reached.')
                    : _tr('আর ${target - done}টি প্রশ্ন বাকি', '${target - done} questions left'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ])),
                const SizedBox(height: 8),
                _metricGrid(totalQuestions, accuracy, streak),
                const SizedBox(height: 8),
                _weeklyChart(weekly),
                _subjectCard(weak),
                _achievements(totalQuestions, streak, done >= target),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WrongAnswerPracticePage extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  const _WrongAnswerPracticePage({required this.questions});

  @override
  State<_WrongAnswerPracticePage> createState() => _WrongAnswerPracticePageState();
}

class _WrongAnswerPracticePageState extends State<_WrongAnswerPracticePage> {
  late final List<Map<String, dynamic>> _wrongQuestions;
  final Set<int> _revealed = {};
  int _index = 0;
  int _correctOnRetry = 0;

  @override
  void initState() {
    super.initState();
    _wrongQuestions = widget.questions.where((q) {
      final selected = q['selected_answer']?.toString().toUpperCase();
      final correct = q['correct_answer']?.toString().toUpperCase();
      return selected != null && selected.isNotEmpty && selected != correct;
    }).toList();
  }

  void _reveal() {
    if (_revealed.contains(_index)) return;
    final q = _wrongQuestions[_index];
    final selected = q['selected_answer']?.toString().toUpperCase();
    final correct = q['correct_answer']?.toString().toUpperCase();
    setState(() {
      _revealed.add(_index);
      if (selected == correct) _correctOnRetry++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_wrongQuestions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ভুল প্রশ্ন অনুশীলন')),
        body: const Center(child: Text('অনুশীলনের জন্য ভুল উত্তর পাওয়া যায়নি।')),
      );
    }
    final q = _wrongQuestions[_index];
    final options = Map<String, dynamic>.from(q['options'] as Map? ?? {});
    final revealed = _revealed.contains(_index);
    final correct = q['correct_answer']?.toString().toUpperCase() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('ভুল প্রশ্ন অনুশীলন')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LinearProgressIndicator(value: (_index + 1) / _wrongQuestions.length),
          const SizedBox(height: 12),
          Text('প্রশ্ন ${_index + 1} / ${_wrongQuestions.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _maroon)),
          const SizedBox(height: 12),
          Text(q['question']?.toString() ?? '',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final letter in ['A', 'B', 'C', 'D'])
            Card(
              color: revealed && letter == correct ? Colors.green.shade50 : null,
              child: ListTile(
                title: Text('$letter. ${options[letter] ?? ''}'),
                trailing: revealed && letter == correct
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            ),
          if (!revealed)
            FilledButton.icon(
              onPressed: _reveal,
              icon: const Icon(Icons.visibility),
              label: const Text('সঠিক উত্তর ও ব্যাখ্যা দেখুন'),
              style: FilledButton.styleFrom(backgroundColor: _maroon),
            )
          else ...[
            Card(
              color: const Color(0xFFEAF7EC),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('সঠিক উত্তর: $correct',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  if ((q['explanation'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('ব্যাখ্যা: ${q['explanation']}'),
                  ],
                  const SizedBox(height: 8),
                  Text('আগের উত্তর: ${q['selected_answer'] ?? 'উত্তর দেওয়া হয়নি'}'),
                ]),
              ),
            ),
            Row(children: [
              if (_index > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _index--),
                  child: const Text('আগের প্রশ্ন'),
                ),
              const Spacer(),
              if (_index < _wrongQuestions.length - 1)
                FilledButton(
                  onPressed: () => setState(() => _index++),
                  child: const Text('পরের প্রশ্ন'),
                )
              else
                FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('অনুশীলন সম্পন্ন'),
                      content: Text('${_wrongQuestions.length}টি ভুল প্রশ্ন পর্যালোচনা করেছেন।'),
                      actions: [TextButton(
                        onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                        child: const Text('শেষ করুন'),
                      )],
                    ),
                  ),
                  child: const Text('সম্পন্ন'),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _ResultPending extends StatelessWidget{
  const _ResultPending();
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('পরীক্ষা জমা হয়েছে'),automaticallyImplyLeading:false),
    body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.lock_clock,color:_maroon,size:64),
      const SizedBox(height:16),
      const Text('তোমার পরীক্ষা সফলভাবে জমা হয়েছে।',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold),textAlign:TextAlign.center),
      const SizedBox(height:8),
      const Text('Admin ফলাফল প্রকাশ করলে স্কোর ও সঠিক উত্তর দেখতে পারবে।',textAlign:TextAlign.center),
      const SizedBox(height:20),
      FilledButton(onPressed:()=>Navigator.popUntil(context,(r)=>r.isFirst),child:const Text('ফিরে যাও'))
    ])))
  );
}

class MyTestResultsPage extends StatefulWidget {
  const MyTestResultsPage({super.key, this.loadResults, this.loadDetail});
  final Future<List<Map<String, dynamic>>> Function()? loadResults;
  final Future<Map<String, dynamic>> Function(int)? loadDetail;

  @override
  State<MyTestResultsPage> createState() => _MyTestResultsPageState();
}

class _MyTestResultsPageState extends State<MyTestResultsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _opening = false;

  String _tr(String bn, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : bn;

  Future<List<Map<String, dynamic>>> _load() async =>
      widget.loadResults?.call() ?? ModelTestService.instance.myResults();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() { _future = next; });
    // FutureBuilder owns the error state; do not leak an unhandled retry error.
    await next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  double? _number(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  bool? _passed(dynamic value) {
    if (value == true || value == 1 || value == '1') return true;
    if (value == false || value == 0 || value == '0') return false;
    return null;
  }

  String _title(Map<String, dynamic> row) =>
      row['title']?.toString() ?? _tr('মডেল টেস্ট', 'Model test');

  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(color: Theme.of(context).colorScheme.primary,
        fontSize: 18, fontWeight: FontWeight.w800, height: 1.2)),
      const SizedBox(height: 2),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.2)),
    ],
  );

  Widget _heading(String title) => Text(title, style: Theme.of(context).textTheme.titleSmall
    ?.copyWith(fontWeight: FontWeight.w800, fontSize: 14, height: 1.25));

  Widget _caption(String title) => Text(title, style: Theme.of(context).textTheme.bodySmall
    ?.copyWith(fontSize: 11, height: 1.3, color: Theme.of(context).colorScheme.onSurfaceVariant));

  Widget _card(List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
  );

  Widget _metrics(List<Widget> items) => LayoutBuilder(builder: (context, constraints) {
    if (constraints.maxWidth < 240 || MediaQuery.textScalerOf(context).scale(14) > 20) {
      return Wrap(spacing: 16, runSpacing: 10, children: [
        for (final item in items) SizedBox(width: (constraints.maxWidth - 16) / 2, child: item),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final item in items) Expanded(child: item)]);
  });

  Widget _bar(double percentage) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(borderRadius: BorderRadius.circular(5),
      child: LinearProgressIndicator(value: (percentage / 100).clamp(0.0, 1.0),
        minHeight: 6, color: scheme.primary, backgroundColor: scheme.surfaceContainerHighest));
  }

  PreferredSizeWidget _header() => AppBar(
    toolbarHeight: 68, titleSpacing: 8, leadingWidth: 48, centerTitle: false,
    backgroundColor: _deepMaroon, foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0,
    title: LayoutBuilder(builder: (context, constraints) => Row(children: [
      if (constraints.maxWidth >= 145) ...[
        Container(width: 40, height: 40, decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .24))),
          child: const Icon(Icons.assignment_turned_in_outlined, size: 27, color: Colors.white)),
        const SizedBox(width: 9),
        Container(width: 1, height: 42, color: Colors.white54),
        const SizedBox(width: 9),
      ],
      Expanded(child: Text(_tr('আমার পরীক্ষার ফলাফল', 'My Exam Results'),
        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(
          color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w500, height: 1.2))),
    ])),
    actions: [
      IconButton(tooltip: _tr('রিফ্রেশ', 'Refresh'), onPressed: _refresh,
        icon: Container(width: 34, height: 34, decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white))),
      const SizedBox(width: 4),
    ],
  );

  Future<void> _openDetail(Map<String, dynamic> row) async {
    if (_opening) return;
    final id = int.tryParse(row['attempt_id']?.toString() ?? '');
    if (id == null || id < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        _tr('সঠিক ফলাফল নির্বাচন করা যায়নি।', 'Invalid result selection.'))));
      return;
    }
    setState(() { _opening = true; });
    try {
      final detail = await (widget.loadDetail?.call(id) ?? ModelTestService.instance.getResult(id));
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _ExamResult(result: detail)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        _tr('বিস্তারিত ফলাফল লোড হয়নি। আবার চেষ্টা করুন।', 'Could not load result details. Try again.'))));
    } finally {
      if (mounted) setState(() { _opening = false; });
    }
  }

  Widget _resultCard(Map<String, dynamic> row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final passed = _passed(row['passed']);
    final status = passed == null ? _tr('পাস নম্বর নির্ধারিত নয়', 'Pass mark not set')
        : passed ? _tr('পাস', 'Pass') : _tr('ফেল', 'Fail');
    final color = passed == null ? scheme.onSurfaceVariant : passed
        ? (theme.brightness == Brightness.dark ? const Color(0xFF8BD5AF) : const Color(0xFF207A50))
        : scheme.error;
    return _card([
      _heading(_title(row)),
      const SizedBox(height: 6),
      Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(_tr('স্কোর: ${row['score'] ?? '—'} / ${row['total_marks'] ?? '—'}',
          'Score: ${row['score'] ?? '—'} / ${row['total_marks'] ?? '—'}'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.primary)),
        Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      _caption(_tr('সঠিক: ${row['correct_count'] ?? 0} • ভুল: ${row['incorrect_count'] ?? 0} • উত্তর নেই: ${row['unanswered_count'] ?? 0}',
        'Correct: ${row['correct_count'] ?? 0} • Wrong: ${row['incorrect_count'] ?? 0} • Unanswered: ${row['unanswered_count'] ?? 0}')),
      const SizedBox(height: 2),
      _caption(_tr('জমা: ${row['submitted_at'] ?? '—'}', 'Submitted: ${row['submitted_at'] ?? '—'}')),
      Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(
        onPressed: _opening ? null : () => _openDetail(row),
        icon: const Icon(Icons.chevron_right, size: 18),
        label: Text(_tr('বিস্তারিত ফলাফল দেখুন', 'View result details'),
          style: const TextStyle(fontSize: 12)),
      )),
    ]);
  }

  Widget _content(List<Map<String, dynamic>> rows) {
    final valid = rows.where((r) => (_number(r['total_marks']) ?? 0) > 0 && _number(r['score']) != null).toList();
    double percent(Map<String, dynamic> row) =>
        _number(row['score'])! / _number(row['total_marks'])! * 100;
    final scores = valid.map(percent).toList();
    final average = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final best = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a > b ? a : b);
    final questions = rows.fold<double>(0, (sum, r) => sum + (_number(r['question_count']) ?? 0));
    final correct = rows.fold<double>(0, (sum, r) => sum + (_number(r['correct_count']) ?? 0));
    final accuracy = questions > 0 ? correct / questions * 100 : 0.0;
    final recent = scores.take(8).toList().reversed.toList();
    final grouped = <String, List<double>>{};
    for (final row in valid) {
      grouped.putIfAbsent(_title(row), () => []).add(percent(row));
    }
    String fmt(double n) => '${n.toStringAsFixed(1)}%';
    return ListView(physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16), children: [
        _card([
          _heading(_tr('আপনার প্রস্তুতির সারাংশ', 'Preparation summary')),
          const SizedBox(height: 8),
          _metrics([
            _metric(_tr('মোট পরীক্ষা', 'Total tests'), '${rows.length}'),
            _metric(_tr('পাস', 'Passed'), '${rows.where((r) => _passed(r['passed']) == true).length}'),
            _metric(_tr('গড় স্কোর', 'Average score'), scores.isEmpty ? '—' : fmt(average)),
          ]),
          const SizedBox(height: 10),
          _metrics([
            _metric(_tr('সেরা স্কোর', 'Best score'), scores.isEmpty ? '—' : fmt(best)),
            _metric(_tr('সঠিক উত্তরের হার', 'Accuracy'), questions > 0 ? fmt(accuracy) : '—'),
          ]),
          if (questions > 0) ...[const SizedBox(height: 8), _bar(accuracy)],
          const SizedBox(height: 6),
          _caption(_tr('প্রকাশিত ফলাফলের ভিত্তিতে হিসাব।', 'Based on published results.')),
        ]),
        if (recent.length > 1) _card([
          _heading(_tr('সাম্প্রতিক স্কোর ট্রেন্ড', 'Recent score trend')),
          const SizedBox(height: 8),
          for (var i = 0; i < recent.length; i++)
            Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [
              SizedBox(width: 22, child: _caption('${i + 1}')),
              Expanded(child: _bar(recent[i])),
              const SizedBox(width: 8),
              Text(fmt(recent[i]), style: const TextStyle(fontSize: 12)),
            ])),
          _caption(_tr('শেষ ৮টি প্রকাশিত ফলাফল; ১ = সবচেয়ে পুরোনো।',
            'Latest 8 published results; 1 = oldest shown.')),
        ]),
        if (grouped.isNotEmpty) _card([
          _heading(_tr('পরীক্ষাভিত্তিক গড় স্কোর', 'Average by test')),
          const SizedBox(height: 8),
          for (final entry in grouped.entries) ...[
            Text(entry.key, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _bar(entry.value.reduce((a, b) => a + b) / entry.value.length)),
              const SizedBox(width: 8),
              Text(fmt(entry.value.reduce((a, b) => a + b) / entry.value.length),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
          ],
          _caption(_tr('শুধু প্রকাশিত ফলাফল; আলাদা Subject তথ্য নেই।',
            'Published results only; separate subject data is unavailable.')),
        ]),
        _heading(_tr('পরীক্ষার ইতিহাস', 'Test history')),
        const SizedBox(height: 6),
        for (final row in rows) _resultCard(row),
      ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _header(),
    body: RefreshIndicator(onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const FsLoadingCards(count: 3);
          }
          if (snapshot.hasError) return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14), children: [
              FsStatusCard(icon: Icons.cloud_off_outlined,
                message: _tr('ফলাফল লোড করা যায়নি। লগইন ও সংযোগ পরীক্ষা করুন।',
                  'Could not load results. Check your login and connection.'),
                onRetry: _refresh),
            ]);
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14), children: [
              FsStatusCard(icon: Icons.assignment_outlined,
                message: _tr('এখনো কোনো প্রকাশিত ফলাফল নেই।', 'No published results yet.')),
            ]);
          return _content(rows);
        },
      )),
  );
}
