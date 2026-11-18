import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/utils/job_notice_sections.dart';

void main() {
  test('parses a Bdjobs-style notice into separate readable sections', () {
    const notice = '''
Requirements

Education

Bachelor/Honors
Must have completed a six-month Fire Safety Training Course.

Experience

5 to 10 years
Garments, Textile

Additional Requirements

Age 25 to 35 years
Only Male

Responsibilities & Context

Ensure compliance with fire safety regulations.
Conduct regular fire drills.

Skills & Expertise
Communication
Fire Safety

Other Relevant Skills
Incident Management

Compensation & Other Benefits

Mobile bill
Salary Review: Yearly
Festival Bonus: 2

Workplace

Work at office

Employment Status

Full Time

Gender

Only males are allowed to apply.

Job Location

Gazipur (Sreepur)
''';

    final sections = JobNoticeParser.parse(notice);
    expect(sections.map((s) => s.key), containsAll([
      'education',
      'experience',
      'additionalRequirements',
      'responsibilities',
      'skills',
      'otherSkills',
      'benefits',
      'workplace',
      'employmentStatus',
      'gender',
      'jobLocation',
    ]));
    expect(JobNoticeParser.firstValue(sections, 'jobLocation'),
        'Gazipur (Sreepur)');
    expect(JobNoticeParser.firstValue(sections, 'employmentStatus'),
        'Full Time');
    expect(JobNoticeParser.firstValue(sections, 'workplace'),
        'Work at office');
    expect(sections.firstWhere((s) => s.key == 'benefits').content,
        contains('Salary Review: Yearly'));
    expect(sections.firstWhere((s) => s.key == 'education').content,
        contains('six-month Fire Safety Training Course'));
    expect(sections.firstWhere((s) => s.key == 'responsibilities').content,
        contains('Conduct regular fire drills.'));
    expect(sections.any((s) => s.content == 'Requirements'), isFalse);
  });

  test('supports inline headings without inventing missing fields', () {
    final sections = JobNoticeParser.parse(
      'Education: Bachelor/Honors\nJob Location: Dhaka\n'
      'Employment Status: Full Time',
    );
    expect(JobNoticeParser.firstValue(sections, 'education'),
        'Bachelor/Honors');
    expect(JobNoticeParser.firstValue(sections, 'jobLocation'), 'Dhaka');
    expect(JobNoticeParser.firstValue(sections, 'employmentStatus'),
        'Full Time');
    expect(JobNoticeParser.firstValue(sections, 'benefits'), isNull);
  });

  test('keeps unstructured notices as a single overview section', () {
    final sections = JobNoticeParser.parse(
      'This is a short notice.\nApply after checking the official circular.',
    );
    expect(sections, hasLength(1));
    expect(sections.single.key, 'overview');
    expect(sections.single.content, contains('official circular'));
  });

  test('empty notice has no sections', () {
    expect(JobNoticeParser.parse('  \n  '), isEmpty);
  });
}
