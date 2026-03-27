import 'question.dart';

class Quiz {
  final String quizId;
  final String quizName;
  final String description;
  final String folderName;
  final DateTime? addedAt;
  final List<QuizQuestion> questions;

  Quiz({
    required this.quizId,
    required this.quizName,
    required this.description,
    required this.folderName,
    required this.addedAt,
    required this.questions,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      quizId: json['quizId'],
      quizName: json['quizName'],
      description: json['description'] ?? '',
      folderName: json['folderName'] ?? 'Imported',
      addedAt:
          json['addedAt'] != null ? DateTime.tryParse(json['addedAt']) : null,
      questions:
          (json['questions'] as List)
              .map((q) => QuizQuestion.fromJson(q))
              .toList(),
    );
  }

  Quiz copyWith({
    String? quizId,
    String? quizName,
    String? description,
    String? folderName,
    DateTime? addedAt,
    List<QuizQuestion>? questions,
  }) {
    return Quiz(
      quizId: quizId ?? this.quizId,
      quizName: quizName ?? this.quizName,
      description: description ?? this.description,
      folderName: folderName ?? this.folderName,
      addedAt: addedAt ?? this.addedAt,
      questions: questions ?? this.questions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quizId': quizId,
      'quizName': quizName,
      'description': description,
      'folderName': folderName,
      'addedAt': addedAt?.toIso8601String(),
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}
