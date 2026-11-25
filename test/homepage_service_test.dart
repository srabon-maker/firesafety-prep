import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fire_safety_job_prep/services/homepage_service.dart';

void main() {
  test('remote sections are allowlisted and ordered, with explicit empty supported', () {
    expect(HomepageService.sections(['jobs','bad','jobs','tips']), ['jobs','tips']);
    expect(HomepageService.sections([]), isEmpty);
  });
  test('banner images are restricted to first-party uploads', () {
    expect(HomepageService.safeImage('https://fire.manobikishwarganj.com/uploads/a.jpg'), isTrue);
    expect(HomepageService.safeImage('https://elsewhere.test/uploads/a.jpg'), isFalse);
    expect(HomepageService.safeImage('https://fire.manobikishwarganj.com/uploads/a.php'), isFalse);
  });
  test('interview search uses encoded query and rejects unavailable content', () async {
    final client=MockClient((request) async {
      expect(request.url.queryParameters['action'], 'interviews');
      expect(request.url.queryParameters['search'], 'Fire & Safety');
      return http.Response('{"success":true,"data":[]}',200);
    });
    final result=await HomepageService.fetch('interviews',filters:{'search':'Fire & Safety'},client:client);
    expect(result['data'],isEmpty);
    final fail=MockClient((_) async=>http.Response('{"success":false}',503));
    await expectLater(HomepageService.fetch('home',client:fail),throwsFormatException);
  });
}
