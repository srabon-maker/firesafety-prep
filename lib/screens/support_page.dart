import 'package:flutter/material.dart';
import '../services/support_service.dart';
import '../settings/app_settings.dart';

const _status={'open':'উত্তরের অপেক্ষায়','answered':'উত্তর দেওয়া হয়েছে','closed':'বন্ধ'};
const _plans={'none':'নির্দিষ্ট নয়','monthly':'মাসিক','quarterly':'ত্রৈমাসিক','annual':'বার্ষিক'};
const _warning='PIN, OTP, পাসওয়ার্ড বা কার্ডের তথ্য পাঠাবেন না। এটি সহায়তা, পেমেন্ট গ্রহণের মাধ্যম নয়।';
class SupportPage extends StatefulWidget{
  const SupportPage({super.key, this.generalSupport = false});
  final bool generalSupport;
  @override
  State<SupportPage> createState()=>_SupportPageState();
}
class _SupportPageState extends State<SupportPage>{
  late final _service=SupportService();
  int _page=1;
  late Future<Map<String,dynamic>> _data=_service.tickets(_page);
  void _load([int? page])=>setState((){_page=page??_page;_data=_service.tickets(_page);});
  Future<void> _open(String id) async{
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>_SupportThread(service:_service,id:id)));
    if(mounted)_load();
  }
  Future<void> _compose() async{
    final id=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>_SupportCompose(service:_service,generalSupport:widget.generalSupport)));
    if(!mounted)return;
    if(id!=null){_load(1);await _open(id);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.generalSupport ? AppText.of(context,'অ্যাডমিন সাপোর্ট','Admin support') : 'পেমেন্ট ও সদস্যপদ সহায়তা'),actions:[IconButton(onPressed:()=>_load(),icon:const Icon(Icons.refresh),tooltip:'রিফ্রেশ')]),
    body:FutureBuilder<Map<String,dynamic>>(future:_data,builder:(context,snapshot){
      final data=snapshot.connectionState==ConnectionState.waiting?null:snapshot.data;
      final rows=(data?['data'] as List? ?? []).whereType<Map>();
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
