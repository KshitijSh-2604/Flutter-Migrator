import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../data/models/migration_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/migration_provider.dart';
import '../widgets/code_input_widget.dart';

class MigrateScreen extends StatefulWidget {
  const MigrateScreen({super.key});

  @override
  State<MigrateScreen> createState() => _MigrateScreenState();
}

class _MigrateScreenState extends State<MigrateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Shared
  final _titleCtrl   = TextEditingController();
  final _fromVersionCtrl = TextEditingController();
  final _toVersionCtrl = TextEditingController();

  // Tab 0 — Paste
  final _codeCtrl = TextEditingController();

  // Tab 1 — Single .dart file
  String?   _dartFileName;
  List<int>? _dartFileBytes;

  // Tab 2 — ZIP project
  String?   _zipFileName;
  List<int>? _zipFileBytes;

  // Tab 3 — GitHub URL
  final _githubCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);

    // Set initial tab if provided via arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialTab = ModalRoute.of(context)?.settings.arguments as int?;
      if (initialTab != null && initialTab >= 0 && initialTab < 4) {
        _tabs.index = initialTab;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _fromVersionCtrl.dispose();
    _toVersionCtrl.dispose();
    _codeCtrl.dispose();
    _githubCtrl.dispose();
    super.dispose();
  }

  // ── File pickers ─────────────────────────────────────────────────────────────

  Future<void> _pickDartFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['dart'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _dartFileName  = result.files.first.name;
      _dartFileBytes = result.files.first.bytes?.toList();
    });
  }

  Future<void> _pickZipFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _zipFileName  = result.files.first.name;
      _zipFileBytes = result.files.first.bytes?.toList();
    });
  }

  // ── Migrate ───────────────────────────────────────────────────────────────────

  bool _isValidVersion(String version) {
    if (version.isEmpty) return true;
    final regExp = RegExp(r'^\d+\.\d+\.\d+(\+.*)?$');
    return regExp.hasMatch(version);
  }

  Future<void> _migrate() async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasValidKey) {
      _snack('Please configure your API keys in the Profile menu before migrating.', isError: true);
      return;
    }

    final provider = context.read<MigrationProvider>();
    String title = _titleCtrl.text.trim();
    
    // 1. Mandatory title check
    if (title.isEmpty) {
      _showErrorDialog('Missing Title', 'Please provide a title for your migration.');
      return;
    }

    // 2. Duplicate title check
    final isDuplicate = provider.migrations.any((m) => m.title.toLowerCase() == title.toLowerCase());
    if (isDuplicate) {
      _showErrorDialog('Duplicate Title', 'A migration with the title "$title" already exists in your history. Please use a unique title.');
      return;
    }

    final fromVersion = _fromVersionCtrl.text.trim();
    final toVersion = _toVersionCtrl.text.trim();

    if (fromVersion.isNotEmpty && !_isValidVersion(fromVersion)) {
      _showVersionError(fromVersion, 'From');
      return;
    }

    if (toVersion.isNotEmpty && !_isValidVersion(toVersion)) {
      _showVersionError(toVersion, 'To');
      return;
    }

    MigrationModel? result;

    switch (_tabs.index) {
      case 0: // Paste
        if (_codeCtrl.text.trim().isEmpty) {
          _snack('Please paste some Dart code first.');
          return;
        }
        result = await provider.migrate(
          title: title,
          code: _codeCtrl.text,
          fromVersion: fromVersion.isEmpty ? null : fromVersion,
          toVersion: toVersion.isEmpty ? null : toVersion,
        );

      case 1: // Single .dart file
        if (_dartFileBytes == null) {
          _snack('Please pick a .dart file first.');
          return;
        }
        result = await provider.migrateFile(
          fileBytes: _dartFileBytes!,
          fileName: _dartFileName!,
          fromVersion: fromVersion.isEmpty ? null : fromVersion,
          toVersion: toVersion.isEmpty ? null : toVersion,
        );

      case 2: // ZIP project
        if (_zipFileBytes == null) {
          _snack('Please pick a .zip file first.');
          return;
        }
        result = await provider.migrateZip(
          fileBytes: _zipFileBytes!,
          fileName: _zipFileName!,
          fromVersion: fromVersion.isEmpty ? null : fromVersion,
          toVersion: toVersion.isEmpty ? null : toVersion,
        );

      case 3: // GitHub URL
        if (_githubCtrl.text.trim().isEmpty) {
          _snack('Please enter a GitHub URL.');
          return;
        }
        result = await provider.migrateGithub(
          githubUrl: _githubCtrl.text.trim(),
          title: title,
          fromVersion: fromVersion.isEmpty ? null : fromVersion,
          toVersion: toVersion.isEmpty ? null : toVersion,
        );
    }

    if (!mounted) return;
    if (result != null) {
      Navigator.pushNamed(context, '/result');
    } else {
      _snack(provider.errorMessage ?? 'Migration failed.', isError: true);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVersionError(String version, String type) {    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invalid Version'),
        content: Text('The $type version "$version" is not a valid Dart version format (e.g., 3.0.0).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fix it'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : null,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MigrationProvider>();
    final cs = Theme.of(context).colorScheme;

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Migrate Flutter Code'),
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
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.code_rounded),             text: 'Paste Code'),
            Tab(icon: Icon(Icons.insert_drive_file_rounded), text: '.dart File'),
            Tab(icon: Icon(Icons.folder_zip_outlined),       text: 'ZIP Project'),
            Tab(icon: Icon(Icons.link_rounded),              text: 'GitHub URL'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: provider.isLoading ? null : _migrate,
              icon: provider.isLoading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.auto_fix_high_rounded),
              label: Text(provider.isLoading ? 'Migrating...' : 'Migrate'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Shared title + versions ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Migration Title',
                    hintText: 'My Flutter Migration',
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
                const Gap(16),
                Row(
                  children: [
                    const Expanded(
                      child: TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Detected automatically',
                          hintText: 'Current version...',
                          prefixIcon: Icon(Icons.auto_awesome_rounded),
                        ),
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: TextField(
                        controller: _toVersionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Target Dart Version',
                          hintText: 'e.g. 3.5.0',
                          prefixIcon: Icon(Icons.rocket_launch_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(16),

          // ── Tab content ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Tab 0 — Paste code
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Dart Code',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _codeCtrl.clear(),
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear'),
                          ),
                        ],
                      ),
                      const Gap(8),
                      Expanded(child: CodeInputWidget(controller: _codeCtrl)),
                    ],
                  ),
                ),

                // Tab 1 — Single .dart file
                _UploadPanel(
                  icon: Icons.insert_drive_file_outlined,
                  title: 'Upload a single .dart file',
                  subtitle:
                  'Pick any .dart file from your Flutter project.\n'
                      'The AI migrates it and returns the updated code.',
                  buttonLabel: _dartFileName != null
                      ? '✓  $_dartFileName'
                      : 'Choose .dart file',
                  onPick: _pickDartFile,
                  accepted: _dartFileName != null,
                  acceptedColor: Colors.green,
                ),

                // Tab 2 — ZIP project
                _UploadPanel(
                  icon: Icons.folder_zip_outlined,
                  title: 'Upload entire Flutter project as ZIP',
                  subtitle:
                  'Zip your project root folder, then upload.\n'
                      'We parse pubspec.yaml, all .dart files, '
                      'and Android/iOS configs automatically.',
                  buttonLabel: _zipFileName != null
                      ? '✓  $_zipFileName'
                      : 'Choose .zip file',
                  onPick: _pickZipFile,
                  accepted: _zipFileName != null,
                  acceptedColor: Colors.green,
                  extraInfo: const [
                    _InfoChip(Icons.check, 'pubspec.yaml parsed'),
                    _InfoChip(Icons.check, 'All .dart files scanned'),
                    _InfoChip(Icons.check, 'android/build.gradle checked'),
                    _InfoChip(Icons.check, 'ios/Podfile checked'),
                  ],
                ),

                // Tab 3 — GitHub URL
                _GithubPanel(controller: _githubCtrl),
              ],
            ),
          ),

          // ── Loading bar ───────────────────────────────────────────────────
          AnimatedSize(
            duration: 300.ms,
            child: provider.isLoading
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              color: cs.surfaceContainerHighest,
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Migrating your code…',
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(
                          'Rule engine running → sending to Gemini 3.5 Flash → '
                              'checking pub.dev',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                              color: cs.onSurface
                                  .withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ));
  }
}

// ── Upload Panel ──────────────────────────────────────────────────────────────

class _UploadPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPick;
  final bool accepted;
  final Color acceptedColor;
  final List<Widget> extraInfo;

  const _UploadPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPick,
    required this.accepted,
    this.acceptedColor = Colors.green,
    this.extraInfo = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    accepted ? Icons.check_circle_rounded : icon,
                    size: 64,
                    color: accepted ? acceptedColor : cs.primary,
                  )
                      .animate(target: accepted ? 1 : 0)
                      .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1))
                      .then()
                      .scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1)),
                  const Gap(20),
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (extraInfo.isNotEmpty) ...[
                    const Gap(16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: extraInfo,
                    ),
                  ],
                  const Gap(24),
                  FilledButton.icon(
                    onPressed: onPick,
                    icon: Icon(accepted
                        ? Icons.check_circle_outline
                        : Icons.upload_file_rounded),
                    label: Text(buttonLabel),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 14,
          color: Theme.of(context).colorScheme.primary),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── GitHub Panel ──────────────────────────────────────────────────────────────

class _GithubPanel extends StatelessWidget {
  final TextEditingController controller;
  const _GithubPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link_rounded, color: cs.primary, size: 28),
                  const Gap(10),
                  Text(
                    'Public GitHub Repository',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const Gap(8),
              Text(
                'Enter the URL of any public Flutter project on GitHub. '
                    'We download it, parse every file, and run the full migration pipeline.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.65),
                  height: 1.5,
                ),
              ),
              const Gap(20),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'GitHub Repository URL',
                  hintText: 'https://github.com/flutter/samples',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const Gap(16),

              // Example repos
              Text('Example repos to try:',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Gap(8),
              ...[
                'https://github.com/flutter/samples',
                'https://github.com/brianegan/flutter_redux',
                'https://github.com/filiph/spinkit',
              ].map(
                    (url) => InkWell(
                  onTap: () => controller.text = url,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.subdirectory_arrow_right,
                            size: 14, color: cs.primary),
                        const Gap(4),
                        Text(url,
                            style: TextStyle(
                                color: cs.primary,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
              ),
              const Gap(20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    Gap(8),
                    Expanded(
                      child: Text(
                        'Only public repositories are supported. '
                            'Private repos require a GitHub token (not yet implemented).',
                        style: TextStyle(fontSize: 12),
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
}