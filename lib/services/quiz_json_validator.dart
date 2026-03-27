class QuizJsonValidator {
  static List<String> validate(Map<String, dynamic> decoded) {
    final errors = <String>[];

    final quizzes = decoded['quizzes'];
    if (quizzes is! List) {
      errors.add('Missing or invalid "quizzes" array.');
      return errors;
    }

    for (int qi = 0; qi < quizzes.length; qi++) {
      final quiz = quizzes[qi];
      if (quiz is! Map<String, dynamic>) {
        errors.add('Quiz ${qi + 1} is not an object.');
        continue;
      }

      if (quiz['quizId'] == null || quiz['quizName'] == null) {
        errors.add('Quiz ${qi + 1} is missing quizId or quizName.');
      }

      final questions = quiz['questions'];
      if (questions is! List) {
        errors.add('Quiz ${qi + 1} has missing or invalid questions array.');
        continue;
      }

      for (int qj = 0; qj < questions.length; qj++) {
        final question = questions[qj];
        if (question is! Map<String, dynamic>) {
          errors.add('Quiz ${qi + 1}, question ${qj + 1} is not an object.');
          continue;
        }

        final hasOldFormat =
            question.containsKey('options') &&
            question.containsKey('correctAnswer');

        final hasNewFormat =
            question.containsKey('correctOptionText') &&
            question.containsKey('distractors');

        if (!hasOldFormat && !hasNewFormat) {
          errors.add(
            'Quiz ${qi + 1}, question ${qj + 1} must use either old format '
            '(options + correctAnswer) or new format '
            '(correctOptionText + distractors).',
          );
          continue;
        }

        if (question['id'] == null || question['prompt'] == null) {
          errors.add(
            'Quiz ${qi + 1}, question ${qj + 1} is missing id or prompt.',
          );
        }

        if (question['hint'] == null || question['explanation'] == null) {
          errors.add(
            'Quiz ${qi + 1}, question ${qj + 1} is missing hint or explanation.',
          );
        }

        if (hasOldFormat) {
          final options = question['options'];
          final correctAnswer = question['correctAnswer'];

          if (options is! List || options.length != 5) {
            errors.add(
              'Quiz ${qi + 1}, question ${qj + 1} must have exactly 5 options.',
            );
          }

          const validLabels = {'A', 'B', 'C', 'D', 'E'};
          if (!validLabels.contains(correctAnswer)) {
            errors.add(
              'Quiz ${qi + 1}, question ${qj + 1} has invalid correctAnswer "$correctAnswer".',
            );
          }

          if (options is List) {
            for (int oi = 0; oi < options.length; oi++) {
              final option = options[oi];
              if (option is! Map<String, dynamic>) {
                errors.add(
                  'Quiz ${qi + 1}, question ${qj + 1}, option ${oi + 1} is not an object.',
                );
                continue;
              }

              final label = option['label'];
              final text = option['text'];

              if (!validLabels.contains(label)) {
                errors.add(
                  'Quiz ${qi + 1}, question ${qj + 1}, option ${oi + 1} has invalid label "$label".',
                );
              }

              if (text == null || text is! String) {
                errors.add(
                  'Quiz ${qi + 1}, question ${qj + 1}, option ${oi + 1} is missing text.',
                );
              }
            }
          }
        }

        if (hasNewFormat) {
          final correctOptionText = question['correctOptionText'];
          final distractors = question['distractors'];

          if (correctOptionText == null || correctOptionText is! String) {
            errors.add(
              'Quiz ${qi + 1}, question ${qj + 1} is missing correctOptionText.',
            );
          }

          if (distractors is! List || distractors.length != 4) {
            errors.add(
              'Quiz ${qi + 1}, question ${qj + 1} must have exactly 4 distractors.',
            );
          }
        }
      }
    }

    return errors;
  }
}
