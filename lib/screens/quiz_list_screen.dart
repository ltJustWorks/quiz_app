import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/quiz_loader.dart';
import '../services/quiz_session_storage_service.dart';
import '../services/quiz_storage_service.dart';
import '../models/quiz_session_state.dart';
import 'quiz_play_screen.dart';

class QuizListScreen extends StatefulWidget {
  final List<Quiz> initialQuizzes;
  final Map<String, QuizSessionState> initialSessionStates;
  final String? initialResumeQuizId;

  const QuizListScreen({
    super.key,
    required this.initialQuizzes,
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
  final QuizStorageService storage = QuizStorageService();
  final QuizSessionStorageService sessionStorage = QuizSessionStorageService();
  late Map<String, QuizSessionState> sessionStates;
  bool _didAutoResume = false;

  @override
  void initState() {
    super.initState();
    quizzes = List.from(widget.initialQuizzes);
    sessionStates = Map.from(widget.initialSessionStates);
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

  Map<String, List<Quiz>> get quizzesByFolder {
    final grouped = <String, List<Quiz>>{};

    for (final quiz in quizzes) {
      grouped.putIfAbsent(quiz.folderName, () => []).add(quiz);
    }

    for (final folderQuizzes in grouped.values) {
      folderQuizzes.sort(
        (a, b) {
          final aAddedAt = a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bAddedAt = b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bAddedAt.compareTo(aAddedAt);
        },
      );
    }

    return Map.fromEntries(
      grouped.entries.toList()
        ..sort(
          (a, b) {
            final aLatest =
                a.value
                    .map(
                      (quiz) =>
                          quiz.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                    )
                    .fold<DateTime>(
                      DateTime.fromMillisecondsSinceEpoch(0),
                      (latest, date) => date.isAfter(latest) ? date : latest,
                    );
            final bLatest =
                b.value
                    .map(
                      (quiz) =>
                          quiz.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                    )
                    .fold<DateTime>(
                      DateTime.fromMillisecondsSinceEpoch(0),
                      (latest, date) => date.isAfter(latest) ? date : latest,
                    );
            return bLatest.compareTo(aLatest);
          },
        ),
    );
  }

  Future<void> _saveImportedQuizzes() async {
    await storage.saveQuizzes(importedQuizzes);
  }

  Future<void> _refreshSessionStates() async {
    final latestSessions = await sessionStorage.loadSessions();
    if (!mounted) return;

    setState(() {
      sessionStates = latestSessions;
    });
  }

  Future<void> _openQuiz(Quiz quiz) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => QuizPlayScreen(
              quiz: quiz,
              initialSessionState: sessionStates[quiz.quizId],
            ),
      ),
    );

    await _refreshSessionStates();
  }

  Future<String?> _promptForFolder({
    required String title,
    required String initialFolder,
  }) async {
    final controller = TextEditingController(text: initialFolder);

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addImportedQuizzes(
    List<Quiz> imported, {
    required String folderName,
  }) async {
    final normalizedFolder =
        folderName.trim().isEmpty ? _defaultImportedFolder : folderName.trim();
    final addedAt = DateTime.now();

    setState(() {
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
    final folder = await _promptForFolder(
      title: 'Move Quiz To Folder',
      initialFolder: quiz.folderName,
    );

    if (folder == null || folder.trim().isEmpty) return;

    setState(() {
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
    final session = sessionStates[quiz.quizId];
    final answeredCount =
        session?.answeredQuestionsCount(quiz.questions.length) ?? 0;

    if (session == null) {
      return Chip(
        avatar: const Icon(Icons.radio_button_unchecked, size: 18),
        label: Text('Not completed: 0/${quiz.questions.length}'),
      );
    }

    if (session.isCompleted) {
      return Chip(
        avatar: const Icon(Icons.check_circle, size: 18),
        backgroundColor: Colors.green.shade100,
        label: const Text('Completed'),
      );
    }

    return Chip(
      avatar: const Icon(Icons.timelapse, size: 18),
      backgroundColor: Colors.orange.shade100,
      label: Text('In progress: $answeredCount/${quiz.questions.length}'),
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
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
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
      final folder = await _promptForFolder(
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
      final folder = await _promptForFolder(
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
          TextButton(
            onPressed: loadJsonFile,
            child: const Text('Load JSON File'),
          ),
          TextButton(onPressed: pasteJsonText, child: const Text('Paste JSON')),
        ],
      ),
      body:
          quizzes.isEmpty
              ? const Center(child: Text('No quizzes available'))
              : ListView(
                padding: const EdgeInsets.all(16),
                children:
                    groupedQuizzes.entries.map((entry) {
                      final folder = entry.key;
                      final folderQuizzes = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_outlined),
                                const SizedBox(width: 8),
                                Text(
                                  folder,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${folderQuizzes.length} ${folderQuizzes.length == 1 ? 'quiz' : 'quizzes'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...folderQuizzes.map((quiz) {
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
                                      const SizedBox(height: 8),
                                      _buildStatusChip(quiz),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isBuiltIn)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.drive_file_move_outline,
                                          ),
                                          tooltip: 'Move to folder',
                                          onPressed:
                                              () => _moveQuizToFolder(quiz),
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
                            }),
                          ],
                        ),
                      );
                    }).toList(),
              ),
    );
  }
}
