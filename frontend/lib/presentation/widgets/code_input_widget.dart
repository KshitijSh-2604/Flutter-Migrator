import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class CodeInputWidget extends StatefulWidget {
  final TextEditingController controller;
  const CodeInputWidget({super.key, required this.controller});

  @override
  State<CodeInputWidget> createState() => _CodeInputWidgetState();
}

class _CodeInputWidgetState extends State<CodeInputWidget> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _lineNumbersController = ScrollController();
  int _lines = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _scrollController.addListener(_syncScroll);
    _onChanged();
  }

  void _onChanged() {
    final text = widget.controller.text;
    final count = text.isEmpty ? 1 : text.split('\n').length;
    if (_lines != count) {
      setState(() {
        _lines = count;
      });
    }
  }

  void _syncScroll() {
    if (_lineNumbersController.hasClients) {
      _lineNumbersController.jumpTo(_scrollController.offset);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _scrollController.dispose();
    _lineNumbersController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Line Numbers ──────────────────────────────────────────────
              Container(
                width: 48,
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  border: Border(
                    right: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
                  ),
                ),
                child: ListView.builder(
                  controller: _lineNumbersController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lines,
                  itemBuilder: (context, index) {
                    return Container(
                      height: 22.1, // Matches text height roughly
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Code Input ────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 2500, // Finite width to resolve "unbounded width" error
                    child: TextField(
                      controller: widget.controller,
                      scrollController: _scrollController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.7, // Line height multiplier
                      ),
                      decoration: const InputDecoration(
                        hintText: '// Paste your old Flutter / Dart code here...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Actions ───────────────────────────────────────────────────────
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                if (widget.controller.text.isNotEmpty)
                  _ActionButton(
                    icon: Icons.copy_rounded,
                    onTap: _copyToClipboard,
                    tooltip: 'Copy Code',
                  ),
                const Gap(8),
                _ActionButton(
                  icon: Icons.auto_awesome_rounded,
                  onTap: _insertSample,
                  tooltip: 'Load Sample',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _insertSample() {
    widget.controller.text = '''
import 'package:flutter/material.dart';

class OldHomeScreen extends StatelessWidget {
  const OldHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Home',
          style: Theme.of(context).textTheme.headline6,
        ),
        backgroundColor: Theme.of(context).accentColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome',
              style: Theme.of(context).textTheme.bodyText1,
            ),
            const SizedBox(height: 16),
            RaisedButton(
              onPressed: () {
                Scaffold.of(context).showSnackBar(
                  const SnackBar(content: Text('Hello!')),
                );
              },
              child: const Text('Press me'),
            ),
            const SizedBox(height: 8),
            FlatButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back'),
            ),
            const SizedBox(height: 8),
            WillPopScope(
              onWillPop: () async => true,
              child: OutlineButton(
                onPressed: () {},
                child: const Text('Outline'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
        ),
      ),
    );
  }
}
