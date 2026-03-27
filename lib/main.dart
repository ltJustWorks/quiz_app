import 'package:flutter/material.dart';
import 'models/quiz.dart';
import 'services/quiz_loader.dart';
import 'services/quiz_storage_service.dart';
import 'screens/quiz_list_screen.dart';
import 'models/quiz_session_state.dart';
import 'services/quiz_session_storage_service.dart';

void main() {
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuizGPT',
      theme: ThemeData(useMaterial3: true),
      restorationScopeId: 'app',
      home: const QuizBootstrapScreen(),
    );
  }
}

class QuizBootstrapScreen extends StatefulWidget {
  const QuizBootstrapScreen({super.key});

  @override
  State<QuizBootstrapScreen> createState() => _QuizBootstrapScreenState();
}

class _QuizBootstrapScreenState extends State<QuizBootstrapScreen> {
  late Future<_BootstrapData> futureData;

  Future<_BootstrapData> _loadAllData() async {
    final assetQuizzes =
        (await QuizLoader.loadFromAssets('assets/quizzes/sample_quizzes.json'))
            .map(
              (quiz) => quiz.copyWith(folderName: 'Built-in', addedAt: null),
            )
            .toList();

    final storage = QuizStorageService();
    final savedQuizzes = await storage.loadSavedQuizzes();

    final merged = [...assetQuizzes];
    for (final quiz in savedQuizzes) {
      final alreadyExists = merged.any((q) => q.quizId == quiz.quizId);
      if (!alreadyExists) {
        merged.add(quiz);
      }
    }

    final sessionStorage = QuizSessionStorageService();
    final sessions = await sessionStorage.loadSessions();
    final latestIncompleteSession = sessions.values
        .where((session) => !session.isCompleted)
        .fold<QuizSessionState?>(
          null,
          (latest, session) {
            if (latest == null) {
              return session;
            }

            final latestTimestamp =
                latest.lastInteractedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final sessionTimestamp =
                session.lastInteractedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return sessionTimestamp.isAfter(latestTimestamp) ? session : latest;
          },
        );

    return _BootstrapData(
      quizzes: merged,
      sessions: sessions,
      initialResumeQuizId: latestIncompleteSession?.quizId,
    );
  }

  @override
  void initState() {
    super.initState();
    futureData = _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapData>(
      future: futureData,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final data = snapshot.data!;
        return QuizListScreen(
          initialQuizzes: data.quizzes,
          initialSessionStates: data.sessions,
          initialResumeQuizId: data.initialResumeQuizId,
        );
      },
    );
  }
}

class _BootstrapData {
  final List<Quiz> quizzes;
  final Map<String, QuizSessionState> sessions;
  final String? initialResumeQuizId;

  _BootstrapData({
    required this.quizzes,
    required this.sessions,
    required this.initialResumeQuizId,
  });
}
