import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/quiz.dart';

class QuizStorageService {
  static const String _fileName = 'saved_quizzes.json';

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<Quiz>> loadSavedQuizzes() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        return [];
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      final quizzesJson = decoded['quizzes'] as List<dynamic>;

      return quizzesJson.map((q) => Quiz.fromJson(q)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveQuizzes(List<Quiz> quizzes) async {
    final file = await _getFile();

    final data = {'quizzes': quizzes.map((q) => q.toJson()).toList()};

    await file.writeAsString(jsonEncode(data));
  }

  Future<void> addQuizzes(List<Quiz> existing, List<Quiz> newQuizzes) async {
    final merged = [...existing];

    for (final quiz in newQuizzes) {
      final alreadyExists = merged.any((q) => q.quizId == quiz.quizId);
      if (!alreadyExists) {
        merged.add(quiz);
      }
    }

    await saveQuizzes(merged);
  }
}
