import 'dart:async';
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
  @override
  void initState(){super.initState();_tests=ModelTestService.instance.listTests();}
  Future<void> _refresh() async {final next=ModelTestService.instance.listTests();setState(()=>_tests=next);await next;}
  Future<void> _start(Map<String,dynamic> test) async {
    if(!await AuthGuard.ensureAuthenticated(context)||!mounted)return;
    try {
      final attempt=await ModelTestService.instance.start((test['id'] as num).toInt());
      if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>_ExamRunner(attempt:attempt)));
      if(mounted) _refresh();
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('মডেল টেস্ট'),actions:[
      IconButton(tooltip:'আমার ফলাফল',onPressed:() async {if(!await AuthGuard.ensureAuthenticated(context)||!mounted)return;Navigator.push(context,MaterialPageRoute(builder:(_)=>const _MyTestResultsPage()));},icon:const Icon(Icons.history)),
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
          const SizedBox(height:16),
          for(final t in tests) Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
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
            const SizedBox(height:12),Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:()=>_start(t),icon:const Icon(Icons.play_arrow),label:const Text('পরীক্ষা শুরু করুন'),style:FilledButton.styleFrom(backgroundColor:_maroon)))
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
class _ExamRunnerState extends State<_ExamRunner>{
  late final List<Map<String,dynamic>> _questions;
  late final int _attemptId,_testId;
  late int _remaining,_index=0;
  Timer? _timer;
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
    _remaining=(widget.attempt['remaining_seconds'] as num?)?.toInt()??0;
    _timer=Timer.periodic(const Duration(seconds:1),(_){
      if(!mounted||_submitting)return;
      if(_remaining<=1){setState(()=>_remaining=0);_finish(auto:true);return;}
      setState(()=>_remaining--);
    });
  }
  @override
  void dispose(){_timer?.cancel();super.dispose();}
  String get _clock=>'${(_remaining~/60).toString().padLeft(2,'0')}:${(_remaining%60).toString().padLeft(2,'0')}';
  Future<void> _choose(String answer) async {
    final q=_questions[_index];final id=(q['id'] as num).toInt();
    setState(()=>_answers[id]=answer);
    final pending=_saveQueue.catchError((_){}).then((_)=>ModelTestService.instance.saveAnswer(attemptId:_attemptId,testId:_testId,questionId:id,answer:answer));
    _saveQueue=pending;
    try{await pending;if(mounted)setState(()=>_saveError=null);}
    catch(e){if(mounted)setState(()=>_saveError='উত্তর সার্ভারে সংরক্ষণ হয়নি। Submit করার আগে আবার সংরক্ষণ চেষ্টা করা হবে।');}
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
      // While time remains, flush the latest selected answers in order.
      // Once the server deadline has passed, answer writes are correctly
      // rejected; submit the answers already saved before expiry instead.
      if(_remaining>0){
        for(final entry in _answers.entries){
          await ModelTestService.instance.saveAnswer(attemptId:_attemptId,testId:_testId,questionId:entry.key,answer:entry.value);
        }
      }
      final response=await ModelTestService.instance.submit(attemptId:_attemptId,testId:_testId);
      if(!mounted)return;
      if(response['result_released']==true && response['result'] is Map){
        await Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>_ExamResult(result:Map<String,dynamic>.from(response['result'] as Map))));
      }else{
        await Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const _ResultPending()));
      }
    }catch(e){if(mounted){setState(()=>_submitting=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));if(auto)_timer=Timer.periodic(const Duration(seconds:1),(_){if(!mounted||_submitting)return;if(_remaining<=1){_remaining=0;_finish(auto:true);}else{setState(()=>_remaining--);}});}}
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
          if(_saveError!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_saveError!,style:const TextStyle(color:Colors.red))),
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
      const SizedBox(height:12),const Text('প্রশ্নভিত্তিক পর্যালোচনা',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      for(final q in questions)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${q['order']}. ${q['question']}',style:const TextStyle(fontWeight:FontWeight.bold)),
        for(final letter in ['A','B','C','D'])Padding(padding:const EdgeInsets.only(top:4),child:Text('$letter. ${(q['options'] as Map)[letter]}')),
        const SizedBox(height:6),Text('তোমার উত্তর: ${q['selected_answer']??'উত্তর দাওনি'}'),Text('সঠিক উত্তর: ${q['correct_answer']}',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.bold)),
        if((q['explanation']??'').toString().isNotEmpty)Text('ব্যাখ্যা: ${q['explanation']}')
      ]))),
      const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.popUntil(context,(r)=>r.isFirst),child:const Text('পরীক্ষার তালিকায় ফিরুন'))
    ]));
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

class _MyTestResultsPage extends StatefulWidget{
  const _MyTestResultsPage();
  @override
  State<_MyTestResultsPage> createState()=>_MyTestResultsPageState();
}
class _MyTestResultsPageState extends State<_MyTestResultsPage>{
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
        final average = validScores.isEmpty ? 0.0 : validScores
            .map((r) => ((r['score'] as num?)?.toDouble() ?? 0) /
                (r['total_marks'] as num).toDouble() * 100)
            .reduce((a, b) => a + b) / validScores.length;
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
