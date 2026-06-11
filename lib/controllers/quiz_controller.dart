import 'package:flutter/foundation.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../models/quiz_session_state.dart';
import '../services/quiz_session_storage_service.dart';

class QuizController extends ChangeNotifier {
  final Quiz quiz;
  final QuizSessionStorageService sessionStorage;

  int currentIndex = 0;
  int score = 0;
  int _persistedElapsedSeconds = 0;
  final Stopwatch _stopwatch = Stopwatch();
  bool _quizCompleted = false;
  final Map<int, QuizQuestionProgressState> _questionProgress = {};
  int _furthestReachedQuestionIndex = 0;
  int _completedReviewPasses = 0;
  double _bestPartialReviewPass = 0;
  int _completedRunCount = 0;
  int _cumulativeElapsedSeconds = 0;
  int? _lastCompletedScore;
  int? _lastCompletedTotalQuestions;
  DateTime? _lastCompletedAt;

  QuizController(
    this.quiz, {
    QuizSessionStorageService? sessionStorage,
    QuizSessionState? initialState,
  }) : sessionStorage = sessionStorage ?? QuizSessionStorageService() {
    if (initialState != null && initialState.quizId == quiz.quizId) {
      currentIndex = initialState.currentIndex;
      score = initialState.score;
      _persistedElapsedSeconds = initialState.elapsedSeconds;
      _quizCompleted = initialState.isCompleted;
      _questionProgress.addAll(initialState.questionProgress);
      _furthestReachedQuestionIndex = initialState.furthestReachedQuestionIndex;
      _completedReviewPasses = initialState.completedReviewPasses;
      _bestPartialReviewPass = initialState.bestPartialReviewPass;
      _completedRunCount = initialState.completedRunCount;
      _cumulativeElapsedSeconds = initialState.cumulativeElapsedSeconds;
      _lastCompletedScore = initialState.lastCompletedScore;
      _lastCompletedTotalQuestions = initialState.lastCompletedTotalQuestions;
      _lastCompletedAt = initialState.lastCompletedAt;
    }

    if (initialState == null || !initialState.isCompleted) {
      _stopwatch.start();
    }
  }

  QuizQuestion get currentQuestion => quiz.questions[currentIndex];

  QuizQuestionProgressState get currentQuestionProgress =>
      _questionProgress[currentIndex] ??
      const QuizQuestionProgressState(wrongAnswers: [], correctSelected: null);

  Set<String> get wrongAnswers => currentQuestionProgress.wrongAnswers.toSet();
  String? get correctSelected => currentQuestionProgress.correctSelected;
  String? get feedbackMessage {
    if (correctSelected != null) {
      return "Correct!\n\nExplanation: ${currentQuestion.explanation}";
    }

    if (wrongAnswers.isNotEmpty) {
      return "Incorrect. Hint: ${currentQuestion.hint}";
    }

    return null;
  }

  bool get hasAnsweredCorrectly => correctSelected != null;
  bool get isLastQuestion => currentIndex == quiz.questions.length - 1;
  bool get isCompleted => _quizCompleted;
  bool get canGoToPreviousQuestion => currentIndex > 0;
  bool get canGoToNextQuestion => currentIndex < _furthestReachedQuestionIndex;
  int get answeredQuestionCount =>
      _questionProgress.values
          .where((progress) => progress.hasAnsweredCorrectly)
          .length;
  int get completedReviewPasses => _completedReviewPasses;
  double get currentPartialReviewPass => _computeCurrentPartialReviewPass();
  double get reviewPassEquivalent => _completedReviewPasses + currentPartialReviewPass;
  QuizSessionState get currentSessionSnapshot => QuizSessionState(
    quizId: quiz.quizId,
    currentIndex: currentIndex,
    score: score,
    wrongAnswers: currentQuestionProgress.wrongAnswers,
    correctSelected: currentQuestionProgress.correctSelected,
    isCompleted: _quizCompleted,
    lastInteractedAt: DateTime.now(),
    elapsedSeconds: _persistedElapsedSeconds,
    questionProgress: Map<int, QuizQuestionProgressState>.from(_questionProgress),
    furthestReachedQuestionIndex: _furthestReachedQuestionIndex,
    completedReviewPasses: _completedReviewPasses,
    bestPartialReviewPass: _bestPartialReviewPass,
    completedRunCount: _completedRunCount,
    cumulativeElapsedSeconds: _cumulativeElapsedSeconds,
    lastCompletedScore: _lastCompletedScore,
    lastCompletedTotalQuestions: _lastCompletedTotalQuestions,
    lastCompletedAt: _lastCompletedAt,
  );

  Duration get elapsedDuration =>
      Duration(seconds: _persistedElapsedSeconds) + _stopwatch.elapsed;
  String get formattedElapsedTime => _formatDuration(elapsedDuration);

  Future<void> saveProgress() => _persistSession();

  Future<void> pauseTracking() async {
    if (_stopwatch.isRunning) {
      await _persistSession();
      _stopwatch
        ..stop()
        ..reset();
    }
  }

  void resumeTracking() {
    if (!_stopwatch.isRunning && !_quizCompleted) {
      _stopwatch.start();
    }
  }

  bool isWrongSelected(String label) => wrongAnswers.contains(label);
  bool isCorrectSelected(String label) => correctSelected == label;

  Future<void> selectAnswer(String label) async {
    if (hasAnsweredCorrectly) return;

    final updatedWrongAnswers = Set<String>.from(wrongAnswers);
    String? updatedCorrectSelected;

    if (label == currentQuestion.correctAnswer) {
      updatedCorrectSelected = label;
      score = _questionProgress.values
              .where((progress) => progress.hasAnsweredCorrectly)
              .length +
          1;
    } else {
      updatedWrongAnswers.add(label);
    }

    _questionProgress[currentIndex] = QuizQuestionProgressState(
      wrongAnswers: updatedWrongAnswers.toList(),
      correctSelected: updatedCorrectSelected,
    );

    notifyListeners();
    await _persistSession();
  }

  Future<void> nextQuestion() async {
    if (hasAnsweredCorrectly && currentIndex < quiz.questions.length - 1) {
      _furthestReachedQuestionIndex =
          currentIndex + 1 > _furthestReachedQuestionIndex
              ? currentIndex + 1
              : _furthestReachedQuestionIndex;
    } else if (!canGoToNextQuestion) {
      return;
    }

    currentIndex++;
    notifyListeners();
    await _persistSession();
  }

  Future<void> previousQuestion() async {
    if (!canGoToPreviousQuestion) return;

    currentIndex--;
    notifyListeners();
    await _persistSession();
  }

  Future<void> completeQuiz() async {
    final totalElapsed = elapsedDuration;
    _persistedElapsedSeconds = totalElapsed.inSeconds;
    _stopwatch.stop();
    _quizCompleted = true;
    _completedReviewPasses += 1;
    _bestPartialReviewPass = 0;
    _completedRunCount += 1;
    _cumulativeElapsedSeconds += _persistedElapsedSeconds;
    _lastCompletedScore = score;
    _lastCompletedTotalQuestions = quiz.questions.length;
    _lastCompletedAt = DateTime.now();

    await sessionStorage.saveSession(
      QuizSessionState(
        quizId: quiz.quizId,
        currentIndex: quiz.questions.length - 1,
        score: score,
        wrongAnswers: const [],
        correctSelected: currentQuestion.correctAnswer,
        isCompleted: true,
        lastInteractedAt: DateTime.now(),
        elapsedSeconds: _persistedElapsedSeconds,
        questionProgress: Map<int, QuizQuestionProgressState>.from(
          _questionProgress,
        ),
        furthestReachedQuestionIndex: quiz.questions.length - 1,
        completedReviewPasses: _completedReviewPasses,
        bestPartialReviewPass: _bestPartialReviewPass,
        completedRunCount: _completedRunCount,
        cumulativeElapsedSeconds: _cumulativeElapsedSeconds,
        lastCompletedScore: _lastCompletedScore,
        lastCompletedTotalQuestions: _lastCompletedTotalQuestions,
        lastCompletedAt: _lastCompletedAt,
      ),
    );
  }

  Future<void> restartQuiz() async {
    currentIndex = 0;
    score = 0;
    _persistedElapsedSeconds = 0;
    _quizCompleted = false;
    _questionProgress.clear();
    _furthestReachedQuestionIndex = 0;
    _stopwatch
      ..stop()
      ..reset()
      ..start();

    notifyListeners();
    await _persistSession();
  }

  Future<void> _persistSession() async {
    final totalElapsed = elapsedDuration;
    _persistedElapsedSeconds = totalElapsed.inSeconds;
    final partialReviewPass = _computeCurrentPartialReviewPass();
    if (partialReviewPass > _bestPartialReviewPass) {
      _bestPartialReviewPass = partialReviewPass;
    }
    _stopwatch
      ..stop()
      ..reset()
      ..start();

    await sessionStorage.saveSession(
      QuizSessionState(
        quizId: quiz.quizId,
        currentIndex: currentIndex,
        score: score,
        wrongAnswers: currentQuestionProgress.wrongAnswers,
        correctSelected: currentQuestionProgress.correctSelected,
        isCompleted: false,
        lastInteractedAt: DateTime.now(),
        elapsedSeconds: _persistedElapsedSeconds,
        questionProgress: Map<int, QuizQuestionProgressState>.from(
          _questionProgress,
        ),
        furthestReachedQuestionIndex: _furthestReachedQuestionIndex,
        completedReviewPasses: _completedReviewPasses,
        bestPartialReviewPass: _bestPartialReviewPass,
        completedRunCount: _completedRunCount,
        cumulativeElapsedSeconds: _cumulativeElapsedSeconds,
        lastCompletedScore: _lastCompletedScore,
        lastCompletedTotalQuestions: _lastCompletedTotalQuestions,
        lastCompletedAt: _lastCompletedAt,
      ),
    );
  }

  double _computeCurrentPartialReviewPass() {
    if (quiz.questions.isEmpty || _quizCompleted) {
      return 0;
    }

    return (answeredQuestionCount / quiz.questions.length).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }

    return '${seconds}s';
  }
}
