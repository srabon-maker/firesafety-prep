import 'package:flutter_test/flutter_test.dart';
import '../lib/services/mock_interview_evaluator.dart';

void main() {
  test('exact English sample answer gets full sample-match indicator', () {
    const sample =
        'Fire extinguisher inspection checks pressure gauge, seal, hose, pin and expiry date.';
    final result = MockInterviewEvaluation.evaluate(
      answer: sample,
      sampleAnswer: sample,
    );

    expect(result.available, isTrue);
    expect(result.score, 100);
    expect(result.matchedTerms, isNotEmpty);
    expect(result.missingTerms, isEmpty);
  });

  test('Bengali answer terms are compared locally', () {
    const sample =
        'অগ্নিনির্বাপক যন্ত্রের চাপ, সিল, হোস, পিন এবং মেয়াদ পরীক্ষা করতে হবে।';
    final result = MockInterviewEvaluation.evaluate(
      answer: sample,
      sampleAnswer: sample,
    );

    expect(result.available, isTrue);
    expect(result.score, 100);
  });

  test('empty answer cannot be evaluated', () {
    final result = MockInterviewEvaluation.evaluate(
      answer: '   ',
      sampleAnswer: 'Fire extinguisher inspection checks pressure and seal.',
    );

    expect(result.available, isFalse);
    expect(result.score, 0);
  });

  test('missing sample answer does not invent an evaluation', () {
    final result = MockInterviewEvaluation.evaluate(
      answer: 'I inspect the equipment carefully.',
      sampleAnswer: '',
    );

    expect(result.available, isFalse);
    expect(result.feedback, contains('নমুনা উত্তর নেই'));
  });

  test('partial answer reports missing sample terms', () {
    final result = MockInterviewEvaluation.evaluate(
      answer: 'Check pressure gauge and seal.',
      sampleAnswer:
          'Check pressure gauge, seal, hose, pin, safety tag and expiry date.',
    );

    expect(result.available, isTrue);
    expect(result.score, lessThan(100));
    expect(result.missingTerms, isNotEmpty);
  });
}
