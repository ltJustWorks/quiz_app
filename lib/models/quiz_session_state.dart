class QuizSessionState {
  final String quizId;
  final int currentIndex;
  final int score;
  final List<String> wrongAnswers;
  final String? correctSelected;
  final bool isCompleted;
  final DateTime? lastInteractedAt;

  QuizSessionState({
    required this.quizId,
    required this.currentIndex,
    required this.score,
    required this.wrongAnswers,
    required this.correctSelected,
    required this.isCompleted,
    required this.lastInteractedAt,
  });

  factory QuizSessionState.fromJson(Map<String, dynamic> json) {
    return QuizSessionState(
      quizId: json['quizId'] ?? json['activeQuizId'],
      currentIndex: json['currentIndex'],
      score: json['score'],
      wrongAnswers: List<String>.from(json['wrongAnswers'] ?? []),
      correctSelected: json['correctSelected'],
      isCompleted: json['isCompleted'] ?? false,
      lastInteractedAt:
          json['lastInteractedAt'] != null
              ? DateTime.tryParse(json['lastInteractedAt'])
              : null,
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
    };
  }

  int answeredQuestionsCount(int totalQuestions) {
    if (isCompleted) {
      return totalQuestions;
    }

    final answeredCount = currentIndex + (correctSelected != null ? 1 : 0);
    return answeredCount.clamp(0, totalQuestions);
  }
}
