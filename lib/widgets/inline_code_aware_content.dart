import 'package:flutter/material.dart';
import 'quiz_rich_content.dart';

class InlineCodeAwareContent extends StatelessWidget {
  final String data;
  final TextStyle? baseStyle;

  const InlineCodeAwareContent({super.key, required this.data, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = baseStyle ?? theme.textTheme.bodyLarge ?? const TextStyle();

    final text = data.trim();

    // If there are no inline backticks, just use the normal rich renderer.
    if (!text.contains('`')) {
      return QuizRichContent(data: text, baseStyle: style);
    }

    // If there are fenced code blocks, let the existing markdown renderer handle them.
    if (text.contains('```')) {
      return QuizRichContent(data: text, baseStyle: style);
    }

    final parts = <Widget>[];
    final regex = RegExp(r'`([^`]+)`');
    int currentIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        final normalText = text.substring(currentIndex, match.start);
        if (normalText.isNotEmpty) {
          parts.add(QuizRichContent(data: normalText, baseStyle: style));
        }
      }

      final codeText = match.group(1)!;
      parts.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            codeText,
            style: style.copyWith(
              fontFamily: 'monospace',
              fontSize: (style.fontSize ?? 16) * 0.95,
            ),
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      final trailingText = text.substring(currentIndex);
      if (trailingText.isNotEmpty) {
        parts.add(QuizRichContent(data: trailingText, baseStyle: style));
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: parts,
    );
  }
}
