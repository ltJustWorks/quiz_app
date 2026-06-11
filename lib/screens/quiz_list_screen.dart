import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/quiz.dart';
import '../models/quiz_session_state.dart';
import '../services/cloud_sync_service.dart';
import '../services/quiz_loader.dart';
import '../services/quiz_session_storage_service.dart';
import '../services/quiz_storage_service.dart';
import 'quiz_play_screen.dart';
import 'quiz_result_screen.dart';

enum QuizSortOrder { addedAt, recallFragility }

enum _MemoryStage { newQuiz, fragile, consolidating, durable }

class _MemoryStageAssessment {
  final _MemoryStage stage;
  final int completedReviewPasses;
  final double fragilityScore;

  const _MemoryStageAssessment({
    required this.stage,
    required this.completedReviewPasses,
    required this.fragilityScore,
  });

  String get headline {
    return switch (stage) {
      _MemoryStage.newQuiz => 'Memory stage: New',
      _MemoryStage.fragile => 'Memory stage: Fragile',
      _MemoryStage.consolidating => 'Memory stage: Consolidating',
      _MemoryStage.durable => 'Memory stage: Durable',
    };
  }

  String get detail {
    return switch (stage) {
      _MemoryStage.newQuiz =>
        'No completed retrieval pass yet',
      _MemoryStage.fragile =>
        'One completed retrieval pass | high forgetting risk',
      _MemoryStage.consolidating =>
        'Two completed retrieval passes | strengthening',
      _MemoryStage.durable =>
        '$completedReviewPasses completed retrieval passes | lower forgetting risk',
    };
  }

  double get strengthProgress {
    return (completedReviewPasses / 3).clamp(0.0, 1.0);
  }

  int get stageIndex {
    return switch (stage) {
      _MemoryStage.newQuiz => 0,
      _MemoryStage.fragile => 1,
      _MemoryStage.consolidating => 2,
      _MemoryStage.durable => 3,
    };
  }
}

class QuizListScreen extends StatefulWidget {
  final List<Quiz> initialQuizzes;
  final List<String> initialFolders;
  final Map<String, QuizSessionState> initialSessionStates;
  final String? initialResumeQuizId;

  const QuizListScreen({
    super.key,
    required this.initialQuizzes,
    required this.initialFolders,
    required this.initialSessionStates,
    this.initialResumeQuizId,
  });

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  static const String _builtInFolder = 'Built-in';
  static const String _defaultImportedFolder = 'Imported';

  late List<Quiz> quizzes;
  late List<String> folders;
  final QuizStorageService storage = QuizStorageService();
  final QuizSessionStorageService sessionStorage = QuizSessionStorageService();
  final CloudSyncService cloudSyncService = CloudSyncService();
  late Map<String, QuizSessionState> sessionStates;
  QuizSortOrder _sortOrder = QuizSortOrder.addedAt;
  String? syncFolderPath;
  bool _syncing = false;
  bool _didAutoResume = false;

  @override
  void initState() {
    super.initState();
    quizzes = List.from(widget.initialQuizzes);
    folders = List.from(widget.initialFolders);
    sessionStates = Map.from(widget.initialSessionStates);
    _loadSyncFolderPath();
  }

  Future<void> _loadSyncFolderPath() async {
    final path = await cloudSyncService.loadSyncFolderPath();
    if (!mounted) return;

    setState(() {
      syncFolderPath = path;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didAutoResume) return;

    final resumeQuizId = widget.initialResumeQuizId;
    if (resumeQuizId == null) return;

    final quiz = quizzes.cast<Quiz?>().firstWhere(
      (candidate) => candidate?.quizId == resumeQuizId,
      orElse: () => null,
    );
    final session = sessionStates[resumeQuizId];

    if (quiz == null || session == null || session.isCompleted) {
      _didAutoResume = true;
      return;
    }

    _didAutoResume = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openQuiz(quiz);
    });
  }

  List<Quiz> get importedQuizzes {
    return quizzes.where((q) => !q.quizId.startsWith('builtin_')).toList();
  }

  List<String> get selectableFolders {
    final folderSet = {
      _defaultImportedFolder,
      ...folders.where((folder) => folder != _builtInFolder),
      ...importedQuizzes.map((quiz) => quiz.folderName),
    };

    return folderSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Map<String, List<Quiz>> get quizzesByFolder {
    final grouped = <String, List<Quiz>>{};
    final allFolders = {
      ...folders,
      ...quizzes.map((quiz) => quiz.folderName),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final folder in allFolders) {
      grouped[folder] = [];
    }

    for (final quiz in quizzes) {
      grouped.putIfAbsent(quiz.folderName, () => []).add(quiz);
    }

    for (final folderQuizzes in grouped.values) {
      folderQuizzes.sort(_compareQuizzes);
    }

    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) {
        if (_sortOrder == QuizSortOrder.recallFragility) {
          final aFragility = a.value
              .map(_recallFragilityForQuiz)
              .fold<double>(0, (max, fragility) {
                return fragility > max ? fragility : max;
              });
          final bFragility = b.value
              .map(_recallFragilityForQuiz)
              .fold<double>(0, (max, fragility) {
                return fragility > max ? fragility : max;
              });

          if (aFragility == bFragility) {
            return a.key.toLowerCase().compareTo(b.key.toLowerCase());
          }

          return bFragility.compareTo(aFragility);
        }

        final aLatest = _latestAddedAtForFolder(a.value);
        final bLatest = _latestAddedAtForFolder(b.value);

        if (aLatest == bLatest) {
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
        }

        return bLatest.compareTo(aLatest);
      }),
    );
  }

  int _compareQuizzes(Quiz a, Quiz b) {
    if (_sortOrder == QuizSortOrder.recallFragility) {
      final aFragility = _recallFragilityForQuiz(a);
      final bFragility = _recallFragilityForQuiz(b);

      if (aFragility != bFragility) {
        return bFragility.compareTo(aFragility);
      }
    } else {
      final aAddedAt = a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAddedAt = b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (aAddedAt != bAddedAt) {
        return bAddedAt.compareTo(aAddedAt);
      }
    }

    return a.quizName.toLowerCase().compareTo(b.quizName.toLowerCase());
  }

  DateTime _latestAddedAtForFolder(List<Quiz> folderQuizzes) {
    return folderQuizzes
        .map((quiz) => quiz.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .fold<DateTime>(
          DateTime.fromMillisecondsSinceEpoch(0),
          (latest, date) => date.isAfter(latest) ? date : latest,
        );
  }

  double _recallFragilityForQuiz(Quiz quiz) {
    return _memoryAssessmentForQuiz(quiz).fragilityScore;
  }

  _MemoryStageAssessment _memoryAssessmentForQuiz(Quiz quiz) {
    final session = sessionStates[quiz.quizId];
    if (session == null) {
      return const _MemoryStageAssessment(
        stage: _MemoryStage.newQuiz,
        completedReviewPasses: 0,
        fragilityScore: 1,
      );
    }

    final completedPasses = session.completedReviewPasses;
    final stage =
        completedPasses >= 3
            ? _MemoryStage.durable
            : completedPasses == 2
                ? _MemoryStage.consolidating
                : completedPasses == 1
                    ? _MemoryStage.fragile
                    : _MemoryStage.newQuiz;
    final fragilityScore = (1 - (completedPasses / 3)).clamp(0.0, 1.0);

    return _MemoryStageAssessment(
      stage: stage,
      completedReviewPasses: completedPasses,
      fragilityScore: fragilityScore,
    );
  }

  Future<void> _saveImportedQuizzes() async {
    await storage.saveData(quizzes: importedQuizzes, folders: selectableFolders);
  }

  Future<void> _refreshSessionStates() async {
    final latestSessions = await sessionStorage.loadSessions();
    if (!mounted) return;

    setState(() {
      sessionStates = latestSessions;
    });
  }

  Future<void> _selectSyncFolder() async {
    final selectedPath =
        Platform.isAndroid
            ? await cloudSyncService.selectAndroidSyncFolder()
            : await FilePicker.platform.getDirectoryPath(
              dialogTitle: 'Select QuizGPT Sync Folder',
            );
    if (selectedPath == null || selectedPath.trim().isEmpty) return;

    try {
      await cloudSyncService.validateSyncFolderAccess(selectedPath);
      await cloudSyncService.saveSyncFolderPath(selectedPath);
    } catch (e) {
      if (!mounted) return;
      _showSyncMessage(_formatSyncError(e));
      return;
    }

    if (!mounted) return;
    setState(() {
      syncFolderPath = selectedPath;
    });

    await _syncWithSelectedFolder();
  }

  Future<void> _syncWithSelectedFolder() async {
    final path = syncFolderPath;
    if (path == null || path.trim().isEmpty) {
      await _selectSyncFolder();
      return;
    }

    setState(() {
      _syncing = true;
    });

    try {
      final latestLocalSessions = await sessionStorage.loadSessions();
      if (mounted) {
        setState(() {
          sessionStates = latestLocalSessions;
        });
      }

      final result = await cloudSyncService.sync(
        folderPath: path,
        localQuizzes: importedQuizzes,
        localFolders: folders,
        localSessions: latestLocalSessions,
      );
      final builtInQuizzes =
          quizzes.where((quiz) => quiz.quizId.startsWith('builtin_')).toList();
      final syncedImportedQuizzes =
          result.quizzes
              .where((quiz) => !quiz.quizId.startsWith('builtin_'))
              .toList();
      final nextQuizzes = [...builtInQuizzes];

      for (final quiz in syncedImportedQuizzes) {
        final exists = nextQuizzes.any((existing) => existing.quizId == quiz.quizId);
        if (!exists) {
          nextQuizzes.add(quiz);
        }
      }

      await storage.saveData(
        quizzes: syncedImportedQuizzes,
        folders: result.folders,
      );
      await sessionStorage.saveSessions(result.sessions);

      if (mounted) {
        setState(() {
          quizzes = nextQuizzes;
          folders = result.folders;
          sessionStates = result.sessions;
        });

        _showSyncMessage(
          'Sync complete: ${result.importedQuizCount} quizzes and ${result.importedSessionCount} sessions imported',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSyncMessage(_formatSyncError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  void _showSyncMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatSyncError(Object error) {
    if (error is CloudSyncFolderAccessException) {
      return 'This folder cannot be used for sync from this device. '
          'If this is OneDrive on a phone, the folder picker may not grant write access. '
          'Try a local app-accessible folder that OneDrive syncs, or sync from desktop.';
    }

    return 'Sync failed: $error';
  }

  Future<void> _openQuiz(Quiz quiz) async {
    final maybeSession = sessionStates[quiz.quizId];

    if (maybeSession?.isCompleted ?? false) {
      final session = maybeSession!;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => QuizResultScreen(
                score: session.lastCompletedScore ?? session.score,
                total: session.lastCompletedTotalQuestions ?? quiz.questions.length,
                elapsedTime: _formatElapsedSeconds(session.elapsedSeconds),
                quiz: quiz,
                sessionState: session,
              ),
        ),
      );

      await _refreshSessionStates();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => QuizPlayScreen(
              quiz: quiz,
              initialSessionState: maybeSession,
            ),
      ),
    );

    await _refreshSessionStates();
  }

  Future<String?> _selectFolder({
    required String title,
    required String initialFolder,
  }) async {
    final options = selectableFolders;
    if (options.isEmpty) {
      return _defaultImportedFolder;
    }

    var selectedFolder =
        options.contains(initialFolder) ? initialFolder : options.first;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: DropdownButtonFormField<String>(
                value: selectedFolder,
                decoration: const InputDecoration(
                  labelText: 'Folder',
                  border: OutlineInputBorder(),
                ),
                items:
                    options
                        .map(
                          (folder) => DropdownMenuItem<String>(
                            value: folder,
                            child: Text(folder),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedFolder = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedFolder),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    final normalizedFolder = folderName?.trim();
    if (normalizedFolder == null || normalizedFolder.isEmpty) return;

    if (normalizedFolder == _builtInFolder) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Built-in is reserved for bundled quizzes')),
      );
      return;
    }

    if (!folders.contains(normalizedFolder)) {
      setState(() {
        folders = [...folders, normalizedFolder]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });

      await _saveImportedQuizzes();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Folder "$normalizedFolder" created')));
  }

  Future<void> _addImportedQuizzes(
    List<Quiz> imported, {
    required String folderName,
  }) async {
    final normalizedFolder =
        folderName.trim().isEmpty ? _defaultImportedFolder : folderName.trim();
    final addedAt = DateTime.now();

    setState(() {
      if (!folders.contains(normalizedFolder)) {
        folders = [...folders, normalizedFolder]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }

      for (final quiz in imported) {
        final exists = quizzes.any((q) => q.quizId == quiz.quizId);
        if (!exists) {
          quizzes.add(
            quiz.copyWith(
              folderName: normalizedFolder,
              addedAt: quiz.addedAt ?? addedAt,
            ),
          );
        }
      }
    });

    await _saveImportedQuizzes();
  }

  Future<void> _moveQuizToFolder(Quiz quiz) async {
    final folder = await _selectFolder(
      title: 'Move Quiz To Folder',
      initialFolder: quiz.folderName,
    );

    if (folder == null || folder.trim().isEmpty) return;

    setState(() {
      if (!folders.contains(folder.trim())) {
        folders = [...folders, folder.trim()]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }

      quizzes =
          quizzes
              .map(
                (existing) =>
                    existing.quizId == quiz.quizId
                        ? existing.copyWith(folderName: folder.trim())
                        : existing,
              )
              .toList();
    });

    await _saveImportedQuizzes();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${quiz.quizName} moved to $folder')));
  }

  Widget _buildStatusChip(Quiz quiz) {
    final assessment = _memoryAssessmentForQuiz(quiz);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 14,
              child: _buildMemoryStrengthBar(assessment),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            assessment.headline,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            assessment.detail,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 2),
          Text(
            'Completed retrieval passes: ${assessment.completedReviewPasses}/3',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryStrengthBar(_MemoryStageAssessment assessment) {
    final stages = <({int index, Color activeColor})>[
      (index: 0, activeColor: Colors.grey.shade400),
      (index: 1, activeColor: Colors.orange.shade300),
      (index: 2, activeColor: Colors.green.shade300),
      (index: 3, activeColor: Colors.green.shade700),
    ];

    return Row(
      children:
          stages.map((stage) {
            final isReached = stage.index <= assessment.stageIndex;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: stage.index == stages.length - 1 ? 0 : 2,
                ),
                color: isReached ? stage.activeColor : Colors.grey.shade200,
              ),
            );
          }).toList(),
    );
  }

  String _formatElapsedSeconds(int elapsedSeconds) {
    final duration = Duration(seconds: elapsedSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }

    return '${seconds}s';
  }

  Widget _buildCompletionTimeText(Quiz quiz) {
    final session = sessionStates[quiz.quizId];
    if (session == null || !session.isCompleted) {
      return const SizedBox.shrink();
    }

    return Text(
      'Completed in ${_formatElapsedSeconds(session.elapsedSeconds)}',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
    );
  }

  String _formatAddedAt(DateTime addedAt) {
    final local = addedAt.toLocal();
    final month = switch (local.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };
    final hour =
        local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';

    return '$month ${local.day}, ${local.year} at $hour:$minute $suffix';
  }

  Widget _buildAddedAtText(Quiz quiz) {
    final addedAt = quiz.addedAt;
    final label =
        addedAt == null
            ? 'Added date unavailable'
            : 'Added ${_formatAddedAt(addedAt)}';

    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
    );
  }

  Future<void> loadJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) return;

    try {
      final folder = await _selectFolder(
        title: 'Folder For Imported Quizzes',
        initialFolder: _defaultImportedFolder,
      );
      if (folder == null) return;

      final imported = await QuizLoader.loadFromFile(result.files.single.path!);
      await _addImportedQuizzes(imported, folderName: folder);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON file loaded into "$folder"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load JSON file: $e')));
    }
  }

  Future<void> pasteJsonText() async {
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Paste Quiz JSON'),
          content: SizedBox(
            width: 600,
            child: TextField(
              controller: textController,
              maxLines: 18,
              decoration: const InputDecoration(
                hintText: 'Paste quiz JSON here',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, textController.text),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty) return;

    try {
      final folder = await _selectFolder(
        title: 'Folder For Imported Quizzes',
        initialFolder: _defaultImportedFolder,
      );
      if (folder == null) return;

      final imported = QuizLoader.parseQuizzes(result);
      await _addImportedQuizzes(imported, folderName: folder);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON text imported into "$folder"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid JSON: $e')));
    }
  }

  Future<void> deleteQuiz(Quiz quiz) async {
    setState(() {
      quizzes.removeWhere((q) => q.quizId == quiz.quizId);
      sessionStates.remove(quiz.quizId);
    });

    await _saveImportedQuizzes();
    await sessionStorage.clearSession(quiz.quizId);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${quiz.quizName} deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final groupedQuizzes = quizzesByFolder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuizGPT'),
        actions: [
          PopupMenuButton<QuizSortOrder>(
            initialValue: _sortOrder,
            tooltip: 'Sort quizzes',
            onSelected: (value) {
              setState(() {
                _sortOrder = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: QuizSortOrder.addedAt,
                child: Text('Sort by add time'),
              ),
              PopupMenuItem(
                value: QuizSortOrder.recallFragility,
                child: Text('Sort by recall fragility'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  _sortOrder == QuizSortOrder.addedAt
                      ? 'Add Time'
                      : 'Fragility',
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) {
              switch (value) {
                case 'new-folder':
                  _createFolder();
                  break;
                case 'sync-folder':
                  if (!_syncing) _selectSyncFolder();
                  break;
                case 'sync-now':
                  if (!_syncing) _syncWithSelectedFolder();
                  break;
                case 'load-json':
                  loadJsonFile();
                  break;
                case 'paste-json':
                  pasteJsonText();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'new-folder',
                    child: Text('New Folder'),
                  ),
                  PopupMenuItem(
                    value: 'sync-folder',
                    enabled: !_syncing,
                    child: const Text('Select Sync Folder'),
                  ),
                  PopupMenuItem(
                    value: 'sync-now',
                    enabled: !_syncing,
                    child: Text(_syncing ? 'Syncing...' : 'Sync Now'),
                  ),
                  const PopupMenuItem(
                    value: 'load-json',
                    child: Text('Load JSON File'),
                  ),
                  const PopupMenuItem(
                    value: 'paste-json',
                    child: Text('Paste JSON'),
                  ),
                ],
          ),
        ],
      ),
      body:
          groupedQuizzes.isEmpty
              ? const Center(child: Text('No quizzes available'))
              : ListView(
                padding: const EdgeInsets.all(16),
                children:
                    groupedQuizzes.entries.map((entry) {
                      final folder = entry.key;
                      final folderQuizzes = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ExpansionTile(
                          key: PageStorageKey<String>('folder:$folder'),
                          initiallyExpanded: false,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(
                            folder,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Text(
                            '${folderQuizzes.length} ${folderQuizzes.length == 1 ? 'quiz' : 'quizzes'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          children:
                              folderQuizzes.map((quiz) {
                                final isBuiltIn =
                                    quiz.quizId.startsWith('builtin_') ||
                                    quiz.folderName == _builtInFolder;

                                return Card(
                                  child: ListTile(
                                    title: Text(quiz.quizName),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(quiz.description),
                                        const SizedBox(height: 6),
                                        _buildAddedAtText(quiz),
                                        if (sessionStates[quiz.quizId]?.isCompleted ??
                                            false)
                                          const SizedBox(height: 6),
                                        _buildCompletionTimeText(quiz),
                                        const SizedBox(height: 8),
                                        _buildStatusChip(quiz),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (sessionStates[quiz.quizId]?.isCompleted ??
                                            false)
                                          IconButton(
                                            icon: const Icon(Icons.replay),
                                            tooltip: 'Redo quiz',
                                            onPressed: () => _openQuiz(quiz),
                                          ),
                                        if (!isBuiltIn)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.drive_file_move_outline,
                                            ),
                                            tooltip: 'Move to folder',
                                            onPressed: () => _moveQuizToFolder(quiz),
                                          ),
                                        if (!isBuiltIn)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            tooltip: 'Delete quiz',
                                            onPressed: () => deleteQuiz(quiz),
                                          ),
                                        const Icon(Icons.arrow_forward),
                                      ],
                                    ),
                                    onTap: () => _openQuiz(quiz),
                                  ),
                                );
                              }).toList(),
                        ),
                      );
                    }).toList(),
              ),
    );
  }
}
