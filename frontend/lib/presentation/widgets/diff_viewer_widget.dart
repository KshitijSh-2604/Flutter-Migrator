import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

class DiffViewerWidget extends StatelessWidget {
  final String original;
  final String migrated;

  const DiffViewerWidget({
    super.key,
    required this.original,
    required this.migrated,
  });

  @override
  Widget build(BuildContext context) {
    if (original.isEmpty || migrated.isEmpty) {
      return const Center(child: Text('No comparison available.'));
    }

    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(original, migrated);
    dmp.diffCleanupSemantic(diffs);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF282C34) : Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                _LegendItem(color: Colors.red, label: 'Deleted'),
                const SizedBox(width: 16),
                _LegendItem(color: Colors.green, label: 'Added'),
                const SizedBox(width: 16),
                const _LegendItem(color: Colors.transparent, label: 'Unchanged'),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText.rich(
                TextSpan(
                  children: diffs.map((diff) {
                    final operation = diff.operation;
                    final text = diff.text;

                    Color? color;
                    TextDecoration? decoration;
                    Color? bgColor;

                    if (operation == DIFF_INSERT) {
                      color = Colors.green;
                      bgColor = Colors.green.withValues(alpha: 0.1);
                    } else if (operation == DIFF_DELETE) {
                      color = Colors.red;
                      decoration = TextDecoration.lineThrough;
                      bgColor = Colors.red.withValues(alpha: 0.1);
                    }

                    return TextSpan(
                      text: text,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: color,
                        backgroundColor: bgColor,
                        decoration: decoration,
                        height: 1.5,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: color == Colors.transparent
                ? Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5))
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
