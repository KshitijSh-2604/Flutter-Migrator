import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../providers/migration_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MigrationProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MigrationProvider>();
    final cs = Theme.of(context).colorScheme;
    final history = provider.migrations;

    final completed = history.where((m) => m.status == 'completed').length;
    final failed    = history.where((m) => m.status == 'failed').length;
    final avgConf   = history
        .where((m) => m.confidenceScore != null)
        .map((m) => m.confidenceScore!)
        .fold<int>(0, (a, b) => a + b);
    final confCount = history.where((m) => m.confidenceScore != null).length;
    final avgConfScore = confCount > 0 ? avgConf ~/ confCount : null;

    return SelectionArea(
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // ── Hero header ────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 225,
              pinned: true,
              stretch: true,
              backgroundColor: cs.primary,
              centerTitle: true,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final double top = constraints.biggest.height;
                  final double expandedHeight = 225.0;
                  final double minHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
                  
                  // progress: 0.0 (collapsed) to 1.0 (fully expanded)
                  final double progress = ((top - minHeight) / (expandedHeight - minHeight)).clamp(0.0, 1.0);
                  
                  // Dynamic sizes based on progress
                  final double iconSize = 32 + (64 * progress);   // 32 to 96
                  final double fontSize = 20 + (20 * progress);   // 20 to 40
                  final double gapWidth = 8 + (12 * progress);    // 8 to 20

                  return FlexibleSpaceBar(
                    expandedTitleScale: 1.0,
                    centerTitle: true,
                    titlePadding: EdgeInsets.zero,
                    title: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(iconSize * 0.25),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              height: iconSize * 0.75,
                              width: iconSize * 0.75,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Gap(gapWidth),
                          Text(
                            'Flutter Migrator',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: fontSize,
                              color: Colors.white,
                              letterSpacing: -0.5 * progress,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3 * progress + 0.1),
                                  blurRadius: 8 * progress + 2,
                                  offset: Offset(0, 3 * progress),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/landing_bg.png',
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                cs.primary.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const Gap(20),
                          Text(
                            'RULE ENGINE + GOOGLE GEMINI',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: cs.primary,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const Gap(12),
                          Text(
                            'Migrate your Flutter project in seconds.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              height: 1.2,
                            ),
                          ),
                          const Gap(40),
                        ],
                      ),
                    ),

                    // ── Quick actions ──────────────────────────────────────────
                    Text(
                      'Start migrating',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Gap(12),
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: MediaQuery.of(context).size.width > 900 ? 1.4 : 1.8,
                      children: [
                        _QuickAction(
                          icon: Icons.code_rounded,
                          label: 'Paste Code',
                          subtitle: 'Single .dart snippet',
                          color: cs.primary,
                          onTap: () => Navigator.pushNamed(context, '/migrate', arguments: 0),
                        ),
                        _QuickAction(
                          icon: Icons.insert_drive_file_outlined,
                          label: '.dart File',
                          subtitle: 'Upload single file',
                          color: Colors.orange,
                          onTap: () => Navigator.pushNamed(context, '/migrate', arguments: 1),
                        ),
                        _QuickAction(
                          icon: Icons.folder_zip_outlined,
                          label: 'ZIP Project',
                          subtitle: 'Entire Flutter project',
                          color: Colors.teal,
                          onTap: () => Navigator.pushNamed(context, '/migrate', arguments: 2),
                        ),
                        _QuickAction(
                          icon: Icons.link_rounded,
                          label: 'GitHub URL',
                          subtitle: 'Any public repo',
                          color: Colors.purple,
                          onTap: () => Navigator.pushNamed(context, '/migrate', arguments: 3),
                        ),
                      ]
                          .asMap()
                          .entries
                          .map((e) => e.value
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: e.key * 60))
                          .slideY(begin: 0.1, end: 0))
                          .toList(),
                    ),

                    const Gap(28),

                    // ── Stats row ─────────────────────────────────────────────
                    Text(
                      'Your stats',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '${history.length}',
                            label: 'Migrations',
                            icon: Icons.history_rounded,
                            color: cs.primary,
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: _StatCard(
                            value: '$completed',
                            label: 'Completed',
                            icon: Icons.check_circle_outline_rounded,
                            color: Colors.green,
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: _StatCard(
                            value: avgConfScore != null
                                ? '$avgConfScore%'
                                : '—',
                            label: 'Avg Confidence',
                            icon: Icons.verified_rounded,
                            color: Colors.blue,
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: _StatCard(
                            value: '$failed',
                            label: 'Failed',
                            icon: Icons.error_outline_rounded,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const Gap(28),

                    // ── What this tool handles ─────────────────────────────────
                    Text(
                      'What gets migrated',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Gap(12),
                    ..._capabilities.asMap().entries.map(
                          (e) => _CapabilityRow(
                        category: e.value.$1,
                        examples: e.value.$2,
                        source: e.value.$3,
                      )
                          .animate()
                          .fadeIn(
                        delay: Duration(milliseconds: e.key * 50),
                      ),
                    ),

                    const Gap(28),

                    // ── Recent migrations ─────────────────────────────────────
                    if (history.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/history'),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                      const Gap(8),
                      ...history.take(3).map(
                            (m) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: (m.isCompleted
                                  ? Colors.green
                                  : Colors.red)
                                  .withValues(alpha: 0.1),
                              child: Icon(
                                m.isCompleted
                                    ? Icons.check_rounded
                                    : Icons.error_outline_rounded,
                                size: 16,
                                color: m.isCompleted
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            title: Text(
                              m.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${m.flutterVersionFrom ?? "?"} → '
                                  '${m.flutterVersionTo ?? "latest"}  •  '
                                  '${_sourceLabel(m.sourceType)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: m.confidenceScore != null
                                ? Text(
                              '${m.confidenceScore}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: m.confidenceScore! >= 90
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            )
                                : null,
                            onTap: () {
                              provider.setCurrentMigration(m);
                              Navigator.pushNamed(context, '/result');
                            },
                          ),
                        ),
                      ),
                    ],

                    const Gap(32),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── FAB ───────────────────────────────────────────────────────────────
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/migrate'),
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: const Text('New Migration'),
        ),
      ),
    );
  }

  String _sourceLabel(String type) => switch (type) {
    'zip'    => '📦 ZIP',
    'github' => '🐙 GitHub',
    'file'   => '📄 .dart',
    _        => '📋 Paste',
  };
}

// Capabilities list: (category, examples, source)
const _capabilities = [
  (
  'Widget API',
  'RaisedButton → ElevatedButton, FlatButton → TextButton',
  'rule',
  ),
  (
  'Typography',
  'headline6 → titleLarge, bodyText1 → bodyLarge, caption → bodySmall',
  'rule',
  ),
  (
  'Navigation',
  'Scaffold.of() → ScaffoldMessenger, WillPopScope → PopScope',
  'rule',
  ),
  (
  'Theming',
  'accentColor → colorScheme.secondary, ThemeData color system',
  'rule',
  ),
  (
  'Null Safety',
  'late keyword, required, ?. chains, async BuildContext gaps',
  'ai',
  ),
  (
  'State Management',
  'Provider patterns, GoRouter, Navigator 2.0',
  'ai',
  ),
  (
  'Dependencies',
  'pub.dev latest version check, breaking change detection',
  'ai',
  ),
  (
  'Android / iOS',
  'compileSdk, targetSdk, minSdk, Gradle 7+ syntax',
  'rule',
  ),
];

// ── Quick action card ─────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final Color    color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const Gap(10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const Gap(6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Capability row ────────────────────────────────────────────────────────────

class _CapabilityRow extends StatelessWidget {
  final String category;
  final String examples;
  final String source; // 'rule' | 'ai'

  const _CapabilityRow({
    required this.category,
    required this.examples,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final isRule = source == 'rule';
    final color  = isRule ? Colors.blue : Colors.purple;
    final badge  = isRule ? 'Rule Engine' : 'AI';
    final icon   = isRule ? Icons.rule_rounded : Icons.psychology_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Gap(6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border:
                        Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  examples,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
