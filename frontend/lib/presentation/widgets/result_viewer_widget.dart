import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

class ResultViewerWidget extends StatelessWidget {
  final String code;
  final String language;
  final String emptyMessage;

  const ResultViewerWidget({
    super.key,
    required this.code,
    this.language = 'dart',
    this.emptyMessage = 'No code available.',
  });

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF282C34) : Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(Icons.code, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  language.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HighlightView(
                  code,
                  language: language,
                  theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}