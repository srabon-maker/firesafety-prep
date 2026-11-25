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
}
