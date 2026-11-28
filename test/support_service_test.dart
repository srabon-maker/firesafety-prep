import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fire_safety_job_prep/services/support_service.dart';
void main(){
 test('create uses authenticated account and never sends user ID',() async{
  final client=MockClient((r) async{expect(r.headers['Authorization'],'Bearer token');expect(jsonDecode(r.body),{'action':'create','subject':'Help','plan_code':'monthly','message':'Question'});return http.Response('{"success":true,"ticket_id":"42"}',200);});
  expect(await SupportService(currentToken:()async=>'token',client:client).create('Help','monthly','Question'),'42');
 });
 test('thread is scoped to requested ticket, rejects unauthorized response',()async{
  final client=MockClient((r)async{expect(r.url.queryParameters['ticket_id'],'42');return http.Response('{"success":false}',404);});
  await expectLater(SupportService(currentToken:()async=>'token',client:client).thread('42'),throwsFormatException);
 });
 test('account switch discards response',()async{
  String? token='one';
  final client=MockClient((r)async{token='two';return http.Response('{"success":true,"data":[]}',200);});
  await expectLater(SupportService(currentToken:()async=>token,client:client).tickets(1),throwsFormatException);
 });
 test('hide requests contain only owned ticket/message IDs and bearer auth',() async{
  final requests=<Map<String,dynamic>>[];
  final client=MockClient((r) async{
    expect(r.headers['Authorization'],'Bearer token');
    requests.add(Map<String,dynamic>.from(jsonDecode(r.body) as Map));
    return http.Response('{"success":true}',200);
  });
  final service=SupportService(currentToken:() async=>'token',client:client);
  await service.hideMessage('42','7');
  await service.hideThread('42');
  expect(requests,[
    {'action':'hide_message','ticket_id':'42','message_id':'7'},
    {'action':'hide_thread','ticket_id':'42'},
  ]);
 });
 test('failed hide does not report success',() async{
  final client=MockClient((r) async=>http.Response('{"success":false}',404));
  await expectLater(SupportService(currentToken:()async=>'token',client:client)
    .hideThread('42'),throwsFormatException);
 });
}
