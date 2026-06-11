import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/quiz.dart';

class QuizStorageData {
  final List<Quiz> quizzes;
  final List<String> folders;

  QuizStorageData({required this.quizzes, required this.folders});
}

class QuizStorageService {
  static const String _fileName = 'saved_quizzes.json';

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<QuizStorageData> loadStorageData() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        return QuizStorageData(quizzes: const [], folders: const []);
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return QuizStorageData(quizzes: const [], folders: const []);
      }

      final decoded = jsonDecode(raw);
      final quizzesJson = decoded['quizzes'] as List<dynamic>;
      final foldersJson = List<String>.from(decoded['folders'] ?? const []);

      return QuizStorageData(
        quizzes: quizzesJson.map((q) => Quiz.fromJson(q)).toList(),
        folders: foldersJson,
      );
    } catch (_) {
      return QuizStorageData(quizzes: const [], folders: const []);
    }
  }

  Future<List<Quiz>> loadSavedQuizzes() async {
    final data = await loadStorageData();
    return data.quizzes;
  }

  Future<List<String>> loadSavedFolders() async {
    final data = await loadStorageData();
    return data.folders;
  }

  Future<void> saveData({
    required List<Quiz> quizzes,
    required List<String> folders,
  }) async {
    final file = await _getFile();
    final normalizedFolders =
        folders.toSet().where((folder) => folder.trim().isNotEmpty).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final data = {
      'quizzes': quizzes.map((q) => q.toJson()).toList(),
      'folders': normalizedFolders,
    };

    await file.writeAsString(jsonEncode(data));
  }

  Future<void> saveQuizzes(List<Quiz> quizzes, {List<String> folders = const []}) async {
    await saveData(quizzes: quizzes, folders: folders);
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
