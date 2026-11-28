import 'dart:convert';
import 'package:fire_safety_job_prep/screens/support_page.dart';
import 'package:fire_safety_job_prep/services/support_service.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main(){
  for(final mode in [ThemeMode.dark,ThemeMode.light]){
    testWidgets('Payment support list is compact and preserves navigation in $mode',(tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=const Size(360,800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final pages=<String>[];
      final client=MockClient((r)async{
        final page=r.url.queryParameters['page'];
        if(page!=null)pages.add(page);
        final result=<String,dynamic>{'success':true};
        if(r.url.queryParameters.containsKey('ticket_id')){
          result['ticket']={'id':'42','subject':'Sample ticket','status':'open'};
          result['messages']=[];
        }else{
          result['data']=[
            {'id':'42','subject':'Sample ticket','status':'open','plan_code':'none'},
            {'id':'43','subject':'Membership','status':'answered','plan_code':'monthly'},
          ];
          result['has_more']=page=='2';
        }
        return http.Response(jsonEncode(result),200,headers:{'content-type':'application/json'});
      });
      addTearDown(client.close);
      final service=SupportService(currentToken:()async=>'test',client:client);
      await tester.pumpWidget(MaterialApp(theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,
        themeMode:mode,home:SupportPage(service:service)));
      await tester.pumpAndSettle();
      final title=tester.widget<Text>(find.byKey(const ValueKey('payment-support-title')));
      expect(title.data,'পেমেন্ট সহায়তা');
      expect(title.semanticsLabel,'পেমেন্ট ও সদস্যপদ সহায়তা');
      expect(title.style?.fontSize,15.5);
      final warning=find.descendant(of:find.byKey(const ValueKey('payment-support-warning')),
        matching:find.byType(Text));
      expect(tester.widget<Text>(warning).data,
        'PIN, OTP, পাসওয়ার্ড বা কার্ডের তথ্য পাঠাবেন না। এটি সহায়তা, পেমেন্ট গ্রহণের মাধ্যম নয়।');
      expect(tester.widget<Text>(warning).style?.fontSize,11);
      final button=tester.widget<FilledButton>(find.byKey(const ValueKey('payment-support-compose')));
      expect(button.style?.minimumSize?.resolve({}),const Size(48,44));
      expect(tester.widget<Text>(find.text('Sample ticket')).style?.fontSize,14);
      expect(tester.widget<Text>(find.text('উত্তরের অপেক্ষায়')).style?.fontSize,10);
      expect(find.text('মাসিক'),findsOneWidget);
      expect(find.text('নির্দিষ্ট নয়'),findsNothing);
      expect(find.byKey(const ValueKey('payment-support-pagination')),findsNothing);
      await tester.tap(find.text('নতুন মেসেজ'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField),findsNWidgets(2));
      expect(find.text('প্যাকেজ (ঐচ্ছিক)'),findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sample ticket'));
      await tester.pumpAndSettle();
      expect(find.text('অ্যাডমিনের সঙ্গে কথোপকথন'),findsOneWidget);
      expect(find.byType(TextField),findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(pages,isNotEmpty);
      expect(tester.takeException(),isNull);
    });
  }

  testWidgets('Payment support pagination remains available across pages',(tester)async{
    final pages=<String>[];
    final client=MockClient((r)async{
      final page=r.url.queryParameters['page']!;
      pages.add(page);
      return http.Response(jsonEncode({'success':true,'data':[],'has_more':page=='1'}),200);
    });
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home:SupportPage(service:
      SupportService(currentToken:()async=>'test',client:client))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-support-pagination')),findsOneWidget);
    await tester.tap(find.text('পরের পেজ'));
    await tester.pumpAndSettle();
    expect(pages,['1','2']);
    expect(find.byKey(const ValueKey('payment-support-pagination')),findsOneWidget);
    await tester.tap(find.text('আগের পেজ'));
    await tester.pumpAndSettle();
    expect(pages,['1','2','1']);
    expect(tester.takeException(),isNull);
  });
}
