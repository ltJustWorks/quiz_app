// quiz_result_screen.dart
import 'package:flutter/material.dart';

class QuizResultScreen extends StatelessWidget {
  final int score;
  final int total;

  const QuizResultScreen({super.key, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Results")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Your Score",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              "$score / $total",
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back to Quizzes"),
            ),
          ],
        ),
      ),
    );
  }
}
