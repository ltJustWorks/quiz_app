import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'dart:async';
import '../models/quiz.dart';
import '../controllers/quiz_controller.dart';
import '../widgets/quiz_rich_content.dart';
import '../models/quiz_session_state.dart';
import '../services/quiz_session_storage_service.dart';
import 'quiz_result_screen.dart';

class QuizPlayScreen extends StatefulWidget {
  final Quiz quiz;
  final QuizSessionState? initialSessionState;

  const QuizPlayScreen({
    super.key,
    required this.quiz,
    this.initialSessionState,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen>
    with WidgetsBindingObserver {
  late QuizController controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    controller = QuizController(
      widget.quiz,
      sessionStorage: QuizSessionStorageService(),
      initialState: widget.initialSessionState,
    );
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_onControllerChanged);

    if (widget.initialSessionState == null ||
        !widget.initialSessionState!.isCompleted) {
      controller.saveProgress();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.pauseTracking();
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      controller.pauseTracking();
    }

    if (state == AppLifecycleState.resumed) {
      controller.resumeTracking();
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildOptionContent(String text) {
    final trimmed = text.trim();

    final isPureInlineLatex =
        trimmed.startsWith(r'$') &&
        trimmed.endsWith(r'$') &&
        trimmed.length > 2 &&
        !trimmed.substring(1, trimmed.length - 1).contains(r'$');

    final containsMarkdownOrRichFormatting =
        trimmed.contains('`') ||
        trimmed.contains('```') ||
        trimmed.contains(r'$') ||
        trimmed.contains(r'\(') ||
        trimmed.contains(r'\[');

    if (isPureInlineLatex) {
      final latex = trimmed.substring(1, trimmed.length - 1);

      return Math.tex(latex, textStyle: Theme.of(context).textTheme.bodyLarge);
    }

    if (containsMarkdownOrRichFormatting) {
      return QuizRichContent(
        data: trimmed,
        baseStyle: Theme.of(context).textTheme.bodyLarge,
      );
    }

    return Text(trimmed, style: Theme.of(context).textTheme.bodyLarge);
  }

  Widget _buildOptionCard(String label, String text) {
    Color backgroundColor;
    Color borderColor;

    if (controller.isCorrectSelected(label)) {
      backgroundColor = Colors.green.shade100;
      borderColor = Colors.green;
    } else if (controller.isWrongSelected(label)) {
      backgroundColor = Colors.red.shade100;
      borderColor = Colors.red;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = Colors.grey.shade300;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap:
              controller.hasAnsweredCorrectly
                  ? null
                  : () => controller.selectAnswer(label),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "$label.",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildOptionContent(text)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = controller.currentQuestion;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.quiz.quizName),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Question ${controller.currentIndex + 1} / ${widget.quiz.questions.length}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Time: ${controller.formattedElapsedTime}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  QuizRichContent(
                    data: q.prompt,
                    baseStyle: Theme.of(context).textTheme.headlineSmall,
                  ),

                  const SizedBox(height: 24),

                  ...q.options.map(
                    (option) => _buildOptionCard(option.label, option.text),
                  ),

                  const SizedBox(height: 16),

                  if (controller.feedbackMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QuizRichContent(data: controller.feedbackMessage!),
                    ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed:
                            controller.canGoToPreviousQuestion
                                ? controller.previousQuestion
                                : null,
                        child: const Text("Previous"),
                      ),
                      if (controller.hasAnsweredCorrectly)
                        ElevatedButton(
                          onPressed: () async {
                            if (controller.isLastQuestion) {
                              await controller.completeQuiz();
                              if (!context.mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => QuizResultScreen(
                                        score: controller.score,
                                        total: widget.quiz.questions.length,
                                        elapsedTime:
                                            controller.formattedElapsedTime,
                                        quiz: widget.quiz,
                                        sessionState:
                                            controller.currentSessionSnapshot,
                                      ),
                                ),
                              );
                            } else {
                              controller.nextQuestion();
                            }
                          },
                          child: Text(
                            controller.isLastQuestion ? "Finish" : "Next",
                          ),
                        )
                      else
                        OutlinedButton(
                          onPressed:
                              controller.canGoToNextQuestion
                                  ? controller.nextQuestion
                                  : null,
                          child: const Text("Next"),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
