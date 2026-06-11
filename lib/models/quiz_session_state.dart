class QuizQuestionProgressState {
  final List<String> wrongAnswers;
  final String? correctSelected;

  const QuizQuestionProgressState({
    required this.wrongAnswers,
    required this.correctSelected,
  });

  factory QuizQuestionProgressState.fromJson(Map<String, dynamic> json) {
    return QuizQuestionProgressState(
      wrongAnswers: List<String>.from(json['wrongAnswers'] ?? []),
      correctSelected: json['correctSelected'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wrongAnswers': wrongAnswers,
      'correctSelected': correctSelected,
    };
  }

  bool get hasAnsweredCorrectly => correctSelected != null;
}

class QuizSessionState {
  final String quizId;
  final int currentIndex;
  final int score;
  final List<String> wrongAnswers;
  final String? correctSelected;
  final bool isCompleted;
  final DateTime? lastInteractedAt;
  final int elapsedSeconds;
  final Map<int, QuizQuestionProgressState> questionProgress;
  final int furthestReachedQuestionIndex;
  final int completedReviewPasses;
  final double bestPartialReviewPass;
  final int completedRunCount;
  final int cumulativeElapsedSeconds;
  final int? lastCompletedScore;
  final int? lastCompletedTotalQuestions;
  final DateTime? lastCompletedAt;

  QuizSessionState({
    required this.quizId,
    required this.currentIndex,
    required this.score,
    required this.wrongAnswers,
    required this.correctSelected,
    required this.isCompleted,
    required this.lastInteractedAt,
    required this.elapsedSeconds,
    required this.questionProgress,
    required this.furthestReachedQuestionIndex,
    required this.completedReviewPasses,
    required this.bestPartialReviewPass,
    required this.completedRunCount,
    required this.cumulativeElapsedSeconds,
    required this.lastCompletedScore,
    required this.lastCompletedTotalQuestions,
    required this.lastCompletedAt,
  });

  factory QuizSessionState.fromJson(Map<String, dynamic> json) {
    final rawProgress = Map<String, dynamic>.from(json['questionProgress'] ?? {});
    final isCompleted = json['isCompleted'] ?? false;
    final completedRunCount =
        json['completedRunCount'] ?? (isCompleted ? 1 : 0);
    final completedReviewPasses =
        json['completedReviewPasses'] ?? completedRunCount;

    return QuizSessionState(
      quizId: json['quizId'] ?? json['activeQuizId'],
      currentIndex: json['currentIndex'],
      score: json['score'],
      wrongAnswers: List<String>.from(json['wrongAnswers'] ?? []),
      correctSelected: json['correctSelected'],
      isCompleted: isCompleted,
      lastInteractedAt:
          json['lastInteractedAt'] != null
              ? DateTime.tryParse(json['lastInteractedAt'])
              : null,
      elapsedSeconds: json['elapsedSeconds'] ?? 0,
      questionProgress:
          rawProgress.isNotEmpty
              ? rawProgress.map(
                (index, value) => MapEntry(
                  int.parse(index),
                  QuizQuestionProgressState.fromJson(
                    Map<String, dynamic>.from(value),
                  ),
                ),
              )
              : {
                json['currentIndex']: QuizQuestionProgressState(
                  wrongAnswers: List<String>.from(json['wrongAnswers'] ?? []),
                  correctSelected: json['correctSelected'],
                ),
              },
      furthestReachedQuestionIndex:
          json['furthestReachedQuestionIndex'] ?? json['currentIndex'],
      completedReviewPasses: completedReviewPasses,
      bestPartialReviewPass: (json['bestPartialReviewPass'] ?? 0).toDouble(),
      completedRunCount: completedRunCount,
      cumulativeElapsedSeconds: json['cumulativeElapsedSeconds'] ?? (json['elapsedSeconds'] ?? 0),
      lastCompletedScore: json['lastCompletedScore'] ?? (isCompleted ? json['score'] : null),
      lastCompletedTotalQuestions:
          json['lastCompletedTotalQuestions'] ??
          (isCompleted ? rawProgress.length : null),
      lastCompletedAt:
          json['lastCompletedAt'] != null
              ? DateTime.tryParse(json['lastCompletedAt'])
              : (isCompleted && json['lastInteractedAt'] != null
                    ? DateTime.tryParse(json['lastInteractedAt'])
                    : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quizId': quizId,
      'currentIndex': currentIndex,
      'score': score,
      'wrongAnswers': wrongAnswers,
      'correctSelected': correctSelected,
      'isCompleted': isCompleted,
      'lastInteractedAt': lastInteractedAt?.toIso8601String(),
      'elapsedSeconds': elapsedSeconds,
      'questionProgress': questionProgress.map(
        (index, progress) => MapEntry(index.toString(), progress.toJson()),
      ),
      'furthestReachedQuestionIndex': furthestReachedQuestionIndex,
      'completedReviewPasses': completedReviewPasses,
      'bestPartialReviewPass': bestPartialReviewPass,
      'completedRunCount': completedRunCount,
      'cumulativeElapsedSeconds': cumulativeElapsedSeconds,
      'lastCompletedScore': lastCompletedScore,
      'lastCompletedTotalQuestions': lastCompletedTotalQuestions,
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
    };
  }

  QuizSessionState preserveMemoryStageFrom(QuizSessionState? existing) {
    if (existing == null) return this;

    return QuizSessionState(
      quizId: quizId,
      currentIndex: currentIndex,
      score: score,
      wrongAnswers: wrongAnswers,
      correctSelected: correctSelected,
      isCompleted: isCompleted,
      lastInteractedAt: lastInteractedAt,
      elapsedSeconds: elapsedSeconds,
      questionProgress: questionProgress,
      furthestReachedQuestionIndex: furthestReachedQuestionIndex,
      completedReviewPasses:
          completedReviewPasses > existing.completedReviewPasses
              ? completedReviewPasses
              : existing.completedReviewPasses,
      bestPartialReviewPass:
          bestPartialReviewPass > existing.bestPartialReviewPass
              ? bestPartialReviewPass
              : existing.bestPartialReviewPass,
      completedRunCount:
          completedRunCount > existing.completedRunCount
              ? completedRunCount
              : existing.completedRunCount,
      cumulativeElapsedSeconds:
          cumulativeElapsedSeconds > existing.cumulativeElapsedSeconds
              ? cumulativeElapsedSeconds
              : existing.cumulativeElapsedSeconds,
      lastCompletedScore: _preferLatestCompletionValue<int>(
        incomingValue: lastCompletedScore,
        incomingCompletedAt: lastCompletedAt,
        existingValue: existing.lastCompletedScore,
        existingCompletedAt: existing.lastCompletedAt,
      ),
      lastCompletedTotalQuestions: _preferLatestCompletionValue<int>(
        incomingValue: lastCompletedTotalQuestions,
        incomingCompletedAt: lastCompletedAt,
        existingValue: existing.lastCompletedTotalQuestions,
        existingCompletedAt: existing.lastCompletedAt,
      ),
      lastCompletedAt: _latestDate(lastCompletedAt, existing.lastCompletedAt),
    );
  }

  static T? _preferLatestCompletionValue<T>({
    required T? incomingValue,
    required DateTime? incomingCompletedAt,
    required T? existingValue,
    required DateTime? existingCompletedAt,
  }) {
    if (incomingValue == null) return existingValue;
    if (existingValue == null) return incomingValue;
    if (incomingCompletedAt == null) return incomingValue;
    if (existingCompletedAt == null) return incomingValue;

    return incomingCompletedAt.isBefore(existingCompletedAt)
        ? existingValue
        : incomingValue;
  }

  static DateTime? _latestDate(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return second.isAfter(first) ? second : first;
  }

  int answeredQuestionsCount(int totalQuestions) {
    if (isCompleted) {
      return totalQuestions;
    }

    final answeredCount =
        questionProgress.values
            .where((progress) => progress.hasAnsweredCorrectly)
            .length;
    return answeredCount.clamp(0, totalQuestions);
  }

  double reviewPassEquivalent(int totalQuestions) {
    if (totalQuestions <= 0) {
      return completedReviewPasses.toDouble();
    }

    final partial = bestPartialReviewPass.clamp(0.0, 1.0);
    return completedReviewPasses + partial;
  }

  QuizSessionState restarted() {
    return QuizSessionState(
      quizId: quizId,
      currentIndex: 0,
      score: 0,
      wrongAnswers: const [],
      correctSelected: null,
      isCompleted: false,
      lastInteractedAt: DateTime.now(),
      elapsedSeconds: 0,
      questionProgress: const {},
      furthestReachedQuestionIndex: 0,
      completedReviewPasses: completedReviewPasses,
      bestPartialReviewPass: bestPartialReviewPass,
      completedRunCount: completedRunCount,
      cumulativeElapsedSeconds: cumulativeElapsedSeconds,
      lastCompletedScore: lastCompletedScore,
      lastCompletedTotalQuestions: lastCompletedTotalQuestions,
      lastCompletedAt: lastCompletedAt,
    );
  }
}
