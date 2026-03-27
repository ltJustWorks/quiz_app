import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/quiz_session_state.dart';

class QuizSessionStorageService {
  static const String _fileName = 'quiz_sessions.json';

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> saveSession(QuizSessionState session) async {
    final file = await _getFile();
    final sessions = await loadSessions();
    sessions[session.quizId] = session;
    await file.writeAsString(
      jsonEncode({
        'sessions': sessions.map(
          (quizId, state) => MapEntry(quizId, state.toJson()),
        ),
      }),
    );
  }

  Future<Map<String, QuizSessionState>> loadSessions() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return {};

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};

      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic> && decoded['sessions'] is Map) {
        final sessionsJson = Map<String, dynamic>.from(decoded['sessions']);
        return sessionsJson.map(
          (quizId, value) => MapEntry(
            quizId,
            QuizSessionState.fromJson(Map<String, dynamic>.from(value)),
          ),
        );
      }

      final legacySession = QuizSessionState.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return {legacySession.quizId: legacySession};
    } catch (_) {
      return {};
    }
  }

  Future<QuizSessionState?> loadSession(String quizId) async {
    final sessions = await loadSessions();
    return sessions[quizId];
  }

  Future<void> clearSession(String quizId) async {
    final file = await _getFile();
    final sessions = await loadSessions();
    sessions.remove(quizId);

    if (sessions.isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    await file.writeAsString(
      jsonEncode({
        'sessions': sessions.map(
          (savedQuizId, state) => MapEntry(savedQuizId, state.toJson()),
        ),
      }),
    );
  }

  Future<void> clearAllSessions() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
