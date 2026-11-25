import 'package:flutter/material.dart';
import '../services/premium_service.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});
  @override
  State<PremiumPage> createState()=>_PremiumPageState();
}
class _PremiumPageState extends State<PremiumPage> {
  late final _service=PremiumService();
  late Future<Map<String,dynamic>> _future=_service.status();
  void _refresh()=>setState(()=>_future=_service.status());
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Fire Safety BD Premium'),actions:[
      IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh),tooltip:'রিফ্রেশ'),
    ]),
    body:FutureBuilder<Map<String,dynamic>>(future:_future,builder:(context,snapshot){
      if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError||!snapshot.hasData)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('সদস্যপদের তথ্য লোড হয়নি। লগইন ও সংযোগ পরীক্ষা করুন।',textAlign:TextAlign.center),
        OutlinedButton(onPressed:_refresh,child:const Text('আবার চেষ্টা করুন')),
      ])));
      final data=snapshot.data!;
      final active=data['premium']==true;
      final expiry=DateTime.tryParse(data['expires_at']?.toString()??'')?.toLocal();
      final plans=(data['plans'] as List? ?? []).whereType<Map>();
      return ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(
          gradient:const LinearGradient(colors:[Color(0xFF450B15),Color(0xFF8B263C)]),borderRadius:BorderRadius.circular(22)),
          child:Column(children:[
            const Icon(Icons.workspace_premium_outlined,color:Color(0xFFFFD166),size:54),
            const SizedBox(height:10),
            Text(active?'Premium সদস্যপদ সক্রিয়':'Free Membership',textAlign:TextAlign.center,
              style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold)),
            if(active&&expiry!=null)Text('মেয়াদ: ${expiry.toString().split('.').first}',style:const TextStyle(color:Colors.white)),
            const SizedBox(height:8),
            const Text('পেশাগত প্রস্তুতির জন্য উন্নত শেখার সুবিধা',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70)),
          ])),
        const SizedBox(height:18),
        const ListTile(leading:Icon(Icons.check_circle_outline),title:Text('চিহ্নিত Premium ইন্টারভিউ প্রশ্নের সম্পূর্ণ উত্তর')),
        const ListTile(leading:Icon(Icons.info_outline),title:Text('প্রশ্ন ব্যাংক, স্টাডি নোট ও মডেল টেস্টের অতিরিক্ত Premium সুবিধা পরবর্তী ধাপে আসবে।')),
        const SizedBox(height:12),
        Text('পরিকল্পিত প্যাকেজ',style:Theme.of(context).textTheme.titleLarge),
        for(final p in plans) Card(child:ListTile(
          leading:const Icon(Icons.workspace_premium),
          title:Text('${p['months']} মাস'),
          subtitle:const Text('প্রস্তাবিত মূল্য • এখন কেনা যাবে না'),
          trailing:Text('৳${p['proposed_price_bdt']}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        )),
        const Padding(padding:EdgeInsets.all(12),child:Text('Google Play-এর পেমেন্ট ব্যবস্থা চালু হলে চূড়ান্ত দাম ও কেনার অপশন দেখানো হবে। এখন কোনো পেমেন্ট নেওয়া হচ্ছে না।')),
      ]);
    }),
  );
}
