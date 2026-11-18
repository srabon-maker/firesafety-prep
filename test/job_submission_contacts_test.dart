import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/job_circular.dart';

void main() {
  final sample = <String, dynamic>{
    'id': 2,
    'title': 'Fire Safety Officer',
    'organization': 'Example Garments',
    'published_at': '2026-11-18T09:43:29',
    'description': 'Education\nBachelor/Honors',
  };

  test('approved job exposes opt-in mobile and WhatsApp numbers', () {
    final job = JobCircular.fromJson({
      ...sample,
      'contact_mobile': '01712345678',
      'contact_whatsapp': '+8801712345678',
    });
    expect(job.contactMobile, '01712345678');
    expect(job.contactWhatsapp, '+8801712345678');
  });

  test('jobs without consent never expose missing contacts', () {
    final job = JobCircular.fromJson({
      ...sample,
      'contact_mobile': null,
      'contact_whatsapp': null,
    });
    expect(job.contactMobile, isNull);
    expect(job.contactWhatsapp, isNull);
  });

  test('invalid contact fields are ignored', () {
    final job = JobCircular.fromJson({
      ...sample,
      'contact_mobile': '<script>alert(1)</script>',
      'contact_whatsapp': 'not-a-number',
    });
    expect(job.contactMobile, isNull);
    expect(job.contactWhatsapp, isNull);
  });
}
