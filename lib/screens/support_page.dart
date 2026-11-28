import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/support_service.dart';
import '../settings/app_settings.dart';

const _status={'open':'উত্তরের অপেক্ষায়','answered':'উত্তর দেওয়া হয়েছে','closed':'বন্ধ'};
const _plans={'none':'নির্দিষ্ট নয়','monthly':'মাসিক','quarterly':'ত্রৈমাসিক','annual':'বার্ষিক'};
const _warning='PIN, OTP, পাসওয়ার্ড বা কার্ডের তথ্য পাঠাবেন না। এটি সহায়তা, পেমেন্ট গ্রহণের মাধ্যম নয়।';
class SupportPage extends StatefulWidget{
  const SupportPage({super.key, this.generalSupport = false, this.service});
  final SupportService? service;
  final bool generalSupport;
  @override
  State<SupportPage> createState()=>_SupportPageState();
}
class _SupportPageState extends State<SupportPage>{
  late final _service=widget.service??SupportService();
  int _page=1;
  late Future<Map<String,dynamic>> _data=_service.tickets(_page);
  void _load([int? page])=>setState((){_page=page??_page;_data=_service.tickets(_page);});
  Future<void> _open(String id) async{
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>widget.generalSupport ? _GeneralSupportChat(service:_service,id:id) : _SupportThread(service:_service,id:id)));
    if(mounted)_load();
  }
  Future<void> _compose() async{
    final id=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>widget.generalSupport ? _GeneralSupportChat(service:_service) : _SupportCompose(service:_service,generalSupport:false)));
    if(!mounted)return;
    if(widget.generalSupport){_load(1);return;}
    if(id!=null){_load(1);await _open(id);}
  }
  String _tr(String bn,String en)=>AppText.of(context,bn,en);

  Widget _generalList(AsyncSnapshot<Map<String,dynamic>> snapshot,
      Iterable<Map> rows,Map<String,dynamic>? data) {
    if(snapshot.connectionState==ConnectionState.waiting) {
      return const Center(child:CircularProgressIndicator());
    }
    if(snapshot.hasError||data==null) {
      return Center(child:OutlinedButton(onPressed:()=>_load(),
        child:Text(_tr('আবার চেষ্টা করুন','Try again'))));
    }
    return RefreshIndicator(onRefresh:() async {
      _load();
      try {await _data;} catch (_) {}
    },child:ListView(padding:const EdgeInsets.all(12),
      physics:const AlwaysScrollableScrollPhysics(),children:[
        FilledButton.icon(onPressed:_compose,icon:const Icon(Icons.chat_bubble_outline,size:19),
          label:Text(_tr('নতুন মেসেজ','New message'))),
        if(rows.isEmpty)Padding(padding:const EdgeInsets.all(24),
          child:Center(child:Text(_tr('কোনো কথোপকথন নেই','No conversations')))),
        for(final row in rows)Card(child:ListTile(
          leading:const Icon(Icons.support_agent_rounded),
          title:Text((row['last_message']??_tr('কথোপকথন','Conversation')).toString(),
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontWeight:FontWeight.w500,fontSize:14)),
          subtitle:Text(_supportStatus(context,row['status'].toString())),
          trailing:const Icon(Icons.chevron_right),
          onTap:()=>_open(row['id'].toString()))),
        if(_page>1||data['has_more']==true)Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          TextButton(onPressed:_page>1?()=>_load(_page-1):null,
            child:Text(_tr('আগের পেজ','Previous'))),
          Text('$_page'),
          TextButton(onPressed:data['has_more']==true?()=>_load(_page+1):null,
            child:Text(_tr('পরের পেজ','Next'))),
        ]),
      ]));
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.generalSupport ? AppText.of(context,'অ্যাডমিন সাপোর্ট','Admin support') : 'পেমেন্ট ও সদস্যপদ সহায়তা'),actions:[IconButton(onPressed:()=>_load(),icon:const Icon(Icons.refresh),tooltip:'রিফ্রেশ')]),
    body:FutureBuilder<Map<String,dynamic>>(future:_data,builder:(context,snapshot){
      final data=snapshot.connectionState==ConnectionState.waiting?null:snapshot.data;
      final rows=(data?['data'] as List? ?? []).whereType<Map>();
      if(widget.generalSupport)return _generalList(snapshot,rows,data);
      return ListView(padding:const EdgeInsets.all(16),children:[
        const Text(_warning),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:_compose,icon:const Icon(Icons.edit_outlined),label:const Text('নতুন মেসেজ')),
        if(snapshot.connectionState==ConnectionState.waiting)const Center(child:CircularProgressIndicator())
        else if(snapshot.hasError||data==null)...[
          const Text('মেসেজ লোড হয়নি। লগইন ও সংযোগ পরীক্ষা করুন।'),
          OutlinedButton(onPressed:()=>_load(),child:const Text('আবার চেষ্টা করুন')),
        ]else...[
          if(rows.isEmpty)const Text('কোনো কথোপকথন নেই।'),
          for(final row in rows)Card(child:ListTile(
            leading:Icon(row['status']=='answered'?Icons.mark_email_unread_outlined:Icons.chat_bubble_outline),
            title:Text(row['subject'].toString()),
            subtitle:Text('${_status[row['status']]??''} • ${_plans[row['plan_code']]??''}'),
            trailing:const Icon(Icons.chevron_right),onTap:()=>_open(row['id'].toString()))),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
            TextButton(onPressed:_page>1?()=>_load(_page-1):null,child:const Text('আগের পেজ')),
            Text('$_page'),
            TextButton(onPressed:data['has_more']==true?()=>_load(_page+1):null,child:const Text('পরের পেজ')),
          ]),
        ],
      ]);
    }),
  );
}
class _SupportCompose extends StatefulWidget{
  const _SupportCompose({required this.service, required this.generalSupport});
  final bool generalSupport;
  final SupportService service;
  @override
  State<_SupportCompose> createState()=>_SupportComposeState();
}
class _SupportComposeState extends State<_SupportCompose>{
  final _subject=TextEditingController(),_body=TextEditingController();
  final _form=GlobalKey<FormState>();
  String _plan='none';bool _sending=false;
  @override
  void dispose(){_subject.dispose();_body.dispose();super.dispose();}
  Future<void> _send() async{
    if(_sending||!_form.currentState!.validate())return;
    setState(()=>_sending=true);
    try{
      final id=await widget.service.create(_subject.text.trim(),_plan,_body.text.trim());
      if(mounted)Navigator.pop(context,id);
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('মেসেজ পাঠানো নিশ্চিত হয়নি। তালিকা দেখে আবার চেষ্টা করুন।')));
    }finally{if(mounted)setState(()=>_sending=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('নতুন মেসেজ')),
    body:Form(key:_form,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text(_warning),
      if(!widget.generalSupport) DropdownButtonFormField<String>(initialValue:_plan,decoration:const InputDecoration(labelText:'প্যাকেজ (ঐচ্ছিক)'),
        items:[for(final p in _plans.entries)DropdownMenuItem(value:p.key,child:Text(p.value))],
        onChanged:_sending?null:(v)=>setState(()=>_plan=v??'none')),
      TextFormField(controller:_subject,maxLength:160,enabled:!_sending,decoration:const InputDecoration(labelText:'বিষয়'),validator:(v)=>(v??'').trim().isEmpty?'বিষয় লিখুন':null),
      TextFormField(controller:_body,maxLength:2000,maxLines:6,enabled:!_sending,decoration:const InputDecoration(labelText:'মেসেজ'),validator:(v)=>(v??'').trim().isEmpty?'মেসেজ লিখুন':null),
      FilledButton(onPressed:_sending?null:_send,child:Text(_sending?'পাঠানো হচ্ছে...':'অ্যাডমিনকে মেসেজ পাঠান')),
    ])));
}
class _SupportThread extends StatefulWidget{
  const _SupportThread({required this.service,required this.id});
  final SupportService service;final String id;
  @override
  State<_SupportThread> createState()=>_SupportThreadState();
}
class _SupportThreadState extends State<_SupportThread>{
  final _body=TextEditingController();bool _sending=false;
  late Future<Map<String,dynamic>> _data=widget.service.thread(widget.id);
  void _load({String? before})=>setState(()=>_data=widget.service.thread(widget.id,before:before));
  @override
  void dispose(){_body.dispose();super.dispose();}
  Future<void> _reply() async{
    if(_sending||_body.text.trim().isEmpty)return;
    setState(()=>_sending=true);
    try{await widget.service.reply(widget.id,_body.text.trim());if(mounted){_body.clear();_load();}}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('উত্তর পাঠানো নিশ্চিত হয়নি। রিফ্রেশ করে দেখুন।')));}
    finally{if(mounted)setState(()=>_sending=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('অ্যাডমিনের সঙ্গে কথোপকথন'),actions:[IconButton(onPressed:_sending?null:()=>_load(),icon:const Icon(Icons.refresh))]),
    body:FutureBuilder<Map<String,dynamic>>(future:_data,builder:(context,snapshot){
      if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError||!snapshot.hasData)return Center(child:OutlinedButton(onPressed:()=>_load(),child:const Text('মেসেজ লোড হয়নি, আবার চেষ্টা করুন')));
      final data=snapshot.data!;
      final ticket=Map<String,dynamic>.from(data['ticket'] as Map);
      final rows=(data['messages'] as List? ?? []).whereType<Map>();
      final colors=Theme.of(context).colorScheme;
      return ListView(padding:const EdgeInsets.all(16),children:[
        Text(ticket['subject'].toString(),style:Theme.of(context).textTheme.titleLarge),
        Text(_status[ticket['status']]??''),
        if(data['next_before_id']!=null)TextButton(onPressed:()=>_load(before:data['next_before_id'].toString()),child:const Text('পুরোনো মেসেজ')),
        for(final row in rows)Align(alignment:row['sender']=='user'?Alignment.centerRight:Alignment.centerLeft,
          child:Card(color:row['sender']=='user'?colors.primaryContainer:colors.surfaceContainerHigh,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
            Text(row['sender']=='admin'?'অ্যাডমিন':'আপনি',style:const TextStyle(fontWeight:FontWeight.bold)),
            SelectableText(row['body'].toString()),
            Text('${row['created_at']} UTC',style:Theme.of(context).textTheme.labelSmall),
          ])))),
        if(ticket['status']!='closed')...[
          const SizedBox(height:12),
          const Text(_warning),
          TextField(controller:_body,maxLength:2000,maxLines:4,enabled:!_sending,decoration:const InputDecoration(labelText:'আপনার মেসেজ')),
          FilledButton.icon(onPressed:_sending?null:_reply,icon:const Icon(Icons.send),label:const Text('পাঠান')),
        ]else const Text('কথোপকথন বন্ধ হয়েছে। প্রয়োজনে নতুন টিকিট করুন।'),
      ]);
    }),
  );
}

String _supportStatus(BuildContext context,String status)=>switch(status){
  'open'=>AppText.of(context,'উত্তরের অপেক্ষায়','Awaiting reply'),
  'answered'=>AppText.of(context,'উত্তর দেওয়া হয়েছে','Answered'),
  'closed'=>AppText.of(context,'বন্ধ','Closed'),
  _=>'',
};

DateTime? _dhakaTime(Object? raw) {
  if(raw==null)return null;
  final parsed=DateTime.tryParse(raw.toString().replaceFirst(' ','T')+'Z');
  return parsed?.toUtc().add(const Duration(hours:6));
}

bool _sameDay(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;

// General support is a compact chat, while payment support keeps its form.
class _GeneralSupportChat extends StatefulWidget {
  const _GeneralSupportChat({required this.service,this.id});
  final SupportService service;
  final String? id;
  @override
  State<_GeneralSupportChat> createState()=>_GeneralSupportChatState();
}

class _GeneralSupportChatState extends State<_GeneralSupportChat>
    with WidgetsBindingObserver {
  final _body=TextEditingController();
  final _scroll=ScrollController();
  late String? _id=widget.id;
  Timer? _poll;
  bool _busy=false,_loading=false,_error=false,_olderLoading=false;
  bool _foreground=true;
  int _generation=0;
  String? _before;
  String _statusCode='open';
  final Map<String,Map<String,dynamic>> _messages={};

  String _tr(String bn,String en)=>AppText.of(context,bn,en);

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state=WidgetsBinding.instance.lifecycleState;
    _foreground=state==null||state==AppLifecycleState.resumed;
    if(_id!=null)_load();
    _poll=Timer.periodic(const Duration(seconds:15),(_){
      if(mounted&&_foreground&&ModalRoute.of(context)?.isCurrent==true&&_id!=null){
        _load(quiet:true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    _foreground=state==AppLifecycleState.resumed;
    if(_foreground&&mounted&&ModalRoute.of(context)?.isCurrent==true&&_id!=null){
      _load(quiet:true);
    }
  }

  @override
  void dispose(){
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _body.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Map<String,dynamic>> _rows(Map<String,dynamic> data)=>
    (data['messages'] as List? ?? []).whereType<Map>()
      .map((m)=>Map<String,dynamic>.from(m)).toList();

  void _bottom(){
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted&&_scroll.hasClients)_scroll.jumpTo(0);
    });
  }

  Future<void> _load({bool quiet=false,bool older=false}) async{
    final id=_id;
    if(id==null||_busy||_loading||_olderLoading||older&&_before==null)return;
    final epoch=++_generation;
    final nearBottom=!_scroll.hasClients||_scroll.offset<80;
    if(older){setState(()=>_olderLoading=true);}
    else{_loading=true;if(!quiet)setState(()=>_error=false);}
    try{
      final data=await widget.service.thread(id,before:older?_before:null);
      if(!mounted||epoch!=_generation)return;
      final rows=_rows(data);
      final ticket=Map<String,dynamic>.from(data['ticket'] as Map);
      setState((){
        _statusCode=ticket['status'].toString();
        if(!older){
          // Replace the server's latest visible window, retaining older pages
          // already explicitly loaded. Never reinsert a locally hidden row.
          if(rows.isNotEmpty){
            final first=int.parse(rows.first['id'].toString());
            _messages.removeWhere((key,_)=>int.parse(key)>=first);
          }else{_messages.clear();}
        }
        for(final row in rows){_messages[row['id'].toString()]=row;}
        if(older||_before==null||_messages.length<=rows.length){
          _before=data['next_before_id']?.toString();
        }
        _error=false;
      });
      if(!older&&nearBottom)_bottom();
    }catch(_){
      if(mounted&&epoch==_generation&&!quiet)setState(()=>_error=true);
    }finally{
      if(mounted&&epoch==_generation)setState((){_loading=false;_olderLoading=false;});
    }
  }

  void _notice(String bn,String en){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_tr(bn,en))));
  }

  void _beginMutation(){
    _generation++;
    setState((){_busy=true;_loading=false;_olderLoading=false;});
  }

  Future<void> _send() async{
    final body=_body.text.trim();
    if(_busy||body.isEmpty||body.runes.length>2000||_statusCode=='closed')return;
    _beginMutation();
    try{
      final id=_id;
      if(id==null){_id=await widget.service.create('Admin support','none',body);}
      else{await widget.service.reply(id,body);}
      if(!mounted)return;
      _body.clear();
    }catch(_){
      _notice('মেসেজ পাঠানো নিশ্চিত হয়নি। রিফ্রেশ করে দেখুন।','Message not confirmed. Refresh before trying again.');
    }finally{
      if(mounted){setState(()=>_busy=false);await _load();_bottom();}
    }
  }

  Future<bool> _confirm(bool all) async=>await showDialog<bool>(
    context:context,builder:(dialog)=>AlertDialog(
      title:Text(all?_tr('কথোপকথন মুছুন','Delete conversation'):_tr('মেসেজ মুছুন','Delete message')),
      content:Text(_tr('শুধু আপনার চ্যাট থেকে মুছে যাবে। অ্যাডমিনের কাছে মেসেজ সংরক্ষিত থাকবে।',
        'Removed only from your chat. The admin retains the messages.')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog,false),child:Text(_tr('বাতিল','Cancel'))),
        TextButton(onPressed:()=>Navigator.pop(dialog,true),child:Text(_tr('মুছুন','Delete'))),
      ]))??false;

  Future<void> _hide({String? messageId}) async{
    final id=_id;
    if(id==null||_busy||!await _confirm(messageId==null)||!mounted||_busy)return;
    _beginMutation();
    try{
      if(messageId==null){
        await widget.service.hideThread(id);
        if(mounted)Navigator.pop(context);
      }else{
        await widget.service.hideMessage(id,messageId);
        if(mounted)setState(()=>_messages.remove(messageId));
      }
    }catch(_){_notice('মুছে ফেলা নিশ্চিত হয়নি। আবার চেষ্টা করুন।','Deletion not confirmed. Try again.');}
    finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _actions(Map<String,dynamic> row) async{
    if(_busy)return;
    final action=await showModalBottomSheet<String>(context:context,builder:(sheet)=>SafeArea(
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        ListTile(leading:const Icon(Icons.copy_outlined),title:Text(_tr('মেসেজ কপি করুন','Copy message')),
          onTap:()=>Navigator.pop(sheet,'copy')),
        ListTile(leading:Icon(Icons.delete_outline,color:Theme.of(context).colorScheme.error),
          title:Text(_tr('আমার জন্য মুছুন','Delete for me')),
          onTap:()=>Navigator.pop(sheet,'delete')),
      ])));
    if(!mounted)return;
    if(action=='copy'){
      await Clipboard.setData(ClipboardData(text:row['body'].toString()));
      _notice('কপি হয়েছে','Copied');
    }else if(action=='delete'){await _hide(messageId:row['id'].toString());}
  }

  void _info()=>showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
    title:Text(_tr('সহায়তা সম্পর্কে','About support')),
    content:Text(_tr(_warning,'Do not share PINs, OTPs, passwords or card details. This is support, not a payment channel.')),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:Text(_tr('বন্ধ করুন','Close')))]));

  Widget _bubble(Map<String,dynamic> row){
    final own=row['sender']=='user';
    final colors=Theme.of(context).colorScheme;
    final stamp=_dhakaTime(row['created_at']);
    final time=stamp==null?'':MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(stamp));
    return Align(alignment:own?Alignment.centerRight:Alignment.centerLeft,
      child:GestureDetector(onLongPress:()=>_actions(row),child:Semantics(
        onLongPress:()=>_actions(row),
        child:Container(
          constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width*.78),
          margin:const EdgeInsets.symmetric(vertical:3),
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
          decoration:BoxDecoration(color:own?colors.primaryContainer:colors.surfaceContainerHigh,
            borderRadius:BorderRadius.circular(16)),
          child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            if(!own)Text(_tr('অ্যাডমিন','Admin'),style:TextStyle(fontSize:10,fontWeight:FontWeight.w400,color:colors.onSurfaceVariant)),
            Text(row['body'].toString(),style:TextStyle(fontSize:14,fontWeight:FontWeight.w400,
              color:own?colors.onPrimaryContainer:colors.onSurface)),
            if(time.isNotEmpty)Align(alignment:Alignment.centerRight,widthFactor:1,
              child:Text(time,style:TextStyle(fontSize:10,fontWeight:FontWeight.w400,
                color:own?colors.onPrimaryContainer:colors.onSurfaceVariant))),
          ]),
        ),
      )));
  }

  Widget _chat(){
    final rows=_messages.values.toList()..sort((a,b)=>
      int.parse(a['id'].toString()).compareTo(int.parse(b['id'].toString())));
    if(rows.isEmpty&&_loading)return const Center(child:CircularProgressIndicator());
    if(rows.isEmpty&&_error)return Center(child:OutlinedButton(
      onPressed:()=>_load(),child:Text(_tr('আবার চেষ্টা করুন','Try again'))));
    if(rows.isEmpty)return Center(child:Text(_tr('মেসেজ লিখে কথা শুরু করুন','Start a conversation')));
    final items=<Widget>[];
    DateTime? previous;
    final today=DateTime.now().toUtc().add(const Duration(hours:6));
    for(final row in rows){
      final date=_dhakaTime(row['created_at']);
      if(date!=null&&(previous==null||!_sameDay(previous,date))){
        items.add(Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Center(child:Text(
          _sameDay(date,today)?_tr('আজ','Today'):MaterialLocalizations.of(context).formatMediumDate(date),
          style:Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight:FontWeight.w400)))));
      }
      previous=date;
      items.add(_bubble(row));
    }
    return ListView(controller:_scroll,reverse:true,padding:const EdgeInsets.all(12),
      children:[
        ...items.reversed,
        if(_before!=null)TextButton(onPressed:_olderLoading||_busy?null:()=>_load(older:true),
          child:Text(_tr('পুরোনো মেসেজ','Older messages'))),
        if(_error)TextButton(onPressed:()=>_load(),child:Text(_tr('আবার চেষ্টা করুন','Try again'))),
      ]);
  }

  Widget _composer(){
    if(_statusCode=='closed')return Padding(padding:const EdgeInsets.all(12),
      child:Text(_tr('কথোপকথন বন্ধ। নতুন মেসেজ শুরু করুন।','Conversation closed. Start a new message.')));
    return Padding(padding:const EdgeInsets.fromLTRB(12,6,12,8),child:Row(
      crossAxisAlignment:CrossAxisAlignment.end,children:[
        Expanded(child:TextField(controller:_body,enabled:!_busy,maxLength:2000,
          minLines:1,maxLines:4,onChanged:(_)=>setState((){}),
          style:const TextStyle(fontSize:14,fontWeight:FontWeight.w400),
          decoration:InputDecoration(hintText:_tr('মেসেজ লিখুন...','Write a message...'),
            counterText:'',isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(24))))),
        const SizedBox(width:8),
        IconButton.filled(tooltip:_tr('পাঠান','Send'),onPressed:_busy||_body.text.trim().isEmpty?null:_send,
          icon:_busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):
            const Icon(Icons.send_rounded,size:20)),
      ]));
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(toolbarHeight:56,titleSpacing:4,
      title:Row(children:[
        const Icon(Icons.support_agent_rounded,size:24),
        const SizedBox(width:8),
        Expanded(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(_tr('অ্যাডমিন সাপোর্ট','Admin support'),maxLines:1,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:16,fontWeight:FontWeight.w500)),
          if(_id!=null)Text(_supportStatus(context,_statusCode),maxLines:1,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:11,fontWeight:FontWeight.w400)),
        ])),
      ]),
      actions:[PopupMenuButton<String>(tooltip:_tr('আরও','More'),onSelected:(value){
        if(value=='refresh')_load();
        if(value=='delete')_hide();
        if(value=='info')_info();
      },itemBuilder:(_)=>[
        if(_id!=null)PopupMenuItem(value:'refresh',enabled:!_busy,child:Text(_tr('রিফ্রেশ','Refresh'))),
        if(_id!=null)PopupMenuItem(value:'delete',enabled:!_busy,child:Text(_tr('কথোপকথন মুছুন','Delete conversation'))),
        PopupMenuItem(value:'info',child:Text(_tr('তথ্য','Info'))),
      ])]),
    body:SafeArea(top:false,child:Column(children:[
      Expanded(child:_chat()),const Divider(height:1),_composer(),
    ])),
  );
}
