import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/auth_guard.dart';
import '../services/model_test_service.dart';

const Color _maroon = Color(0xFF650D18);
const Color _deepMaroon = Color(0xFF36060D);

class TestsPage extends StatefulWidget {
  const TestsPage({super.key});
  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  late Future<List<Map<String,dynamic>>> _tests;
  Map<int, Map<String, dynamic>> _activeAttempts = {};
  bool _loadingActiveAttempts = false;
  final Set<int> _startingTestIds = <int>{};
  @override
  void initState(){
    super.initState();
    _tests=ModelTestService.instance.listTests();
    _loadActiveAttempts();
  }
  Future<void> _loadActiveAttempts() async {
    if (_loadingActiveAttempts) return;
    _loadingActiveAttempts = true;
    try {
      final rows = await ModelTestService.instance.activeAttempts();
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
    final next=ModelTestService.instance.listTests();
    setState(()=>_tests=next);
    await Future.wait([next, _loadActiveAttempts()]);
  }
  Future<void> _start(Map<String,dynamic> test) async {
    final testId = (test['id'] as num).toInt();
    if (_startingTestIds.contains(testId)) return;
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
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
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('মডেল টেস্ট'),actions:[
      IconButton(tooltip:'আমার ফলাফল',onPressed:() async {if(!await AuthGuard.ensureAuthenticated(context)||!mounted)return;Navigator.push(context,MaterialPageRoute(builder:(_)=>const MyTestResultsPage()));},icon:const Icon(Icons.history)),
      IconButton(tooltip:'প্র্যাকটিস ড্যাশবোর্ড',onPressed:() async {if(!await AuthGuard.ensureAuthenticated(context)||!mounted)return;Navigator.push(context,MaterialPageRoute(builder:(_)=>const PracticeDashboardPage()));},icon:const Icon(Icons.insights)),
      IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))
    ]),
    body:RefreshIndicator(onRefresh:_refresh,child:FutureBuilder<List<Map<String,dynamic>>>(
      future:_tests,builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)return ListView(children:[const SizedBox(height:100),Center(child:Text('পরীক্ষার তালিকা লোড হয়নি।')),Center(child:TextButton(onPressed:_refresh,child:const Text('আবার চেষ্টা করুন')))]);
        final tests=snapshot.data??[];
        if(tests.isEmpty)return ListView(children:[const SizedBox(height:100),Center(child:Icon(Icons.assignment_outlined,size:54,color:_maroon)),const Center(child:Text('এখন কোনো প্রকাশিত পরীক্ষা নেই।'))]);
        return ListView(padding:const EdgeInsets.all(16),children:[
          Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[_deepMaroon,_maroon]),borderRadius:BorderRadius.circular(20)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.track_changes,color:Colors.orangeAccent,size:34),SizedBox(height:10),Text('নিজেকে যাচাই করুন',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.bold)),SizedBox(height:5),Text('প্রকাশিত পরীক্ষা নির্বাচন করে প্রস্তুতি যাচাই করুন।',style:TextStyle(color:Colors.white70))])),
          if (_activeAttempts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              color: const Color(0xFFFFF5E8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.pending_actions, color: Colors.deepOrange),
                      SizedBox(width: 8),
                      Expanded(child: Text('আপনার অসমাপ্ত পরীক্ষা',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 8),
                    for (final entry in _activeAttempts.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value['title']?.toString() ?? 'মডেল টেস্ট'),
                        subtitle: Text('বাকি সময়: ${((entry.value['remaining_seconds'] as num?)?.toInt() ?? 0) ~/ 60} মিনিট'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          final test = tests.firstWhere(
                            (t) => (t['id'] as num).toInt() == entry.key,
                            orElse: () => <String, dynamic>{},
                          );
                          if (test.isNotEmpty) _start(test);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height:16),
          for(final t in tests) Card(color:const Color(0xFF241D20),surfaceTintColor:Colors.transparent,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:BorderSide(color:Colors.white.withValues(alpha:0.16))),margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t['title']?.toString()??'মডেল টেস্ট',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
            if((t['description']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text(t['description'].toString())),
            const SizedBox(height:10),Wrap(spacing:14,runSpacing:8,children:[
              _meta(Icons.help_outline,'${t['question_count']} প্রশ্ন'),
              _meta(Icons.timer_outlined,'${t['duration_minutes']} মিনিট'),
              _meta(Icons.grade_outlined,'${t['total_marks']} নম্বর'),
              if(t['pass_marks']!=null)_meta(Icons.flag_outlined,'পাস ${t['pass_marks']}'),
              if(((t['negative_marks_per_question'] as num?)?.toDouble() ?? 0) > 0)
                _meta(Icons.remove_circle_outline,'ভুলে -${t['negative_marks_per_question']}'),
              if(t['randomize_questions']==true)_meta(Icons.shuffle,'প্রশ্নের ক্রম এলোমেলো'),
              if((t['max_attempts'] as num?)?.toInt()!=null && (t['max_attempts'] as num).toInt()>0)_meta(Icons.replay,'সর্বোচ্চ ${t['max_attempts']} বার'),
            ]),
            if((t['exam_instructions']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text('নির্দেশনা: ${t['exam_instructions']}',maxLines:3,overflow:TextOverflow.ellipsis)),
            const SizedBox(height:12),
            Align(
              alignment: Alignment.centerRight,
              child: Builder(builder: (context) {
                final testId = (t['id'] as num).toInt();
                final starting = _startingTestIds.contains(testId);
                final active = _activeAttempts.containsKey(testId);
                return FilledButton.icon(
                  onPressed: starting ? null : () => _start(t),
                  icon: starting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : Icon(active ? Icons.play_circle_outline : Icons.play_arrow),
                  label: Text(starting
                      ? 'প্রস্তুত হচ্ছে…'
                      : active ? 'পরীক্ষা চালিয়ে যান' : 'পরীক্ষা শুরু করুন'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9D1B30),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF6B2530),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
              }),
            )
          ])))
        ]);
      })),
  );
  Widget _meta(IconData icon,String text)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:16,color:_maroon),const SizedBox(width:4),Text(text,style:const TextStyle(fontSize:12))]);
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
          for(final letter in ['A','B','C','D'])Card(child:RadioListTile<String>(value:letter,groupValue:_answers[(q['id'] as num).toInt()],title:Text('$letter. ${options[letter]??''}'),onChanged:_submitting?null:(v)=>v==null?null:_choose(v))),
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
  const SubjectPracticePage({super.key, required this.subject});

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
        appBar: AppBar(title: Text('${widget.subject} অনুশীলন')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.subject} অনুশীলন')),
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
        appBar: AppBar(title: Text('${widget.subject} অনুশীলন')),
        body: const Center(child: Text('এই বিষয়ে Question Bank-এ প্রকাশিত প্রশ্ন পাওয়া যায়নি।')),
      );
    }
    final q = _questions[_index];
    final options = Map<String, dynamic>.from(q['options'] as Map? ?? {});
    final correct = q['correct_answer']?.toString().toUpperCase() ?? '';
    final explanation = q['explanation']?.toString() ?? '';
    final isLast = _index == _questions.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.subject} অনুশীলন')),
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
  const PracticeDashboardPage();
  @override
  State<PracticeDashboardPage> createState() => _PracticeDashboardPageState();
}

class _PracticeDashboardPageState extends State<PracticeDashboardPage> {
  late Future<Map<String, dynamic>> _data;
  bool _savingTarget = false;
  @override
  void initState() {
    super.initState();
    _data = ModelTestService.instance.practiceDashboard();
  }

  Future<void> _refresh() async {
    final next = ModelTestService.instance.practiceDashboard();
    setState(() => _data = next);
    await next;
  }

  Future<void> _chooseTarget(int current) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('দৈনিক অনুশীলনের লক্ষ্য', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ),
          for (final value in [5, 10, 15, 20, 30, 50])
            ListTile(
              title: Text('$valueটি প্রশ্ন'),
              trailing: value == current ? const Icon(Icons.check, color: _maroon) : null,
              onTap: () => Navigator.pop(ctx, value),
            ),
        ]),
      ),
    );
    if (selected == null) return;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('প্র্যাকটিস ড্যাশবোর্ড')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('প্র্যাকটিস রিপোর্ট লোড হয়নি।'),
            TextButton(onPressed: _refresh, child: const Text('আবার চেষ্টা করুন')),
          ]));
        }
        final data = snapshot.data ?? {};
        final today = Map<String, dynamic>.from(data['today'] as Map? ?? {});
        final overall = Map<String, dynamic>.from(data['overall'] as Map? ?? {});
        final target = (data['daily_target'] as num?)?.toInt() ?? 10;
        final done = (today['questions'] as num?)?.toInt() ?? 0;
        final weekly = (data['weekly'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final weak = (data['weak_subjects'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final maxDaily = weekly.fold<int>(1, (m, e) =>
            m > ((e['questions'] as num?)?.toInt() ?? 0) ? m : ((e['questions'] as num?)?.toInt() ?? 0));
        final totalQuestions = (overall['questions'] as num?)?.toInt() ?? 0;
        final totalCorrect = (overall['correct'] as num?)?.toInt() ?? 0;
        final overallAccuracy = totalQuestions == 0 ? 0.0 : totalCorrect / totalQuestions * 100;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              color: const Color(0xFFFFF5E8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('আজকের অনুশীলন',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                    TextButton(
                      onPressed: _savingTarget ? null : () => _chooseTarget(target),
                      child: const Text('লক্ষ্য পরিবর্তন'),
                    ),
                  ]),
                  Text('$done / $target প্রশ্ন সম্পন্ন',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _maroon)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (done / target).clamp(0.0, 1.0), minHeight: 10,
                      color: _maroon, backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(done >= target ? 'দারুণ! আজকের লক্ষ্য পূরণ হয়েছে।' : 'আর ${target - done}টি প্রশ্ন অনুশীলন করুন।'),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _dashboardMetric('মোট প্রশ্ন', '$totalQuestions')),
              const SizedBox(width: 8),
              Expanded(child: _dashboardMetric('সঠিকের হার', '${overallAccuracy.toStringAsFixed(1)}%')),
              const SizedBox(width: 8),
              Expanded(child: _dashboardMetric('স্ট্রিক', '${(overall['streak'] as num?)?.toInt() ?? 0} দিন')),
            ]),
            const SizedBox(height: 14),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('গত ৭ দিনের অগ্রগতি', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                for (final day in weekly) ...[
                  Row(children: [
                    SizedBox(width: 82, child: Text(day['date']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: (((day['questions'] as num?)?.toDouble() ?? 0) / maxDaily).clamp(0.0, 1.0),
                        minHeight: 8, color: _maroon, backgroundColor: Colors.grey.shade200,
                      ),
                    )),
                    const SizedBox(width: 8),
                    Text('${day['questions'] ?? 0}', style: const TextStyle(fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (weekly.isEmpty) const Text('এখনো কোনো অনুশীলনের রেকর্ড নেই।'),
              ]),
            )),
            const SizedBox(height: 10),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('যে বিষয়গুলোতে আরও অনুশীলন দরকার',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                for (final subject in weak)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(subject['category']?.toString() ?? 'অন্যান্য'),
                    subtitle: Text('${subject['questions']} প্রশ্ন • ${subject['sessions']} সেশন'),
                    trailing: Text('${subject['accuracy']}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _maroon)),
                  ),
                if (weak.isEmpty) const Text('বিষয়ভিত্তিক পরামর্শ পেতে অনুশীলন সম্পন্ন করুন।'),
              ]),
            )),
            const SizedBox(height: 10),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('আপনার অর্জন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _achievementChip('প্রথম পদক্ষেপ', totalQuestions >= 1, Icons.flag),
                  _achievementChip('৫০ প্রশ্ন', totalQuestions >= 50, Icons.school),
                  _achievementChip('১০০ প্রশ্ন', totalQuestions >= 100, Icons.workspace_premium),
                  _achievementChip('৭ দিনের ধারাবাহিকতা', ((overall['streak'] as num?)?.toInt() ?? 0) >= 7, Icons.local_fire_department),
                  _achievementChip('লক্ষ্য পূরণ', done >= target, Icons.check_circle),
                ]),
              ]),
            )),
          ]),
        );
      },
    ),
  );

  Widget _dashboardMetric(String label, String value) => Card(
    child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _maroon)),
      const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
    ])),
  );

  Widget _achievementChip(String label, bool unlocked, IconData icon) => Chip(
    avatar: Icon(icon, size: 16, color: unlocked ? Colors.green : Colors.grey),
    label: Text(label),
    backgroundColor: unlocked ? Colors.green.shade50 : Colors.grey.shade100,
    side: BorderSide(color: unlocked ? Colors.green.shade200 : Colors.grey.shade300),
  );
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

Widget _resultMetric(String label, String value) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(value, style: const TextStyle(
      color: _maroon, fontSize: 20, fontWeight: FontWeight.bold,
    )),
    Text(label, style: const TextStyle(fontSize: 11)),
  ],
);

class MyTestResultsPage extends StatefulWidget{
  const MyTestResultsPage();
  @override
  State<MyTestResultsPage> createState()=>_MyTestResultsPageState();
}
class _MyTestResultsPageState extends State<MyTestResultsPage>{
  late Future<List<Map<String,dynamic>>> _future;
  @override
  void initState(){super.initState();_future=ModelTestService.instance.myResults();}
  Future<void> _refresh()async{final f=ModelTestService.instance.myResults();setState(()=>_future=f);await f;}
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('আমার পরীক্ষার ফলাফল'),actions:[IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))]),
    body:RefreshIndicator(onRefresh:_refresh,child:FutureBuilder<List<Map<String,dynamic>>>(
      future:_future,builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)return ListView(children:[const SizedBox(height:100),Center(child:Text('ফলাফল লোড করা যায়নি।')),Center(child:TextButton(onPressed:_refresh,child:const Text('আবার চেষ্টা করুন')))]);
        final rows=snapshot.data??[];
        if(rows.isEmpty)return ListView(children:[const SizedBox(height:110),const Center(child:Icon(Icons.assignment_outlined,size:56,color:_maroon)),const Center(child:Text('এখনো কোনো প্রকাশিত ফলাফল নেই।'))]);
        final totalAttempts = rows.length;
        final passedAttempts = rows.where((r) => r['passed'] == true || r['passed'] == 1).length;
        final validScores = rows.where((r) => ((r['total_marks'] as num?)?.toDouble() ?? 0) > 0).toList();
        final percentages = validScores
            .map((r) => ((r['score'] as num?)?.toDouble() ?? 0) /
                (r['total_marks'] as num).toDouble() * 100)
            .toList();
        final average = percentages.isEmpty ? 0.0 :
            percentages.reduce((a, b) => a + b) / percentages.length;
        final bestScore = percentages.isEmpty ? 0.0 :
            percentages.reduce((a, b) => a > b ? a : b);
        final totalQuestions = rows.fold<int>(0, (sum, r) =>
            sum + ((r['question_count'] as num?)?.toInt() ?? 0));
        final totalCorrect = rows.fold<int>(0, (sum, r) =>
            sum + ((r['correct_count'] as num?)?.toInt() ?? 0));
        final accuracy = totalQuestions == 0 ? 0.0 :
            totalCorrect / totalQuestions * 100;
        final recentScores = percentages.reversed.take(8).toList().reversed.toList();
        final grouped = <String, List<double>>{};
        for (final row in validScores) {
          final title = row['title']?.toString() ?? 'মডেল টেস্ট';
          final percent = ((row['score'] as num?)?.toDouble() ?? 0) /
              (row['total_marks'] as num).toDouble() * 100;
          grouped.putIfAbsent(title, () => []).add(percent);
        }
        final testAverages = grouped.entries.map((entry) {
          final values = entry.value;
          return MapEntry(entry.key, values.reduce((a, b) => a + b) / values.length);
        }).toList();
        return ListView(padding:const EdgeInsets.all(16),children:[
          Card(
            color: const Color(0xFFFFF5F3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('আপনার প্রস্তুতির সারাংশ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _resultMetric('মোট পরীক্ষা', '$totalAttempts')),
                      Expanded(child: _resultMetric('পাস', '$passedAttempts')),
                      Expanded(child: _resultMetric('গড় স্কোর', '${average.toStringAsFixed(1)}%')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('প্রকাশিত ফলাফলের ভিত্তিতে হিসাব করা হয়েছে।',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('আরও কিছু পারফরম্যান্স তথ্য',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _resultMetric('সেরা স্কোর', '${bestScore.toStringAsFixed(1)}%')),
                    Expanded(child: _resultMetric('সঠিক উত্তরের হার', '${accuracy.toStringAsFixed(1)}%')),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (accuracy / 100).clamp(0.0, 1.0),
                      minHeight: 9,
                      backgroundColor: Colors.grey.shade200,
                      color: _maroon,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('প্রকাশিত ফলাফলের মোট প্রশ্ন ও সঠিক উত্তরের ভিত্তিতে হিসাব।',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
          if (recentScores.length > 1)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('সাম্প্রতিক পরীক্ষার স্কোর ট্রেন্ড',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 116,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < recentScores.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('${recentScores[i].toStringAsFixed(0)}%',
                                      style: const TextStyle(fontSize: 9)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: (recentScores[i].clamp(0, 100) / 100 * 78).clamp(3, 78),
                                      decoration: BoxDecoration(
                                        color: _maroon.withValues(alpha: 0.78),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${i + 1}', style: const TextStyle(fontSize: 9)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Text('ক্রম অনুযায়ী শেষ ৮টি প্রকাশিত ফলাফল; ১ = সবচেয়ে পুরোনো।',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          if (testAverages.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('পরীক্ষাভিত্তিক গড় স্কোর',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    for (final item in testAverages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              Expanded(child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (item.value / 100).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  color: _maroon,
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              )),
                              const SizedBox(width: 10),
                              Text('${item.value.toStringAsFixed(1)}%',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                          ],
                        ),
                      ),
                    const Text('শুধু প্রকাশিত ফলাফলের ভিত্তিতে; Admin-এর আলাদা Subject তথ্য এখানে নেই।',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          for(final r in rows)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(r['title']?.toString()??'মডেল টেস্ট',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
            const SizedBox(height:8),
            Text('স্কোর: ${r['score']??'—'} / ${r['total_marks']??'—'}'),
            Text('সঠিক: ${r['correct_count']??0}  •  ভুল: ${r['incorrect_count']??0}  •  উত্তর নেই: ${r['unanswered_count']??0}'),
            Text('জমা: ${r['submitted_at']??'—'}'),
            Text(r['passed']==null?'পাস নম্বর নির্ধারিত নয়':((r['passed']==true||r['passed']==1)?'Pass':'Fail'),style:TextStyle(fontWeight:FontWeight.bold,color:(r['passed']==true||r['passed']==1)?Colors.green:Colors.red)),
            Align(alignment:Alignment.centerRight,child:TextButton(onPressed:() async {
              try{
                final detail=await ModelTestService.instance.getResult((r['attempt_id'] as num).toInt());
                if(!mounted)return;
                Navigator.push(context,MaterialPageRoute(builder:(_)=>_ExamResult(result:detail)));
              }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
            },child:const Text('বিস্তারিত ফলাফল দেখুন')))
          ])))
        ]);
      }))
  );
}
