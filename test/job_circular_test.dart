import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/job_circular.dart';
import 'package:fire_safety_job_prep/services/job_circular_service.dart';

void main() {
  Map<String, dynamic> job({
    dynamic deadline = '2099-12-31',
    String jobType = 'government',
    String? applyUrl = 'https://example.org/apply',
  }) =>
      {
        'id': 12,
        'organization': 'Example Organization',
        'title': 'Fire Safety Officer',
        'job_type': jobType,
        'location': 'Dhaka',
        'published_at': '2026-11-18T10:30:00',
        'application_deadline': deadline,
        'apply_url': applyUrl,
        'circular_url': 'https://example.org/circular.pdf',
      };

  test('parses live job fields and official HTTPS links', () {
    final circulars = JobCircularService.parseResponse({
      'success': true,
      'data': [job()],
    });
    final circular = circulars.single;
    expect(circular.id, 12);
    expect(circular.organization, 'Example Organization');
    expect(circular.isGovernment, isTrue);
    expect(circular.isExpired, isFalse);
    expect(circular.applyUrl, 'https://example.org/apply');
    expect(circular.circularUrl, 'https://example.org/circular.pdf');
  });

  test('expired jobs are identified by calendar day', () {
    final expired = JobCircular.fromJson(job(deadline: '2020-01-01'));
    expect(expired.isExpired, isTrue);
    final unknown = JobCircular.fromJson(job(deadline: null));
    expect(unknown.isExpired, isFalse);
    expect(unknown.deadline, isNull);
  });

  test('rejects unsafe apply and circular URLs', () {
    final circular = JobCircular.fromJson({
      ...job(applyUrl: 'javascript:alert(1)', jobType: 'private'),
      'circular_url': 'http://example.org/circular.pdf',
    });
    expect(circular.isGovernment, isFalse);
    expect(circular.applyUrl, isNull);
    expect(circular.circularUrl, isNull);
  });

  test('rejects missing job identity and invalid deadlines', () {
    expect(
      () => JobCircular.fromJson({...job(), 'title': ''}),
      throwsFormatException,
    );
    expect(
      () => JobCircular.fromJson({...job(), 'application_deadline': 'soon'}),
      throwsFormatException,
    );
  });

  test('never shows fabricated data for missing or malformed API lists', () {
    expect(
      JobCircularService.parseResponse({'success': true, 'data': []}),
      isEmpty,
    );
    expect(
      () => JobCircularService.parseResponse({'success': true, 'data': null}),
      throwsFormatException,
    );
    expect(
      () => JobCircularService.parseResponse({
        'success': false,
        'message': 'Unavailable',
      }),
      throwsFormatException,
    );
  });
}
