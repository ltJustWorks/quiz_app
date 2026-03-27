import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;

class QuizRichContent extends StatelessWidget {
  final String data;
  final TextStyle? baseStyle;

  const QuizRichContent({super.key, required this.data, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = baseStyle ?? theme.textTheme.bodyLarge!;

    final trimmed = data.trim();

    // If the content contains inline code but not fenced blocks,
    // render inline-code manually so backticks never show literally.
    final hasInlineCode = RegExp(r'`[^`]+`').hasMatch(trimmed);
    final hasFencedCode = trimmed.contains('```');

    if (hasInlineCode && !hasFencedCode) {
      return _InlineCodeRichText(data: trimmed, baseStyle: defaultStyle);
    }

    return MarkdownBody(
      data: trimmed,
      shrinkWrap: true,
      selectable: false,
      builders: {'latex': LatexElementBuilder(textStyle: defaultStyle)},
      extensionSet: md.ExtensionSet(
        [...md.ExtensionSet.gitHubFlavored.blockSyntaxes, LatexBlockSyntax()],
        [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
      ),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: defaultStyle,
        code: defaultStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: (defaultStyle.fontSize ?? 16) * 0.95,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _InlineCodeRichText extends StatelessWidget {
  final String data;
  final TextStyle baseStyle;

  const _InlineCodeRichText({required this.data, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <InlineSpan>[];

    final regex = RegExp(r'`([^`]+)`');
    int currentIndex = 0;

    for (final match in regex.allMatches(data)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: data.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final codeText = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              codeText,
              style: baseStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 16) * 0.95,
              ),
            ),
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < data.length) {
      spans.add(TextSpan(text: data.substring(currentIndex), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
