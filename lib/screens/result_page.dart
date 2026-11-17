import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {

  final int score;
  final int total;

  const ResultPage({
    super.key,
    required this.score,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {

    double percent =
        (score / total) * 100;

    return Scaffold(

      appBar: AppBar(
        title: const Text("ফলাফল"),
      ),

      body: Center(

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            Text(
              "$score / $total",
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "${percent.toStringAsFixed(0)}%",
              style: const TextStyle(
                fontSize: 28,
              ),
            ),

          ],
        ),
      ),
    );
  }
}
