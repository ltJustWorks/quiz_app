import 'package:flutter/foundation.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import '../models/quiz_session_state.dart';
import '../services/quiz_session_storage_service.dart';

class QuizController extends ChangeNotifier {
  final Quiz quiz;
  final QuizSessionStorageService sessionStorage;

  int currentIndex = 0;
  int score = 0;

  final Set<String> wrongAnswers = {};
  String? correctSelected;
  String? feedbackMessage;

  QuizController(
    this.quiz, {
    QuizSessionStorageService? sessionStorage,
    QuizSessionState? initialState,
  }) : sessionStorage = sessionStorage ?? QuizSessionStorageService() {
    if (initialState != null && initialState.quizId == quiz.quizId) {
      currentIndex = initialState.currentIndex;
      score = initialState.score;
      wrongAnswers.addAll(initialState.wrongAnswers);
      correctSelected = initialState.correctSelected;

      if (correctSelected != null) {
        feedbackMessage =
            "Correct!\n\nExplanation: ${currentQuestion.explanation}";
      } else if (wrongAnswers.isNotEmpty) {
        feedbackMessage = "Incorrect. Hint: ${currentQuestion.hint}";
      }
    }
  }

  QuizQuestion get currentQuestion => quiz.questions[currentIndex];

  bool get hasAnsweredCorrectly => correctSelected != null;

  Future<void> saveProgress() => _persistSession();

  Future<void> _persistSession() async {
    await sessionStorage.saveSession(
      QuizSessionState(
        quizId: quiz.quizId,
        currentIndex: currentIndex,
        score: score,
        wrongAnswers: wrongAnswers.toList(),
        correctSelected: correctSelected,
        isCompleted: false,
        lastInteractedAt: DateTime.now(),
      ),
    );
  }

  Future<void> selectAnswer(String label) async {
    if (hasAnsweredCorrectly) return;

    if (label == currentQuestion.correctAnswer) {
      correctSelected = label;
      score++;
      feedbackMessage =
          "Correct!\n\nExplanation: ${currentQuestion.explanation}";
    } else {
      wrongAnswers.add(label);
      feedbackMessage = "Incorrect. Hint: ${currentQuestion.hint}";
    }

    notifyListeners();
    await _persistSession();
  }

  bool isWrongSelected(String label) => wrongAnswers.contains(label);
  bool isCorrectSelected(String label) => correctSelected == label;

  Future<void> nextQuestion() async {
    if (currentIndex < quiz.questions.length - 1) {
      currentIndex++;
      wrongAnswers.clear();
      correctSelected = null;
      feedbackMessage = null;
      notifyListeners();
      await _persistSession();
    }
  }

  Future<void> completeQuiz() async {
    await sessionStorage.saveSession(
      QuizSessionState(
        quizId: quiz.quizId,
        currentIndex: quiz.questions.length - 1,
        score: score,
        wrongAnswers: const [],
        correctSelected: currentQuestion.correctAnswer,
        isCompleted: true,
        lastInteractedAt: DateTime.now(),
      ),
    );
  }

  bool get isLastQuestion => currentIndex == quiz.questions.length - 1;
}
