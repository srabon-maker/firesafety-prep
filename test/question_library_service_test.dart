import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fire_safety_job_prep/services/question_library_service.dart';

void main(){
  test('search and note filters are encoded, and request is authenticated',() async {
    final client=MockClient((request) async {
      expect(request.headers['Authorization'],'Bearer test-token');
      expect(request.url.queryParameters['search'],'Fire & Safety');
      expect(request.url.queryParameters['category'],'Fire');
      expect(request.url.queryParameters['difficulty'],'hard');
      expect(request.url.queryParameters['saved'],'1');
      expect(request.url.queryParameters['page'],'2');
      expect(request.url.queryParameters['note_id'],'12');
      return http.Response('{"success":true,"data":[],"has_more":false}',200);
    });
    final service=QuestionLibraryService(currentToken:() async=>'test-token',client:client);
    final result=await service.fetch(search:'Fire & Safety',category:'Fire',difficulty:'hard',saved:true,page:2,noteId:12);
    expect(result['data'],isEmpty);
  });
  test('bookmark uses explicit idempotent state, never user id',() async {
    final client=MockClient((request) async{
      expect(request.method,'POST');
      expect(jsonDecode(request.body),{'action':'bookmark','id':'9','saved':true});
      return http.Response('{"success":true,"saved":true}',200);
    });
    await QuestionLibraryService(currentToken:() async=>'test-token',client:client).bookmark('9',true);
  });
  test('rejects a response if the account changes during request',() async{
    String? token='old';
    final client=MockClient((request) async{
      token='new';
      return http.Response('{"success":true,"data":[]}',200);
    });
    final service=QuestionLibraryService(currentToken:() async=>token,client:client);
    await expectLater(service.fetch(),throwsFormatException);
    await expectLater(service.fetch(),throwsFormatException);
  });
  test('unauthenticated or unsuccessful response is rejected',() async {
    final client=MockClient((request) async=>http.Response('{"success":false}',401));
    final service=QuestionLibraryService(currentToken:() async=>'old',client:client);
    await expectLater(service.fetch(),throwsFormatException);
  });
}
