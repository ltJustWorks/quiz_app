// quiz_result_screen.dart
import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../models/quiz_session_state.dart';
import '../services/quiz_session_storage_service.dart';
import 'quiz_play_screen.dart';

class QuizResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final String elapsedTime;
  final Quiz quiz;
  final QuizSessionState sessionState;

  const QuizResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.elapsedTime,
    required this.quiz,
    required this.sessionState,
  });

  Future<void> _redoQuiz(BuildContext context) async {
    final restartedSession = sessionState.restarted();
    await QuizSessionStorageService().saveSession(restartedSession);

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => QuizPlayScreen(
              quiz: quiz,
              initialSessionState: restartedSession,
            ),
      ),
    );
  }

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
            const SizedBox(height: 12),
            Text(
              'Completed in $elapsedTime',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _redoQuiz(context),
              child: const Text("Redo Quiz"),
            ),
            const SizedBox(height: 12),
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
