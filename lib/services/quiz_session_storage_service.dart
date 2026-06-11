import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/quiz_session_state.dart';

class QuizSessionStorageService {
  static const String _fileName = 'quiz_sessions.json';
  static const String _backupFileName = 'quiz_sessions.backup.json';

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _getBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_backupFileName');
  }

  Future<void> saveSession(QuizSessionState session) async {
    await saveSessions({session.quizId: session});
  }

  Future<void> saveSessions(Map<String, QuizSessionState> sessions) async {
    final existingSessions = await loadSessions();
    final protectedSessions = Map<String, QuizSessionState>.from(existingSessions);

    for (final entry in sessions.entries) {
      protectedSessions[entry.key] =
          entry.value.preserveMemoryStageFrom(existingSessions[entry.key]);
    }

    await _writeSessions(protectedSessions);
  }

  Future<void> _writeSessions(Map<String, QuizSessionState> sessions) async {
    final file = await _getFile();
    final backupFile = await _getBackupFile();
    final payload = jsonEncode({
      'sessions': sessions.map(
        (quizId, state) => MapEntry(quizId, state.toJson()),
      ),
    });

    if (await file.exists()) {
      await backupFile.writeAsString(await file.readAsString(), flush: true);
    }

    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(payload, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
    await backupFile.writeAsString(payload, flush: true);
  }

  Future<Map<String, QuizSessionState>> loadSessions() async {
    final file = await _getFile();
    final backupFile = await _getBackupFile();

    try {
      final primarySessions = await _readSessionsFromFile(file);
      final backupSessions = await _readSessionsFromFile(backupFile);

      for (final entry in backupSessions.entries) {
        final primary = primarySessions[entry.key];
        primarySessions[entry.key] =
            primary?.preserveMemoryStageFrom(entry.value) ?? entry.value;
      }

      return primarySessions;
    } catch (_) {
      try {
        return await _readSessionsFromFile(backupFile);
      } catch (_) {
        return {};
      }
    }
  }

  Future<Map<String, QuizSessionState>> _readSessionsFromFile(File file) async {
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

    await _writeSessions(sessions);
  }

  Future<void> clearAllSessions() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
    final backupFile = await _getBackupFile();
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  }
}
