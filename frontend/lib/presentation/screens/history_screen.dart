import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../providers/migration_provider.dart';
import '../widgets/migration_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all'; // all | completed | failed

  @override
  void initState() {
    super.initState();
    // Refresh history every time this screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MigrationProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MigrationProvider>();

    // Apply filter
    final all = provider.migrations;
    final filtered = _filter == 'all'
        ? all
        : all.where((m) => m.status == _filter).toList();

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Migration History'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/images/landing_bg.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                BlendMode.multiply,
              ),
            ),
          ),
        ),
        actions: [
          // Filter chip row
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  count: all.length,
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const Gap(6),
                _FilterChip(
                  label: 'Done',
                  count: all.where((m) => m.status == 'completed').length,
                  selected: _filter == 'completed',
                  color: Colors.green,
                  onTap: () => setState(() => _filter = 'completed'),
                ),
                const Gap(6),
                _FilterChip(
                  label: 'Failed',
                  count: all.where((m) => m.status == 'failed').length,
                  selected: _filter == 'failed',
                  color: Colors.red,
                  onTap: () => setState(() => _filter = 'failed'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
          ? _EmptyState(filter: _filter)
          : RefreshIndicator(
        onRefresh: () => provider.loadHistory(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Gap(8),
          itemBuilder: (context, index) {
            final migration = filtered[index];
            return MigrationCard(
              migration: migration,
              onTap: () {
                provider.setCurrentMigration(migration);
                Navigator.pushNamed(context, '/result');
              },
              onDelete: () => _confirmDelete(context, provider, migration.id),
            )
                .animate()
                .fadeIn(
              delay: Duration(milliseconds: index * 40),
              duration: 250.ms,
            )
                .slideY(begin: 0.05, end: 0);
          },
        ),
      ),
    ));
  }

  Future<void> _confirmDelete(
      BuildContext context,
      MigrationProvider provider,
      int id,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        title: const Text('Delete migration?'),
        content: const Text(
          'This will permanently remove the migration record and '
              'all its results. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await provider.deleteMigration(id);
    }
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String   label;
  final int      count;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = selected ? color : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? effectiveColor.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? effectiveColor.withValues(alpha: 0.6)
                : Colors.grey.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? effectiveColor : Colors.grey,
              ),
            ),
            const Gap(5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: effectiveColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isFiltered = filter != 'all';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered
                ? Icons.filter_list_off_rounded
                : Icons.history_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const Gap(16),
          Text(
            isFiltered
                ? 'No $filter migrations'
                : 'No migrations yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(8),
          Text(
            isFiltered
                ? 'Try changing the filter above.'
                : 'Run your first migration to see it here.',
            style: TextStyle(
              color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (!isFiltered) ...[
            const Gap(24),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/migrate'),
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Start Migrating'),
            ),
          ],
        ],
      ),
    );
  }
}