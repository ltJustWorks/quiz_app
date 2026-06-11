import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/quiz.dart';
import '../models/quiz_session_state.dart';

class CloudSyncResult {
  final List<Quiz> quizzes;
  final List<String> folders;
  final Map<String, QuizSessionState> sessions;
  final int importedQuizCount;
  final int importedSessionCount;

  const CloudSyncResult({
    required this.quizzes,
    required this.folders,
    required this.sessions,
    required this.importedQuizCount,
    required this.importedSessionCount,
  });
}

class CloudSyncFolderAccessException implements Exception {
  final String folderPath;
  final Object error;

  const CloudSyncFolderAccessException({
    required this.folderPath,
    required this.error,
  });

  @override
  String toString() {
    return 'The selected sync folder is not writable from this app. '
        'On phones, OneDrive and Files providers may show a folder without '
        'granting normal file-system write access. Choose a local app-accessible '
        'folder that OneDrive syncs, or use a desktop sync folder. '
        'Folder: $folderPath. Details: $error';
  }
}

class CloudSyncService {
  static const String _settingsFileName = 'cloud_sync_settings.json';
  static const String _syncFileName = 'quizgpt_sync.json';
  static const MethodChannel _androidSyncChannel = MethodChannel(
    'quiz_app/android_sync_folder',
  );

  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_settingsFileName');
  }

  Future<String?> loadSyncFolderPath() async {
    try {
      final file = await _getSettingsFile();
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;

      final path = decoded['syncFolderPath'];
      return path is String && path.trim().isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSyncFolderPath(String folderPath) async {
    final file = await _getSettingsFile();
    await file.writeAsString(
      jsonEncode({
        'syncFolderPath': folderPath,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<String?> selectAndroidSyncFolder() async {
    if (!Platform.isAndroid) return null;

    return _androidSyncChannel.invokeMethod<String?>('selectSyncFolder');
  }

  Future<void> validateSyncFolderAccess(String folderPath) async {
    if (_usesAndroidSaf(folderPath)) {
      try {
        await _androidSyncChannel.invokeMethod<bool>('validateSyncFolder', {
          'folderUri': folderPath,
        });
        return;
      } catch (e) {
        throw CloudSyncFolderAccessException(folderPath: folderPath, error: e);
      }
    }

    final syncDirectory = Directory(folderPath);

    try {
      if (!await syncDirectory.exists()) {
        throw FileSystemException('Sync folder does not exist', folderPath);
      }

      final probeFile = File(
        '${syncDirectory.path}${Platform.pathSeparator}.quizgpt_write_test',
      );
      await probeFile.writeAsString(
        DateTime.now().toUtc().toIso8601String(),
        flush: true,
      );
      if (await probeFile.exists()) {
        await probeFile.delete();
      }
    } catch (e) {
      throw CloudSyncFolderAccessException(folderPath: folderPath, error: e);
    }
  }

  Future<CloudSyncResult> sync({
    required String folderPath,
    required List<Quiz> localQuizzes,
    required List<String> localFolders,
    required Map<String, QuizSessionState> localSessions,
  }) async {
    await validateSyncFolderAccess(folderPath);

    final remoteData = await _readSyncData(folderPath);
    final remoteQuizzes = remoteData.quizzes;
    final remoteFolders = remoteData.folders;
    final remoteSessions = remoteData.sessions;

    final mergedQuizzesById = <String, Quiz>{
      for (final quiz in remoteQuizzes) quiz.quizId: quiz,
    };
    var importedQuizCount = 0;
    for (final quiz in localQuizzes) {
      final existing = mergedQuizzesById[quiz.quizId];
      mergedQuizzesById[quiz.quizId] = _chooseQuiz(existing, quiz);
    }
    for (final quiz in remoteQuizzes) {
      if (!localQuizzes.any((local) => local.quizId == quiz.quizId)) {
        importedQuizCount++;
      }
    }

    final mergedSessions = <String, QuizSessionState>{...remoteSessions};
    var importedSessionCount = 0;
    for (final entry in localSessions.entries) {
      final existing = mergedSessions[entry.key];
      mergedSessions[entry.key] =
          existing == null ? entry.value : _mergeSession(existing, entry.value);
    }
    for (final entry in remoteSessions.entries) {
      final local = localSessions[entry.key];
      if (local == null || _mergeSession(local, entry.value) != local) {
        importedSessionCount++;
      }
    }

    final mergedFolders = {
      ...remoteFolders,
      ...localFolders,
      ...mergedQuizzesById.values.map((quiz) => quiz.folderName),
    }.where((folder) => folder.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final mergedQuizzes = mergedQuizzesById.values.toList()
      ..sort((a, b) {
        final aAddedAt = a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAddedAt = b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAddedAt.compareTo(aAddedAt);
      });

    await _writeSyncData(
      folderPath: folderPath,
      quizzes: mergedQuizzes,
      folders: mergedFolders,
      sessions: mergedSessions,
    );

    return CloudSyncResult(
      quizzes: mergedQuizzes,
      folders: mergedFolders,
      sessions: mergedSessions,
      importedQuizCount: importedQuizCount,
      importedSessionCount: importedSessionCount,
    );
  }

  Future<_SyncFileData> _readSyncData(String folderPath) async {
    if (_usesAndroidSaf(folderPath)) {
      try {
        final content = await _androidSyncChannel.invokeMethod<String?>(
          'readSyncFile',
          {
            'folderUri': folderPath,
            'fileName': _syncFileName,
          },
        );

        return _decodeSyncFileContent(content);
      } catch (e) {
        throw CloudSyncFolderAccessException(folderPath: folderPath, error: e);
      }
    }

    final syncDirectory = Directory(folderPath);
    final syncFile = File('${syncDirectory.path}${Platform.pathSeparator}$_syncFileName');

    if (!await syncFile.exists()) {
      return const _SyncFileData(
        quizzes: [],
        folders: [],
        sessions: {},
      );
    }

    try {
      return _decodeSyncFileContent(await syncFile.readAsString());
    } catch (e) {
      throw CloudSyncFolderAccessException(folderPath: folderPath, error: e);
    }
  }

  _SyncFileData _decodeSyncFileContent(String? content) {
    if (content == null || content.trim().isEmpty) {
      return const _SyncFileData(
        quizzes: [],
        folders: [],
        sessions: {},
      );
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Sync file root must be a JSON object');
    }

    final quizzes =
        (decoded['quizzes'] as List<dynamic>? ?? const [])
            .map((value) => Quiz.fromJson(Map<String, dynamic>.from(value)))
            .toList();
    final folders = List<String>.from(decoded['folders'] ?? const []);
    final rawSessions = Map<String, dynamic>.from(decoded['sessions'] ?? {});
    final sessions = rawSessions.map(
      (quizId, value) => MapEntry(
        quizId,
        QuizSessionState.fromJson(Map<String, dynamic>.from(value)),
      ),
    );

    return _SyncFileData(
      quizzes: quizzes,
      folders: folders,
      sessions: sessions,
    );
  }

  Future<void> _writeSyncData({
    required String folderPath,
    required List<Quiz> quizzes,
    required List<String> folders,
    required Map<String, QuizSessionState> sessions,
  }) async {
    final payload = {
      'schemaVersion': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'quizzes': quizzes.map((quiz) => quiz.toJson()).toList(),
      'folders': folders,
      'sessions': sessions.map(
        (quizId, session) => MapEntry(quizId, session.toJson()),
      ),
    };
    final content = jsonEncode(payload);

    if (_usesAndroidSaf(folderPath)) {
      await _androidSyncChannel.invokeMethod<bool>('writeSyncFile', {
        'folderUri': folderPath,
        'fileName': _syncFileName,
        'content': content,
      });
      return;
    }

    final syncDirectory = Directory(folderPath);
    final syncFile = File('${syncDirectory.path}${Platform.pathSeparator}$_syncFileName');
    final tempFile = File('${syncFile.path}.tmp');
    await tempFile.writeAsString(content, flush: true);
    if (await syncFile.exists()) {
      await syncFile.delete();
    }
    await tempFile.rename(syncFile.path);
  }

  bool _usesAndroidSaf(String folderPath) {
    return Platform.isAndroid && folderPath.startsWith('content://');
  }

  Quiz _chooseQuiz(Quiz? existing, Quiz incoming) {
    if (existing == null) return incoming;

    final existingAddedAt =
        existing.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final incomingAddedAt =
        incoming.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    return incomingAddedAt.isAfter(existingAddedAt) ? incoming : existing;
  }

  QuizSessionState _mergeSession(
    QuizSessionState first,
    QuizSessionState second,
  ) {
    final firstTime =
        first.lastInteractedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final secondTime =
        second.lastInteractedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final latest = secondTime.isAfter(firstTime) ? second : first;
    final other = identical(latest, first) ? second : first;
    final activeState = _chooseActiveSessionState(first, second, latest);
    final mergedQuestionProgress = <int, QuizQuestionProgressState>{
      ...other.questionProgress,
    };

    for (final entry in latest.questionProgress.entries) {
      final existing = mergedQuestionProgress[entry.key];
      mergedQuestionProgress[entry.key] =
          existing == null
              ? entry.value
              : _mergeQuestionProgress(existing, entry.value);
    }

    return QuizSessionState(
      quizId: latest.quizId,
      currentIndex: activeState.currentIndex,
      score: latest.score > other.score ? latest.score : other.score,
      wrongAnswers: activeState.wrongAnswers,
      correctSelected: activeState.correctSelected,
      isCompleted: activeState.isCompleted,
      lastInteractedAt: secondTime.isAfter(firstTime) ? secondTime : firstTime,
      elapsedSeconds:
          latest.elapsedSeconds > other.elapsedSeconds
              ? latest.elapsedSeconds
              : other.elapsedSeconds,
      questionProgress: mergedQuestionProgress,
      furthestReachedQuestionIndex:
          latest.furthestReachedQuestionIndex > other.furthestReachedQuestionIndex
              ? latest.furthestReachedQuestionIndex
              : other.furthestReachedQuestionIndex,
      completedReviewPasses:
          latest.completedReviewPasses > other.completedReviewPasses
              ? latest.completedReviewPasses
              : other.completedReviewPasses,
      bestPartialReviewPass:
          latest.bestPartialReviewPass > other.bestPartialReviewPass
              ? latest.bestPartialReviewPass
              : other.bestPartialReviewPass,
      completedRunCount:
          latest.completedRunCount > other.completedRunCount
              ? latest.completedRunCount
              : other.completedRunCount,
      cumulativeElapsedSeconds:
          latest.cumulativeElapsedSeconds > other.cumulativeElapsedSeconds
              ? latest.cumulativeElapsedSeconds
              : other.cumulativeElapsedSeconds,
      lastCompletedScore: latest.lastCompletedScore ?? other.lastCompletedScore,
      lastCompletedTotalQuestions:
          latest.lastCompletedTotalQuestions ?? other.lastCompletedTotalQuestions,
      lastCompletedAt: _latestDate(latest.lastCompletedAt, other.lastCompletedAt),
    );
  }

  QuizSessionState _chooseActiveSessionState(
    QuizSessionState first,
    QuizSessionState second,
    QuizSessionState latest,
  ) {
    final firstProgress = _activeProgressWeight(first);
    final secondProgress = _activeProgressWeight(second);

    if (first.isCompleted != second.isCompleted) {
      return latest;
    }

    if (firstProgress == 0 && secondProgress > 0) {
      return second;
    }

    if (secondProgress == 0 && firstProgress > 0) {
      return first;
    }

    return latest;
  }

  int _activeProgressWeight(QuizSessionState session) {
    final answeredQuestions =
        session.questionProgress.values
            .where(
              (progress) =>
                  progress.hasAnsweredCorrectly ||
                  progress.wrongAnswers.isNotEmpty,
            )
            .length;

    return answeredQuestions > session.furthestReachedQuestionIndex
        ? answeredQuestions
        : session.furthestReachedQuestionIndex;
  }

  QuizQuestionProgressState _mergeQuestionProgress(
    QuizQuestionProgressState first,
    QuizQuestionProgressState second,
  ) {
    if (second.correctSelected != null) return second;
    if (first.correctSelected != null) return first;

    return QuizQuestionProgressState(
      wrongAnswers: {...first.wrongAnswers, ...second.wrongAnswers}.toList(),
      correctSelected: null,
    );
  }

  DateTime? _latestDate(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return second.isAfter(first) ? second : first;
  }
}

class _SyncFileData {
  final List<Quiz> quizzes;
  final List<String> folders;
  final Map<String, QuizSessionState> sessions;

  const _SyncFileData({
    required this.quizzes,
    required this.folders,
    required this.sessions,
  });
}
