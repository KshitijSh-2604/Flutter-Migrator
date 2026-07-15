import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/models/migration_model.dart';
import '../../providers/migration_provider.dart';
import '../widgets/result_viewer_widget.dart';
import '../widgets/diff_viewer_widget.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String? _selectedFilePath;
  bool _isMigratingFile = false;

  void _triggerDownload(String content, String fileName) {
    try {
      PlatformUtils.downloadFile(content, fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading $fileName...')),
      );
    } catch (e) {
      Clipboard.setData(ClipboardData(text: content));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download failed. Code copied to clipboard instead.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MigrationProvider>();
    final migration = provider.currentMigration;

    if (migration == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('No migration selected.')),
      );
    }

    final filesData = migration.parsedFilesData;
    final hasMultipleFiles = filesData.isNotEmpty;

    // Set initial selection if not set
    if (_selectedFilePath == null && hasMultipleFiles) {
      _selectedFilePath = filesData.keys.first;
    }

    final currentFile = hasMultipleFiles ? filesData[_selectedFilePath] : null;
    final bool isAiMigrated = currentFile != null ? (currentFile['ai_migrated'] ?? false) : true;

    final String displayOriginal = currentFile != null ? currentFile['original'] : migration.originalCode;
    final String displayMigrated = currentFile != null ? currentFile['migrated'] : (migration.migratedCode ?? '');
    final List<Map<String, dynamic>> displayChanges = currentFile != null
        ? List<Map<String, dynamic>>.from(currentFile['changes'] ?? [])
        : migration.parsedChanges;

    // ── Calculate file-specific stats ──
    final int ruleCount = displayChanges.where((c) => c['source'] == 'rule_engine').length;
    final int aiCount   = displayChanges.where((c) => c['source'] == 'ai').length;
    final int total     = ruleCount + aiCount;
    
    final int displayConfidence = total == 0 ? 95 : (70 + (ruleCount / total * 30)).toInt();

    return DefaultTabController(
      length: 5,
      child: SelectionArea(
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(migration.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  '${migration.flutterVersionFrom ?? "?"} → '
                      '${migration.flutterVersionTo ?? "latest"}  •  '
                      '${_sourceLabel(migration.sourceType)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                ),
              ],
            ),
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
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.code_rounded),         text: 'Migrated Code'),
                Tab(icon: Icon(Icons.compare_rounded),       text: 'Diff View'),
                Tab(icon: Icon(Icons.list_alt_rounded),      text: 'Changes'),
                Tab(icon: Icon(Icons.description_rounded),   text: 'pubspec.yaml'),
                Tab(icon: Icon(Icons.analytics_outlined),    text: 'Packages'),
              ],
            ),
            actions: [
              if (displayMigrated.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: 'Copy current migrated file',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: displayMigrated));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Migrated code copied to clipboard!')),
                    );
                  },
                ),
                if (isAiMigrated)
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    tooltip: 'Download this migrated file',
                    onPressed: () {
                      final fileName = _selectedFilePath?.split('/').last.replaceAll('.dart', '_migrated.dart') ?? 'migrated.dart';
                      _triggerDownload(displayMigrated, fileName);
                    },
                  ),
              ],
            ],
          ),
          body: migration.isFailed
              ? _FailureView(message: migration.errorMessage)
              : Row(
            children: [
              // ── File Sidebar (Multi-file only) ───────────────────────────
              if (hasMultipleFiles)
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open_rounded, size: 18),
                            const Gap(8),
                            Text('PROJECT FILES',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filesData.keys.length,
                          itemBuilder: (context, index) {
                            final path = filesData.keys.elementAt(index);
                            final isSelected = path == _selectedFilePath;
                            final file = filesData[path];
                            final bool fileAiMigrated = file['ai_migrated'] ?? false;

                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                              leading: Stack(
                                children: [
                                  Icon(
                                    path.endsWith('.dart') ? Icons.description_outlined : Icons.insert_drive_file_outlined,
                                    size: 16,
                                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                                  ),
                                  if (fileAiMigrated)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.purple,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                path.split('/').last,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(path, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: fileAiMigrated 
                                ? const Icon(Icons.psychology_rounded, size: 12, color: Colors.purple)
                                : null,
                              onTap: () {
                                setState(() => _selectedFilePath = path);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Tab Content ──────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Dynamic File-Specific Confidence banner
                        _ConfidenceBanner(
                          score: displayConfidence,
                          ruleChanges: ruleCount,
                          aiChanges: aiCount,
                          filesAnalyzed: migration.filesAnalyzed,
                          filePath: _selectedFilePath,
                          isAiMigrated: isAiMigrated,
                        ),

                        // Tab content
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 0 — Migrated Code
                              ResultViewerWidget(
                                code: displayMigrated,
                                language: 'dart',
                                emptyMessage: 'No migrated code available.',
                              ),

                              // Tab 1 — Diff View
                              DiffViewerWidget(
                                original: displayOriginal,
                                migrated: displayMigrated,
                              ),

                              // Tab 2 — Changes list
                              _ChangesTab(changes: displayChanges),

                              // Tab 3 — pubspec.yaml changes
                              _PubspecTab(
                                changes: migration.parsedPubspecChanges,
                                steps: migration.parsedMigrationSteps,
                                packages: migration.parsedPackageAnalysis,
                              ),

                              // Tab 4 — Package analysis
                              _PackageAnalysisTab(
                                packages: migration.parsedPackageAnalysis,
                                recommended: migration.parsedRecommendedPackages,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // ON-DEMAND MIGRATE OVERLAY
                    if (hasMultipleFiles && !isAiMigrated)
                      Positioned(
                        bottom: 24,
                        right: 24,
                        child: FloatingActionButton.extended(
                          onPressed: _isMigratingFile ? null : () async {
                            setState(() => _isMigratingFile = true);
                            await provider.migrateFileIndividually(migration.id, _selectedFilePath!);
                            setState(() => _isMigratingFile = false);
                          },
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          icon: _isMigratingFile 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.psychology_rounded),
                          label: Text(_isMigratingFile ? 'MIGRATING...' : 'MIGRATE THIS FILE WITH AI'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(String type) => switch (type) {
    'zip'    => '📦 ZIP project',
    'github' => '🐙 GitHub',
    'file'   => '📄 .dart file',
    _        => '📋 Pasted code',
  };
}

// ── Failure View ──────────────────────────────────────────────────────────────

class _FailureView extends StatelessWidget {
  final String? message;
  const _FailureView({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            const Gap(16),
            Text('Migration Failed',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Gap(8),
            Text(message ?? 'Unknown error occurred.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7))),
            const Gap(24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confidence Banner ─────────────────────────────────────────────────────────

class _ConfidenceBanner extends StatelessWidget {
  final int score;
  final int ruleChanges;
  final int aiChanges;
  final int filesAnalyzed;
  final String? filePath;
  final bool isAiMigrated;

  const _ConfidenceBanner({
    required this.score,
    required this.ruleChanges,
    required this.aiChanges,
    required this.filesAnalyzed,
    this.filePath,
    required this.isAiMigrated,
  });

  Color get _scoreColor {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  String get _scoreLabel {
    if (score >= 90) return 'High confidence';
    if (score >= 70) return 'Medium confidence';
    return 'Low confidence — review carefully';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: _scoreColor.withValues(alpha: 0.08),
      child: Wrap(
        spacing: 28,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, color: _scoreColor, size: 18),
              const Gap(6),
              Text(
                '$score%  $_scoreLabel',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: _scoreColor),
              ),
              if (filePath != null) ...[
                const Gap(8),
                Text('for ${filePath!.split('/').last}', 
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: _scoreColor.withValues(alpha: 0.7))),
              ],
            ],
          ),
          _BannerStat(
              Icons.rule_rounded, '$ruleChanges rule-based', Colors.blue),
          _BannerStat(
              Icons.psychology_rounded, '$aiChanges AI fixes', isAiMigrated ? Colors.purple : Colors.grey),
          _BannerStat(
              Icons.description_rounded,
              '$filesAnalyzed project files',
              Colors.teal),
          if (!isAiMigrated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Text('AI PENDING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.orange)),
            ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _BannerStat(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const Gap(4),
        Text(label,
            style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

// ── Changes Tab ───────────────────────────────────────────────────────────────

class _ChangesTab extends StatelessWidget {
  final List<Map<String, dynamic>> changes;
  const _ChangesTab({required this.changes});

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green),
              Gap(12),
              Text('No changes needed for this file.'),
              Text('Code is already compatible with target version.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ));
    }

    // Group by source
    final ruleChanges = changes.where((c) => c['source'] == 'rule_engine').toList();
    final aiChanges   = changes.where((c) => c['source'] == 'ai').toList();
    final other       = changes.where(
            (c) => c['source'] != 'rule_engine' && c['source'] != 'ai').toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (ruleChanges.isNotEmpty) ...[
          _ChangesGroupHeader(
              'Rule Engine (Deterministic)', ruleChanges.length, Colors.blue),
          ...ruleChanges.map((c) => _ChangeCard(change: c)),
          const Gap(16),
        ],
        if (aiChanges.isNotEmpty) ...[
          _ChangesGroupHeader(
              'AI Migration (Complex)', aiChanges.length, Colors.purple),
          ...aiChanges.map((c) => _ChangeCard(change: c)),
          const Gap(16),
        ],
        if (other.isNotEmpty) ...[
          _ChangesGroupHeader('Other', other.length, Colors.grey),
          ...other.map((c) => _ChangeCard(change: c)),
        ],
      ],
    );
  }
}

class _ChangesGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _ChangesGroupHeader(this.title, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 13)),
          const Gap(8),
          Chip(
            label: Text('$count'),
            backgroundColor: color.withValues(alpha: 0.1),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final Map<String, dynamic> change;
  const _ChangeCard({required this.change});

  @override
  Widget build(BuildContext context) {
    final confidence = change['confidence'] as int? ?? 80;
    final isAI = change['source'] == 'ai';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: (isAI ? Colors.purple : Colors.blue).withValues(alpha: 0.1),
          child: Icon(
            isAI ? Icons.psychology_rounded : Icons.rule_rounded,
            size: 16,
            color: isAI ? Colors.purple : Colors.blue,
          ),
        ),
        title: Text(
          change['description'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Row(
          children: [
            Chip(
              label: Text(change['category'] ?? '',
                  style: const TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const Gap(8),
            Icon(Icons.verified, size: 12,
                color: confidence >= 90 ? Colors.green : Colors.orange),
            const Gap(2),
            Text('$confidence%',
                style: const TextStyle(fontSize: 10)),
          ],
        ),
        children: [
          if (change['before'] != null)
            _CodeSnippet(
                label: 'Before', code: change['before'], color: Colors.red),
          if (change['after'] != null)
            _CodeSnippet(
                label: 'After', code: change['after'], color: Colors.green),
          const Gap(8),
        ],
      ),
    );
  }
}

class _CodeSnippet extends StatelessWidget {
  final String label;
  final String code;
  final Color color;
  const _CodeSnippet(
      {required this.label, required this.code, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11)),
          const Gap(4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── pubspec Tab ───────────────────────────────────────────────────────────────

class _PubspecTab extends StatelessWidget {
  final Map<String, dynamic> changes;
  final List<String> steps;
  final List<PackageInfo> packages;

  const _PubspecTab({
    required this.changes,
    required this.steps,
    required this.packages,
  });

  @override
  Widget build(BuildContext context) {
    final sdkRaw = changes['sdk_constraints'];
    Map<String, String> sdk = {};
    
    if (sdkRaw is Map) {
      sdk = sdkRaw.cast<String, String>();
    } else if (sdkRaw is String) {
      // Handle the case where AI returns raw string
      final dartMatch = RegExp(r'sdk:\s*([^\n]+)').firstMatch(sdkRaw);
      final flutterMatch = RegExp(r'flutter:\s*([^\n]+)').firstMatch(sdkRaw);
      if (dartMatch != null) sdk['dart'] = dartMatch.group(1)!.trim();
      if (flutterMatch != null) sdk['flutter'] = flutterMatch.group(1)!.trim();
      
      if (sdk.isEmpty && sdkRaw.isNotEmpty) sdk['info'] = sdkRaw;
    } else if (changes.containsKey('raw_info')) {
      // Our new fallback key from the model
      sdk['info'] = changes['raw_info'];
    }

    final add    = List<Map>.from(changes['add_dependencies']    ?? []);
    final remove = List<Map>.from(changes['remove_dependencies'] ?? []);
    final update = List<Map>.from(changes['update_dependencies'] ?? []);

    final needsPackageUpdates = packages.any((p) => p.needsUpgrade);

    if (add.isEmpty && remove.isEmpty && update.isEmpty && steps.isEmpty && !needsPackageUpdates) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green),
            const Gap(16),
            Text(
              'pubspec is up to date already',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Text('No changes are to be made.'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Migration steps
        if (steps.isNotEmpty) ...[
          _Section('Action Plan'),
          ...steps.asMap().entries.map(
                (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text('${e.key + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const Gap(12),
                  Expanded(child: Text(e.value, style: const TextStyle(height: 1.5))),
                ],
              ),
            ),
          ),
          const Gap(20),
        ],

        // SDK constraints
        if (sdk.isNotEmpty) ...[
          _Section('Recommended SDK Constraints'),
          _PubCard(
            label: 'dart',
            value: sdk['dart'] ?? '',
            icon: Icons.code,
            color: Colors.teal,
          ),
          _PubCard(
            label: 'flutter',
            value: sdk['flutter'] ?? '',
            icon: Icons.flutter_dash,
            color: Colors.blue,
          ),
          const Gap(20),
        ],

        // Outdated Packages (from analysis or inference)
        if (needsPackageUpdates || update.isNotEmpty) ...[
          _Section('Dependencies to Update'),
          ...packages.where((p) => p.needsUpgrade).map((p) => _DepCard(
            name: p.name,
            version: '${p.installedVersion} → ${p.latestVersion}',
            note: p.isBreaking ? 'Breaking change' : 'Update available',
            color: p.isBreaking ? Colors.red : Colors.orange,
            icon: Icons.upgrade_rounded,
            action: 'UPDATE',
          )),
          ...update.where((u) => !packages.any((p) => p.name == u['package'])).map((u) => _DepCard(
            name: u['package'] ?? '',
            version: u['new_version'] ?? 'latest',
            note: u['reason'] ?? 'Required dependency',
            color: Colors.blue,
            icon: Icons.add_moderator_rounded,
            action: 'REQUIRE',
          )),
          const Gap(20),
        ],

        // Add
        if (add.isNotEmpty) ...[
          _Section('Add these dependencies'),
          ...add.map((p) => _DepCard(
            name: p['package'] ?? '',
            version: p['version'] ?? '',
            note: p['reason'],
            color: Colors.green,
            icon: Icons.add_circle_outline_rounded,
            action: 'ADD',
          )),
          const Gap(20),
        ],

        // Update (from AI specific logic)
        if (update.isNotEmpty) ...[
          _Section('Structural dependency changes'),
          ...update.map((p) => _DepCard(
            name: p['package'] ?? '',
            version: '${p['old_version']} → ${p['new_version']}',
            note: p['reason'],
            color: Colors.orange,
            icon: Icons.upgrade_rounded,
            action: 'UPDATE',
          )),
          const Gap(20),
        ],

        // Remove
        if (remove.isNotEmpty) ...[
          _Section('Remove these (deprecated)'),
          ...remove.map((p) => _DepCard(
            name: p['package'] ?? '',
            version: '',
            note: p['reason'],
            color: Colors.red,
            icon: Icons.remove_circle_outline_rounded,
            action: 'REMOVE',
          )),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _PubCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _PubCard(
      {required this.label,
        required this.value,
        required this.icon,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value,
              style: TextStyle(
                  fontFamily: 'monospace', color: color, fontSize: 13)),
        ),
      ),
    );
  }
}

class _DepCard extends StatelessWidget {
  final String name;
  final String version;
  final String? note;
  final Color color;
  final IconData icon;
  final String action;

  const _DepCard({
    required this.name,
    required this.version,
    this.note,
    required this.color,
    required this.icon,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          name,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: note != null
            ? Text(note!, style: const TextStyle(fontSize: 12))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (version.isNotEmpty)
              Text(
                version,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: color,
                ),
              ),
            const Gap(8),
            Chip(
              label: Text(
                action,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: color.withValues(alpha: 0.1),
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Package Analysis Tab ──────────────────────────────────────────────────────

class _PackageAnalysisTab extends StatelessWidget {
  final List<PackageInfo> packages;
  final List<Map<String, dynamic>> recommended;

  const _PackageAnalysisTab({
    required this.packages,
    required this.recommended,
  });

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty && recommended.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const Gap(16),
            const Text(
              'No package data available.\n'
                  'Upload a ZIP or GitHub repo to get\n'
                  'real-time pub.dev dependency analysis.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final breaking = packages.where((p) => p.isBreaking).toList();
    final upgrade  = packages.where((p) => p.status == 'upgrade').toList();
    final ok       = packages.where((p) => p.status == 'ok').toList();
    final unknown  = packages.where((p) => p.status == 'unknown').toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Summary counts bar
        if (packages.isNotEmpty) ...[
          _SummaryRow(packages: packages),
          const Gap(20),
        ],

        // Breaking first — most urgent
        if (breaking.isNotEmpty) ...[
          _PkgGroupHeader('⚠  Breaking Changes', breaking.length, Colors.red),
          ...breaking.map((p) => _PkgCard(package: p)),
          const Gap(16),
        ],

        if (upgrade.isNotEmpty) ...[
          _PkgGroupHeader('↑  Needs Upgrade', upgrade.length, Colors.orange),
          ...upgrade.map((p) => _PkgCard(package: p)),
          const Gap(16),
        ],

        if (ok.isNotEmpty) ...[
          _PkgGroupHeader('✓  Up to Date', ok.length, Colors.green),
          ...ok.map((p) => _PkgCard(package: p)),
          const Gap(16),
        ],

        if (unknown.isNotEmpty) ...[
          _PkgGroupHeader('?  Unknown', unknown.length, Colors.grey),
          ...unknown.map((p) => _PkgCard(package: p)),
          const Gap(16),
        ],

        // AI-recommended packages
        if (recommended.isNotEmpty) ...[
          const Divider(height: 32),
          const _SectionTitle('AI Recommended Packages'),
          const Gap(8),
          ...recommended.map(
                (p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.extension_outlined,
                  color: Colors.purple,
                ),
                title: Text(
                  '${p['package']}: ${p['version']}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(p['purpose'] ?? ''),
                trailing: p['replaces'] != null
                    ? Chip(
                  label: Text(
                    'Replaces: ${p['replaces']}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                )
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<PackageInfo> packages;
  const _SummaryRow({required this.packages});

  @override
  Widget build(BuildContext context) {
    final breaking = packages.where((p) => p.isBreaking).length;
    final upgrade  = packages.where((p) => p.status == 'upgrade').length;
    final ok       = packages.where((p) => p.status == 'ok').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SumStat('${packages.length}', 'Total',     Colors.blueGrey),
            _SumStat('$breaking',          'Breaking',  Colors.red),
            _SumStat('$upgrade',           'Upgrade',   Colors.orange),
            _SumStat('$ok',                'Up to date',Colors.green),
          ],
        ),
      ),
    );
  }
}

class _SumStat extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _SumStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _PkgGroupHeader extends StatelessWidget {
  final String title;
  final int    count;
  final Color  color;
  const _PkgGroupHeader(this.title, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 13,
            ),
          ),
          const Gap(8),
          Chip(
            label: Text('$count'),
            backgroundColor: color.withValues(alpha: 0.1),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PkgCard extends StatelessWidget {
  final PackageInfo package;
  const _PkgCard({required this.package});

  Color get _color => switch (package.status) {
    'breaking' => Colors.red,
    'upgrade'  => Colors.orange,
    'ok'       => Colors.green,
    _          => Colors.grey,
  };

  IconData get _icon => switch (package.status) {
    'breaking' => Icons.warning_amber_rounded,
    'upgrade'  => Icons.upgrade_rounded,
    'ok'       => Icons.check_rounded,
    _          => Icons.help_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: _color.withValues(alpha: 0.1),
          child: Icon(_icon, color: _color, size: 16),
        ),
        title: Text(
          package.name,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: package.status != 'ok'
            ? Text(
          '${package.installedVersion}  →  ${package.latestVersion}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        )
            : Text(
          'v${package.latestVersion}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Chip(
          label: Text(
            package.status.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: _color.withValues(alpha: 0.1),
          side: BorderSide(color: _color.withValues(alpha: 0.4)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ── Shared section title ──────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
