import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app/models/option.dart';
import 'package:quiz_app/models/question.dart';
import 'package:quiz_app/models/quiz.dart';
import 'package:quiz_app/models/quiz_session_state.dart';
import 'package:quiz_app/screens/quiz_list_screen.dart';
import 'package:quiz_app/services/cloud_sync_service.dart';

void main() {
  Quiz buildQuiz({
    String quizId = 'quiz-1',
    String quizName = 'Sample Quiz',
    DateTime? addedAt,
  }) {
    return Quiz(
      quizId: quizId,
      quizName: quizName,
      description: 'A short quiz.',
      folderName: 'Science',
      addedAt: addedAt ?? DateTime(2026, 3, 26, 14, 30),
      questions: [
        QuizQuestion(
          id: 'q1',
          prompt: 'Question 1',
          options: [
            QuizOption(label: 'A', text: 'One'),
            QuizOption(label: 'B', text: 'Two'),
          ],
          correctAnswer: 'A',
          hint: 'Hint',
          explanation: 'Explanation',
        ),
        QuizQuestion(
          id: 'q2',
          prompt: 'Question 2',
          options: [
            QuizOption(label: 'A', text: 'Three'),
            QuizOption(label: 'B', text: 'Four'),
          ],
          correctAnswer: 'B',
          hint: 'Hint',
          explanation: 'Explanation',
        ),
      ],
    );
  }

  QuizSessionState buildSession({
    required String quizId,
    required bool isCompleted,
    required Map<int, QuizQuestionProgressState> questionProgress,
    int currentIndex = 0,
    int score = 0,
    int elapsedSeconds = 0,
    int furthestReachedQuestionIndex = 0,
    int completedReviewPasses = 0,
    double bestPartialReviewPass = 0,
    int completedRunCount = 0,
    int cumulativeElapsedSeconds = 0,
    int? lastCompletedScore,
    int? lastCompletedTotalQuestions,
    DateTime? lastCompletedAt,
    DateTime? lastInteractedAt,
  }) {
    return QuizSessionState(
      quizId: quizId,
      currentIndex: currentIndex,
      score: score,
      wrongAnswers: const [],
      correctSelected: null,
      isCompleted: isCompleted,
      lastInteractedAt: lastInteractedAt ?? DateTime(2026),
      elapsedSeconds: elapsedSeconds,
      questionProgress: questionProgress,
      furthestReachedQuestionIndex: furthestReachedQuestionIndex,
      completedReviewPasses: completedReviewPasses,
      bestPartialReviewPass: bestPartialReviewPass,
      completedRunCount: completedRunCount,
      cumulativeElapsedSeconds: cumulativeElapsedSeconds,
      lastCompletedScore: lastCompletedScore,
      lastCompletedTotalQuestions: lastCompletedTotalQuestions,
      lastCompletedAt: lastCompletedAt,
    );
  }

  testWidgets('shows memory stage summary and review passes for incomplete quizzes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizListScreen(
          initialQuizzes: [buildQuiz()],
          initialFolders: const ['Science'],
          initialSessionStates: {
            'quiz-1': buildSession(
              quizId: 'quiz-1',
              isCompleted: false,
              currentIndex: 1,
              score: 1,
              elapsedSeconds: 42,
              furthestReachedQuestionIndex: 1,
              bestPartialReviewPass: 0.5,
              questionProgress: const {
                0: QuizQuestionProgressState(
                  wrongAnswers: [],
                  correctSelected: 'A',
                ),
                1: QuizQuestionProgressState(
                  wrongAnswers: [],
                  correctSelected: null,
                ),
              },
            ),
          },
        ),
      ),
    );

    await tester.tap(find.text('Science'));
    await tester.pumpAndSettle();

    expect(find.text('Memory stage: New'), findsOneWidget);
    expect(find.text('No completed retrieval pass yet'), findsOneWidget);
    expect(find.text('Completed retrieval passes: 0/3'), findsOneWidget);
    expect(find.text('Added Mar 26, 2026 at 2:30 PM'), findsOneWidget);
  });

  testWidgets('shows completed quiz summary and redo action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizListScreen(
          initialQuizzes: [buildQuiz()],
          initialFolders: const ['Science'],
          initialSessionStates: {
            'quiz-1': buildSession(
              quizId: 'quiz-1',
              isCompleted: true,
              currentIndex: 1,
              score: 2,
              elapsedSeconds: 125,
              furthestReachedQuestionIndex: 1,
              completedReviewPasses: 2,
              completedRunCount: 2,
              cumulativeElapsedSeconds: 240,
              lastCompletedScore: 2,
              lastCompletedTotalQuestions: 2,
              lastCompletedAt: DateTime(2026, 3, 26, 15, 0),
              questionProgress: const {
                0: QuizQuestionProgressState(
                  wrongAnswers: [],
                  correctSelected: 'A',
                ),
                1: QuizQuestionProgressState(
                  wrongAnswers: [],
                  correctSelected: 'B',
                ),
              },
            ),
          },
        ),
      ),
    );

    await tester.tap(find.text('Science'));
    await tester.pumpAndSettle();

    expect(find.text('Memory stage: Consolidating'), findsOneWidget);
    expect(find.text('Two completed retrieval passes | strengthening'), findsOneWidget);
    expect(find.text('Completed retrieval passes: 2/3'), findsOneWidget);
    expect(find.text('Completed in 2m 5s'), findsOneWidget);
    expect(find.byIcon(Icons.replay), findsOneWidget);
  });

  testWidgets('folder subtitle no longer shows sort text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizListScreen(
          initialQuizzes: [buildQuiz()],
          initialFolders: const ['Science'],
          initialSessionStates: const {},
        ),
      ),
    );

    expect(find.text('Science'), findsOneWidget);
    expect(find.text('1 quiz'), findsOneWidget);
    expect(find.textContaining('sorted by'), findsNothing);
    expect(find.text('Sample Quiz'), findsNothing);
  });

  testWidgets('sort by recall fragility uses review pass depth', (tester) async {
    final newerQuiz = buildQuiz(
      quizId: 'quiz-newer',
      quizName: 'Newer Quiz',
      addedAt: DateTime(2026, 3, 20),
    );
    final reviewedQuiz = buildQuiz(
      quizId: 'quiz-reviewed',
      quizName: 'Reviewed Quiz',
      addedAt: DateTime(2026, 3, 27),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QuizListScreen(
          initialQuizzes: [reviewedQuiz, newerQuiz],
          initialFolders: const ['Science'],
          initialSessionStates: {
            'quiz-newer': buildSession(
              quizId: 'quiz-newer',
              isCompleted: false,
              bestPartialReviewPass: 0.25,
              questionProgress: const {},
            ),
            'quiz-reviewed': buildSession(
              quizId: 'quiz-reviewed',
              isCompleted: true,
              completedReviewPasses: 2,
              completedRunCount: 2,
              lastCompletedScore: 2,
              lastCompletedTotalQuestions: 2,
              questionProgress: const {
                0: QuizQuestionProgressState(
                  wrongAnswers: [],
                  correctSelected: 'A',
                ),
                1: QuizQuestionProgressState(
                  wrongAnswers: [],
                  correctSelected: 'B',
                ),
              },
            ),
          },
        ),
      ),
    );

    await tester.tap(find.text('Science'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Reviewed Quiz')).dy,
      lessThan(tester.getTopLeft(find.text('Newer Quiz')).dy),
    );

    await tester.tap(find.text('Add Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort by recall fragility'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Newer Quiz')).dy,
      lessThan(tester.getTopLeft(find.text('Reviewed Quiz')).dy),
    );
  });

  test('sync keeps a newer redo session active over an older completed session', () async {
    final syncDir = await Directory.systemTemp.createTemp('quiz-sync-test-');
    addTearDown(() => syncDir.delete(recursive: true));

    final remoteCompleted = buildSession(
      quizId: 'quiz-1',
      isCompleted: true,
      currentIndex: 1,
      score: 2,
      furthestReachedQuestionIndex: 1,
      completedReviewPasses: 1,
      completedRunCount: 1,
      lastCompletedScore: 2,
      lastCompletedTotalQuestions: 2,
      lastCompletedAt: DateTime(2026, 1, 1),
      lastInteractedAt: DateTime(2026, 1, 1),
      questionProgress: const {
        0: QuizQuestionProgressState(wrongAnswers: [], correctSelected: 'A'),
        1: QuizQuestionProgressState(wrongAnswers: [], correctSelected: 'B'),
      },
    );
    final localRedo = buildSession(
      quizId: 'quiz-1',
      isCompleted: false,
      currentIndex: 0,
      score: 0,
      completedReviewPasses: 1,
      completedRunCount: 1,
      lastCompletedScore: 2,
      lastCompletedTotalQuestions: 2,
      lastCompletedAt: DateTime(2026, 1, 1),
      lastInteractedAt: DateTime(2026, 1, 2),
      questionProgress: const {},
    );

    await File('${syncDir.path}${Platform.pathSeparator}quizgpt_sync.json')
        .writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
        'quizzes': const [],
        'folders': const [],
        'sessions': {'quiz-1': remoteCompleted.toJson()},
      }),
    );

    final result = await CloudSyncService().sync(
      folderPath: syncDir.path,
      localQuizzes: const [],
      localFolders: const [],
      localSessions: {'quiz-1': localRedo},
    );

    final merged = result.sessions['quiz-1']!;
    expect(merged.isCompleted, isFalse);
    expect(merged.currentIndex, 0);
    expect(merged.completedReviewPasses, 1);
    expect(merged.lastCompletedScore, 2);
  });

  test('sync keeps in-progress resume position over a newer blank session', () async {
    final syncDir = await Directory.systemTemp.createTemp('quiz-sync-test-');
    addTearDown(() => syncDir.delete(recursive: true));

    final remoteBlank = buildSession(
      quizId: 'quiz-1',
      isCompleted: false,
      currentIndex: 0,
      lastInteractedAt: DateTime(2026, 1, 2),
      questionProgress: const {},
    );
    final localProgress = buildSession(
      quizId: 'quiz-1',
      isCompleted: false,
      currentIndex: 1,
      score: 1,
      furthestReachedQuestionIndex: 1,
      lastInteractedAt: DateTime(2026, 1, 1),
      questionProgress: const {
        0: QuizQuestionProgressState(wrongAnswers: [], correctSelected: 'A'),
      },
    );

    await File('${syncDir.path}${Platform.pathSeparator}quizgpt_sync.json')
        .writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
        'quizzes': const [],
        'folders': const [],
        'sessions': {'quiz-1': remoteBlank.toJson()},
      }),
    );

    final result = await CloudSyncService().sync(
      folderPath: syncDir.path,
      localQuizzes: const [],
      localFolders: const [],
      localSessions: {'quiz-1': localProgress},
    );

    final merged = result.sessions['quiz-1']!;
    expect(merged.isCompleted, isFalse);
    expect(merged.currentIndex, 1);
    expect(merged.questionProgress[0]?.correctSelected, 'A');
  });

  test('session memory stage fields do not downgrade when preserving existing state', () {
    final existing = buildSession(
      quizId: 'quiz-1',
      isCompleted: true,
      currentIndex: 1,
      score: 2,
      completedReviewPasses: 3,
      bestPartialReviewPass: 0.75,
      completedRunCount: 3,
      cumulativeElapsedSeconds: 300,
      lastCompletedScore: 2,
      lastCompletedTotalQuestions: 2,
      lastCompletedAt: DateTime(2026, 1, 3),
      questionProgress: const {
        0: QuizQuestionProgressState(wrongAnswers: [], correctSelected: 'A'),
        1: QuizQuestionProgressState(wrongAnswers: [], correctSelected: 'B'),
      },
    );
    final staleIncoming = buildSession(
      quizId: 'quiz-1',
      isCompleted: false,
      currentIndex: 0,
      completedReviewPasses: 0,
      bestPartialReviewPass: 0,
      completedRunCount: 0,
      cumulativeElapsedSeconds: 0,
      questionProgress: const {},
    );

    final protected = staleIncoming.preserveMemoryStageFrom(existing);

    expect(protected.isCompleted, isFalse);
    expect(protected.completedReviewPasses, 3);
    expect(protected.bestPartialReviewPass, 0.75);
    expect(protected.completedRunCount, 3);
    expect(protected.cumulativeElapsedSeconds, 300);
    expect(protected.lastCompletedScore, 2);
    expect(protected.lastCompletedTotalQuestions, 2);
    expect(protected.lastCompletedAt, DateTime(2026, 1, 3));
  });

  test('legacy completed sessions infer a completed retrieval pass', () {
    final session = QuizSessionState.fromJson({
      'quizId': 'quiz-1',
      'currentIndex': 1,
      'score': 2,
      'wrongAnswers': const [],
      'correctSelected': 'B',
      'isCompleted': true,
      'lastInteractedAt': DateTime(2026, 1, 1).toIso8601String(),
    });

    expect(session.completedReviewPasses, 1);
    expect(session.completedRunCount, 1);
    expect(session.lastCompletedScore, 2);
    expect(session.lastCompletedAt, DateTime(2026, 1, 1));
  });
}
