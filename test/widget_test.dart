import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app/models/option.dart';
import 'package:quiz_app/models/question.dart';
import 'package:quiz_app/models/quiz.dart';
import 'package:quiz_app/models/quiz_session_state.dart';
import 'package:quiz_app/screens/quiz_list_screen.dart';

void main() {
  Quiz buildQuiz() {
    return Quiz(
      quizId: 'quiz-1',
      quizName: 'Sample Quiz',
      description: 'A short quiz.',
      folderName: 'Science',
      addedAt: DateTime(2026, 3, 26, 14, 30),
      questions: [
        QuizQuestion(
          id: 'q1',
          prompt: 'Question 1',
          options: [
            QuizOption(label: 'A', text: 'One'),
            QuizOption(label: 'B', text: 'Two'),
          ],
          correctAnswer: 'A',
          hint: 'Hint',
          explanation: 'Explanation',
        ),
        QuizQuestion(
          id: 'q2',
          prompt: 'Question 2',
          options: [
            QuizOption(label: 'A', text: 'Three'),
            QuizOption(label: 'B', text: 'Four'),
          ],
          correctAnswer: 'B',
          hint: 'Hint',
          explanation: 'Explanation',
        ),
      ],
    );
  }

  testWidgets('shows numeric progress for incomplete quizzes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizListScreen(
          initialQuizzes: [buildQuiz()],
          initialSessionStates: {
            'quiz-1': QuizSessionState(
              quizId: 'quiz-1',
              currentIndex: 1,
              score: 1,
              wrongAnswers: const [],
              correctSelected: null,
              isCompleted: false,
              lastInteractedAt: DateTime(2026),
            ),
          },
        ),
      ),
    );

    expect(find.text('In progress: 1/2'), findsOneWidget);
    expect(find.text('Added Mar 26, 2026 at 2:30 PM'), findsOneWidget);
  });

  testWidgets('shows completed status for finished quizzes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizListScreen(
          initialQuizzes: [buildQuiz()],
          initialSessionStates: {
            'quiz-1': QuizSessionState(
              quizId: 'quiz-1',
              currentIndex: 1,
              score: 2,
              wrongAnswers: const [],
              correctSelected: 'B',
              isCompleted: true,
              lastInteractedAt: DateTime(2026),
            ),
          },
        ),
      ),
    );

    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('groups quizzes under their folder names', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizListScreen(
          initialQuizzes: [buildQuiz()],
          initialSessionStates: const {},
        ),
      ),
    );

    expect(find.text('Science'), findsOneWidget);
    expect(find.text('1 quiz'), findsOneWidget);
  });
}
