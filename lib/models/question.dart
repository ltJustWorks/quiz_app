import 'dart:math';
import 'option.dart';

class QuizQuestion {
  final String id;
  final String prompt;
  final List<QuizOption> options;
  final String correctAnswer;
  final String hint;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    required this.hint,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    // Old format: options + correctAnswer already provided
    if (json.containsKey('options') && json.containsKey('correctAnswer')) {
      return QuizQuestion(
        id: json['id'],
        prompt: json['prompt'],
        options:
            (json['options'] as List)
                .map((o) => QuizOption.fromJson(o))
                .toList(),
        correctAnswer: json['correctAnswer'],
        hint: json['hint'],
        explanation: json['explanation'],
      );
    }

    // New format: correctOptionText + distractors
    if (json.containsKey('correctOptionText') &&
        json.containsKey('distractors')) {
      return _fromUnlabeledJson(json);
    }

    throw FormatException(
      'Question must contain either (options + correctAnswer) or (correctOptionText + distractors).',
    );
  }

  static QuizQuestion _fromUnlabeledJson(Map<String, dynamic> json) {
    final correctOptionText = json['correctOptionText'];
    final distractors = json['distractors'];

    if (correctOptionText is! String) {
      throw FormatException('correctOptionText must be a string.');
    }

    if (distractors is! List || distractors.length != 4) {
      throw FormatException('distractors must be a list of exactly 4 strings.');
    }

    final distractorTexts = distractors.map((d) => d.toString()).toList();

    final allChoices = <String>[correctOptionText, ...distractorTexts];

    // Shuffle choices
    allChoices.shuffle(Random());

    const labels = ['A', 'B', 'C', 'D', 'E'];

    final options = <QuizOption>[];
    String? correctAnswer;

    for (int i = 0; i < allChoices.length; i++) {
      final label = labels[i];
      final text = allChoices[i];

      options.add(QuizOption(label: label, text: text));

      if (text == correctOptionText) {
        correctAnswer = label;
      }
    }

    if (correctAnswer == null) {
      throw FormatException(
        'Failed to assign correctAnswer from correctOptionText.',
      );
    }

    return QuizQuestion(
      id: json['id'],
      prompt: json['prompt'],
      options: options,
      correctAnswer: correctAnswer,
      hint: json['hint'],
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'options': options.map((o) => o.toJson()).toList(),
      'correctAnswer': correctAnswer,
      'hint': hint,
      'explanation': explanation,
    };
  }
}
