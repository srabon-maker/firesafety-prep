/// A transparent, local-only practice indicator.
///
/// This is deliberately not labelled AI: it compares answer terms with the
/// published sample answer and checks response length. It cannot verify facts,
/// reasoning quality, or professional competence.
class MockInterviewEvaluation {
  const MockInterviewEvaluation({
    required this.available,
    required this.score,
    required this.answerWordCount,
    required this.matchedTerms,
    required this.missingTerms,
    required this.feedback,
  });

  final bool available;
  final int score;
  final int answerWordCount;
  final List<String> matchedTerms;
  final List<String> missingTerms;
  final String feedback;

  static const _stopWords = <String>{
    'the','and','for','with','that','this','from','have','has','had','are',
    'was','were','will','would','should','could','can','may','might','into',
    'about','after','before','when','where','what','which','who','why','how',
    'then','than','their','there','they','them','your','you','our','its',
    'also','such','very','more','most','some','any','all','not','but','use',
    'used','using','need','needs','must','shall','being','been','each',
    'একটি','এবং','অথবা','করে','হবে','হয়','হয়','করা','জন্য','থেকে','দিকে',
    'সাথে','এটি','এটা','যা','যে','এই','তার','তাদের','আমাদের','আপনার',
    'কোনো','কোন','সব','আর','তবে','কিন্তু','হলে','হয়েছে','হয়েছে',
    'করতে','হিসেবে','মধ্যে','উপর','নিয়ে','নিয়ে','থাকে','থাকতে',
  };

  static List<String> _tokens(String value) {
    return RegExp(r'[A-Za-z0-9\u0980-\u09FF]+')
        .allMatches(value.toLowerCase())
        .map((match) => match.group(0)!)
        .where((word) => word.length > 1 && !_stopWords.contains(word))
        .toList();
  }

  static MockInterviewEvaluation evaluate({
    required String answer,
    required String sampleAnswer,
  }) {
    final answerWords = _tokens(answer);
    final expected = _tokens(sampleAnswer).toSet().toList();
    if (answerWords.isEmpty) {
      return const MockInterviewEvaluation(
        available: false,
        score: 0,
        answerWordCount: 0,
        matchedTerms: [],
        missingTerms: [],
        feedback: 'আগে নিজের উত্তর লিখুন অথবা ভয়েসে বলুন।',
      );
    }
    if (expected.isEmpty) {
      return MockInterviewEvaluation(
        available: false,
        score: 0,
        answerWordCount: answerWords.length,
        matchedTerms: const [],
        missingTerms: const [],
        feedback: 'এই প্রশ্নের নমুনা উত্তর নেই, তাই মিল সূচক তৈরি করা যায়নি।',
      );
    }

    final answerSet = answerWords.toSet();
    final matched = expected.where(answerSet.contains).toList();
    final missing = expected.where((word) => !answerSet.contains(word)).toList();
    final coverage = matched.length / expected.length;
    final targetWords = (expected.length * 0.65).round().clamp(5, 45).toInt();
    final lengthCoverage = (answerWords.length / targetWords).clamp(0.0, 1.0);
    final score = (coverage * 75 + lengthCoverage * 25).round().clamp(0, 100).toInt();

    final feedback = score >= 80
        ? 'নমুনা উত্তরের সঙ্গে ভালো শব্দ ও বিষয়গত মিল পাওয়া গেছে। তথ্যগুলো নিজে যাচাই করুন।'
        : score >= 55
            ? 'কিছু গুরুত্বপূর্ণ বিষয়ের মিল পাওয়া গেছে। বাদ পড়া বিষয়গুলো নমুনা উত্তরের সঙ্গে মিলিয়ে দেখুন।'
            : 'উত্তরে আরও প্রাসঙ্গিক বিষয় যোগ করুন এবং নমুনা উত্তরটি পড়ে অনুশীলন করুন।';

    return MockInterviewEvaluation(
      available: true,
      score: score,
      answerWordCount: answerWords.length,
      matchedTerms: matched.take(8).toList(),
      missingTerms: missing.take(8).toList(),
      feedback: feedback,
    );
  }
}
