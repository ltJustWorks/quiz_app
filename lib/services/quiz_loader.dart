import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../models/quiz.dart';
import 'json_repair.dart';
import 'latex_json_repair.dart';
import 'quiz_json_validator.dart';

class QuizLoader {
  static Future<List<Quiz>> loadFromAssets(String path) async {
    final raw = await rootBundle.loadString(path);
    return parseQuizzes(raw);
  }

  static Future<List<Quiz>> loadFromFile(String filePath) async {
    final raw = await File(filePath).readAsString();
    return parseQuizzes(raw);
  }

  static String _normalizeJsonInput(String rawJson) {
    final repaired1 = JsonRepair.repair(rawJson);
    final repaired2 = LatexJsonRepair.repair(repaired1);
    return repaired2;
  }

  static Map<String, dynamic> _decodeJsonWithRepair(String rawJson) {
    final normalized = _normalizeJsonInput(rawJson);
    return jsonDecode(normalized) as Map<String, dynamic>;
  }

  static List<Quiz> parseQuizzes(String rawJson) {
    final decoded = _decodeJsonWithRepair(rawJson);

    _convertUnlabeledQuestions(decoded);

    final validationErrors = QuizJsonValidator.validate(decoded);
    if (validationErrors.isNotEmpty) {
      throw FormatException(
        'Quiz JSON validation failed:\n${validationErrors.take(10).join('\n')}',
      );
    }

    final quizzesJson = decoded['quizzes'] as List;
    return quizzesJson.map((q) => Quiz.fromJson(q)).toList();
  }

  static void _convertUnlabeledQuestions(Map<String, dynamic> decoded) {
    final quizzes = decoded['quizzes'];
    if (quizzes is! List) return;

    for (final quiz in quizzes) {
      if (quiz is! Map<String, dynamic>) continue;

      final questions = quiz['questions'];
      if (questions is! List) continue;

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        if (q is! Map<String, dynamic>) continue;

        final hasOldFormat =
            q.containsKey('options') && q.containsKey('correctAnswer');
        final hasNewFormat =
            q.containsKey('correctOptionText') && q.containsKey('distractors');

        if (hasOldFormat || !hasNewFormat) continue;

        questions[i] = _convertOneUnlabeledQuestion(q);
      }
    }
  }

  static Map<String, dynamic> _convertOneUnlabeledQuestion(
    Map<String, dynamic> q,
  ) {
    final correctOptionText = q['correctOptionText'];
    final distractors = q['distractors'];

    if (correctOptionText is! String) {
      throw FormatException('correctOptionText must be a string.');
    }

    if (distractors is! List || distractors.length != 4) {
      throw FormatException('distractors must be a list of exactly 4 items.');
    }

    final allChoices = <String>[
      correctOptionText,
      ...distractors.map((d) => d.toString()),
    ];

    allChoices.shuffle();

    const labels = ['A', 'B', 'C', 'D', 'E'];
    final options = <Map<String, dynamic>>[];
    String? correctAnswer;

    for (int i = 0; i < allChoices.length; i++) {
      options.add({'label': labels[i], 'text': allChoices[i]});

      if (allChoices[i] == correctOptionText) {
        correctAnswer = labels[i];
      }
    }

    if (correctAnswer == null) {
      throw FormatException(
        'Failed to determine correctAnswer from correctOptionText.',
      );
    }

    return {
      'id': q['id'],
      'prompt': q['prompt'],
      'options': options,
      'correctAnswer': correctAnswer,
      'hint': q['hint'],
      'explanation': q['explanation'],
    };
  }
}
