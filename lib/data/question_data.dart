import '../models/question.dart';

class QuestionData {
  static List<Question> fireQuestions = [

    Question(
      question: 'Fire Triangle এর উপাদান কয়টি?',
      options: [
        '২',
        '৩',
        '৪',
        '৫',
      ],
      correctIndex: 1,
    ),

    Question(
      question: 'NFPA 10 কোন বিষয়ের উপর?',
      options: [
        'Fire Pump',
        'Portable Extinguisher',
        'Fire Alarm',
        'Sprinkler',
      ],
      correctIndex: 1,
    ),

  ];
}
