import 'package:flutter/material.dart';
import '../services/question_library_service.dart';
import 'premium_page.dart';

class QuestionBrowserPage extends StatefulWidget {
  const QuestionBrowserPage({super.key,this.initialSearch='',this.category='',this.savedOnly=false,this.noteId});
  final String initialSearch,category;
  final bool savedOnly;
  final int? noteId;
  @override
  State<QuestionBrowserPage> createState()=>_QuestionBrowserPageState();
}

class _QuestionBrowserPageState extends State<QuestionBrowserPage> {
  late final _service=QuestionLibraryService();
  late final _search=TextEditingController(text:widget.initialSearch);
  late bool _saved=widget.savedOnly;
  String _difficulty='all';
  int _page=1;
  late Future<Map<String,dynamic>> _future=_fetch();
  Future<Map<String,dynamic>> _fetch()=>_service.fetch(search:_search.text.trim(),category:widget.category,
    difficulty:_difficulty,saved:_saved,page:_page,noteId:widget.noteId);
  void _reload({int page=1})=>setState((){_page=page;_future=_fetch();});
  @override
  void dispose(){_search.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.noteId!=null?'সংশ্লিষ্ট বিভাগের প্রশ্ন':'প্রশ্ন অনুশীলন')),
    body:FutureBuilder<Map<String,dynamic>>(future:_future,builder:(context,snapshot){
      final loading=snapshot.connectionState==ConnectionState.waiting;
      final data=loading?null:snapshot.data;
      final rows=(data?['data'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      return ListView(padding:const EdgeInsets.all(16),children:[
        TextField(controller:_search,maxLength:120,textInputAction:TextInputAction.search,onSubmitted:(_)=>_reload(),
          decoration:InputDecoration(hintText:'প্রশ্ন, বিষয় বা রেফারেন্স খুঁজুন',suffixIcon:IconButton(onPressed:()=>_reload(),icon:const Icon(Icons.search)))),
        if(widget.category.isNotEmpty) Text('বিভাগ: ${widget.category}'),
        if(widget.noteId!=null&&data?['related_match']==true) Text('মিল পাওয়া প্রশ্নের বিভাগ: ${data?['category']}'),
        DropdownButtonFormField<String>(initialValue:_difficulty,
          decoration:const InputDecoration(labelText:'কঠিনতার মাত্রা'),
          items:const [
            DropdownMenuItem(value:'all',child:Text('সব স্তর')),
            DropdownMenuItem(value:'easy',child:Text('সহজ')),
            DropdownMenuItem(value:'medium',child:Text('মাঝারি')),
            DropdownMenuItem(value:'hard',child:Text('কঠিন')),
          ],
          onChanged:(v){if(v!=null){_difficulty=v;_reload();}}),
        SwitchListTile(title:const Text('শুধু বুকমার্ক করা প্রশ্ন'),value:_saved,onChanged:(v){_saved=v;_reload();}),
        if(loading) const Center(child:CircularProgressIndicator())
        else if(snapshot.hasError||data==null) ...[
          const Text('প্রশ্ন লোড হয়নি। লগইন ও সংযোগ পরীক্ষা করুন।'),
          OutlinedButton(onPressed:()=>_reload(page:_page),child:const Text('আবার চেষ্টা করুন')),
        ] else if(data['related_match']==false) const Text('এই নোটের ক্যাটাগরির সঙ্গে প্রকাশিত কোনো প্রশ্নের বিভাগ মেলেনি।')
        else if(rows.isEmpty) const Text('কোনো প্রশ্ন পাওয়া যায়নি।')
        else for(final row in rows) if(row['locked']==true)
          Card(child:ListTile(leading:const Icon(Icons.lock_outline),title:Text(row['question']?.toString()??''),subtitle:const Text('Premium প্রশ্ন'),trailing:const Icon(Icons.workspace_premium_outlined),onTap:() async{
            await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const PremiumPage()));
            if(mounted)_reload(page:_page);
          }))
        else _LibraryQuestionCard(key:ValueKey(row['id']),row:row,service:_service,onRemoved:(){if(_saved)_reload(page:_page);}),
        if(!loading&&data!=null) Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          TextButton(onPressed:_page>1?()=>_reload(page:_page-1):null,child:const Text('আগের পেজ')),
          Text('$_page'),
          TextButton(onPressed:data['has_more']==true?()=>_reload(page:_page+1):null,child:const Text('পরের পেজ')),
        ]),
        const Text('এটি স্বতন্ত্র অনুশীলন; মডেল টেস্টের নম্বর বা প্রস্তুতির পরিসংখ্যান পরিবর্তন করবে না।'),
      ]);
    }),
  );
}

class _LibraryQuestionCard extends StatefulWidget {
  const _LibraryQuestionCard({super.key,required this.row,required this.service,required this.onRemoved});
  final Map<String,dynamic> row;
  final QuestionLibraryService service;
  final VoidCallback onRemoved;
  @override
  State<_LibraryQuestionCard> createState()=>_LibraryQuestionCardState();
}

class _LibraryQuestionCardState extends State<_LibraryQuestionCard> {
  late bool _saved=widget.row['saved']==true;
  bool _busy=false;
  String? _answer;
  Future<void> _toggle() async {
    if(_busy)return;
    setState(()=>_busy=true);
    final next=!_saved;
    try{
      await widget.service.bookmark(widget.row['id'].toString(),next);
      if(!mounted)return;
      setState(()=>_saved=next);
      if(!next)widget.onRemoved();
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('বুকমার্ক পরিবর্তন হয়নি। আবার চেষ্টা করুন।')));
    }finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context){
    final q=widget.row;
    final options=Map<String,dynamic>.from(q['options'] as Map? ?? {});
    final correct=q['correct_answer']?.toString()??'';
    final colors=Theme.of(context).colorScheme;
    return Card(clipBehavior: Clip.antiAlias, child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text('${q['category']??''} • ${q['difficulty']??''}',style:Theme.of(context).textTheme.labelMedium)),
        IconButton(tooltip:_saved?'বুকমার্ক সরান':'বুকমার্ক করুন',onPressed:_busy?null:_toggle,
          icon:Icon(_saved?Icons.bookmark:Icons.bookmark_border,color:colors.primary)),
      ]),
      Text(q['question']?.toString()??'',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)),
      for(final letter in ['A','B','C','D'])
        ListTile(contentPadding:EdgeInsets.zero,
          leading:Icon(_answer==null?Icons.radio_button_unchecked:letter==correct?Icons.check_circle_outline:letter==_answer?Icons.cancel_outlined:Icons.radio_button_unchecked,
            color:_answer!=null&&letter==correct?colors.primary:_answer==letter?colors.error:null),
          title:Text('$letter. ${options[letter]??''}'),onTap:_answer==null?()=>setState(()=>_answer=letter):null),
      if(_answer!=null)...[
        Text(_answer==correct?'সঠিক উত্তর!':'সঠিক উত্তর: $correct',style:TextStyle(fontWeight:FontWeight.bold,color:_answer==correct?colors.primary:colors.error)),
        if((q['explanation']?.toString()??'').trim().isNotEmpty) Text('ব্যাখ্যা: ${q['explanation']}'),
        if((q['reference']?.toString()??'').trim().isNotEmpty) Text('রেফারেন্স: ${q['reference']}'),
      ],
    ])));
  }
}
