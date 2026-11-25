import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fire_safety_job_prep/services/premium_service.dart';

void main(){
  test('membership status uses bearer and does not accept a caller-supplied user ID',() async{
    final client=MockClient((request) async{
      expect(request.url.path,'/api/premium/index.php');
      expect(request.url.queryParameters.containsKey('user_id'),false);
      expect(request.headers['Authorization'],'Bearer session');
      return http.Response('{"success":true,"premium":false,"purchase_available":false,"ads_active":false}',200);
    });
    final data=await PremiumService(currentToken:() async=>'session',client:client).status();
    expect(data['premium'],false);
    expect(data['purchase_available'],false);
    expect(data['ads_active'],false);
  });
  test('interview preview requests preserve filters but enforce action and preview',() async{
    final client=MockClient((request) async{
      expect(request.url.path,'/api/homepage/index.php');
      expect(request.url.queryParameters['action'],'interviews');
      expect(request.url.queryParameters['premium_preview'],'1');
      expect(request.url.queryParameters['search'],'Fire & Safety');
      return http.Response('{"success":true,"data":[{"id":1,"locked":true,"body":"","body_en":""}]}',200);
    });
    final data=await PremiumService(currentToken:() async=>'session',client:client).interviews({'search':'Fire & Safety','action':'home','premium_preview':'0'});
    expect(data['data'][0]['locked'],true);
    expect(data['data'][0]['body'],'');
  });
  test('a changed token rejects in-flight and future requests',() async{
    String? token='old';
    final client=MockClient((request) async{
      token='new';
      return http.Response('{"success":true,"premium":true}',200);
    });
    final service=PremiumService(currentToken:() async=>token,client:client);
    await expectLater(service.status(),throwsFormatException);
    await expectLater(service.status(),throwsFormatException);
  });
  test('missing login cannot request membership',() async{
    final client=MockClient((request) async=>throw StateError('unexpected network request'));
    await expectLater(PremiumService(currentToken:() async=>null,client:client).status(),throwsFormatException);
  });
}
