import 'package:flutter/material.dart';
import '../data/question_data.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {

  int currentQuestion = 0;
  int score = 0;

  void answerQuestion(int selected) {

    final question =
        QuestionData.fireQuestions[currentQuestion];

    if(selected == question.correctIndex){
      score++;
    }

    if(currentQuestion <
        QuestionData.fireQuestions.length - 1){

      setState(() {
        currentQuestion++;
      });

    }else{

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            score: score,
            total:
              QuestionData.fireQuestions.length,
          ),
        ),
      );

    }
  }

  @override
  Widget build(BuildContext context) {

    final question =
        QuestionData.fireQuestions[currentQuestion];

    return Scaffold(
      appBar: AppBar(
        title: const Text("মডেল টেস্ট"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Text(
              "প্রশ্ন ${currentQuestion + 1}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              question.question,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 30),

            for(int i=0;
                i<question.options.length;
                i++)

              Container(
                margin:
                  const EdgeInsets.only(bottom: 10),

                width: double.infinity,

                child: ElevatedButton(
                  onPressed: (){
                    answerQuestion(i);
                  },

                  child: Text(
                    question.options[i],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
