import 'dart:convert';

import 'package:fire_safety_job_prep/screens/support_page.dart';
import 'package:fire_safety_job_prep/services/support_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main(){
  testWidgets('General support hides subject, sends message, hides locally and removes thread',
      (tester) async {
    var exists=false;
    var hidden=false;
    var hiddenThread=false;
    final calls=<String>[];
    final client=MockClient((r) async{
      Map<String,dynamic> result={'success':true};
      if(r.method=='POST'){
        final body=jsonDecode(r.body) as Map;
        final action=body['action'].toString();
        calls.add(action);
        if(action=='create'){
          expect(body['subject'],'Admin support');
          expect(body['plan_code'],'none');
          expect(body['message'],'Hello');
          exists=true;
          result['ticket_id']='42';
        }else if(action=='hide_message'){
          expect(body['ticket_id'],'42');
          expect(body['message_id'],'1');
          hidden=true;
        }else if(action=='hide_thread'){
          expect(body['ticket_id'],'42');
          hiddenThread=true;
        }
      }else if(r.url.queryParameters.containsKey('ticket_id')){
        result['ticket']={'id':'42','subject':'Old subject','status':'open'};
        result['messages']=[
          if(!hidden){'id':'1','sender':'user','body':'Hello','created_at':'2026-11-28 12:00:00'},
          {'id':'2','sender':'admin','body':'Admin reply','created_at':'2026-11-28 12:01:00'},
        ];
        result['next_before_id']=null;
      }else{
        result['data']=[
          if(exists&&!hiddenThread){'id':'42','subject':'Old subject','status':'open','last_message':'Admin reply'},
        ];
        result['has_more']=false;
      }
      return http.Response(jsonEncode(result),200,headers:{'content-type':'application/json'});
    });
    final service=SupportService(currentToken:()async=>'test',client:client);
    await tester.pumpWidget(MaterialApp(locale:const Locale('en'),
      supportedLocales:const [Locale('bn'),Locale('en')],
      localizationsDelegates:GlobalMaterialLocalizations.delegates,
      home:SupportPage(generalSupport:true,service:service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New message'));
    await tester.pumpAndSettle();
    expect(find.text('Old subject'),findsNothing);
    expect(find.byType(TextField),findsOneWidget);
    expect(find.textContaining('PIN'),findsNothing);
    await tester.enterText(find.byType(TextField),'Hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'),findsOneWidget);
    expect(find.text('Admin reply'),findsOneWidget);
    expect(find.text('Old subject'),findsNothing);
    expect(find.textContaining('UTC'),findsNothing);
    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(find.text('Delete for everyone'),findsNothing);
    await tester.tap(find.text('Delete for me'));
    await tester.pumpAndSettle();
    expect(find.textContaining('admin retains'),findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'),findsNothing);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'),findsNothing);
    expect(find.text('Admin reply'),findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete conversation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No conversations'),findsOneWidget);
    expect(calls,['create','hide_message','hide_thread']);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(),isNull);
  });
}
