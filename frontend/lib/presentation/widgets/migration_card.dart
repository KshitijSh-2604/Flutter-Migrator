import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../data/models/migration_model.dart';

class MigrationCard extends StatelessWidget {
  final MigrationModel migration;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MigrationCard({
    super.key,
    required this.migration,
    required this.onTap,
    required this.onDelete,
  });

  Color _statusColor() => switch (migration.status) {
    'completed' => Colors.green,
    'failed'    => Colors.red,
    _           => Colors.orange,
  };

  IconData _statusIcon() => switch (migration.status) {
    'completed' => Icons.check_circle_outline_rounded,
    'failed'    => Icons.error_outline_rounded,
    _           => Icons.hourglass_top_rounded,
  };

  IconData _sourceIcon() => switch (migration.sourceType) {
    'zip'    => Icons.folder_zip_outlined,
    'github' => Icons.link_rounded,
    'file'   => Icons.insert_drive_file_outlined,
    _        => Icons.code_rounded,
  };

  String _sourceLabel() => switch (migration.sourceType) {
    'zip'    => 'ZIP',
    'github' => 'GitHub',
    'file'   => '.dart',
    _        => 'Paste',
  };

  @override
  Widget build(BuildContext context) {
    final fmt   = DateFormat('MMM d, y • h:mm a');
    final cs    = Theme.of(context).colorScheme;
    final color = _statusColor();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Status avatar ────────────────────────────────────────────
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(_statusIcon(), color: color, size: 22),
              ),
              const Gap(14),

              // ── Main text block ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            migration.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(6),
                        _SmallBadge(
                          icon: _sourceIcon(),
                          label: _sourceLabel(),
                          color: Colors.blueGrey,
                        ),
                      ],
                    ),
                    const Gap(4),

                    // Version arrow row
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 13,
                          color: cs.onSurface.withOpacity(0.45),
                        ),
                        const Gap(4),
                        Text(
                          '${migration.flutterVersionFrom ?? "?"}'
                              '  →  '
                              '${migration.flutterVersionTo ?? "latest"}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        if (migration.filesAnalyzed > 1) ...[
                          const Gap(10),
                          Icon(
                            Icons.description_rounded,
                            size: 12,
                            color: cs.onSurface.withOpacity(0.45),
                          ),
                          const Gap(3),
                          Text(
                            '${migration.filesAnalyzed} files',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(4),

                    // Date + confidence row
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: cs.onSurface.withOpacity(0.4),
                        ),
                        const Gap(4),
                        Text(
                          fmt.format(migration.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ),
                        if (migration.confidenceScore != null) ...[
                          const Gap(12),
                          _ConfidencePill(score: migration.confidenceScore!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const Gap(10),

              // ── Right side: status + delete ───────────────────────────────
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SmallBadge(
                    label: migration.status,
                    color: color,
                    compact: true,
                  ),
                  const Gap(10),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: cs.error,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Confidence pill ───────────────────────────────────────────────────────────

class _ConfidencePill extends StatelessWidget {
  final int score;
  const _ConfidencePill({required this.score});

  Color get _color {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        border: Border.all(color: _color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 11, color: _color),
          const Gap(3),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small badge ───────────────────────────────────────────────────────────────

class _SmallBadge extends StatelessWidget {
  final String  label;
  final Color   color;
  final IconData? icon;
  final bool    compact;

  const _SmallBadge({
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}