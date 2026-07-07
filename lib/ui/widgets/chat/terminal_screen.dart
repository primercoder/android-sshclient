import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/services/ssh/ssh_terminal_service.dart';
import 'package:xterm/xterm.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  final VoidCallback onExit;

  const TerminalScreen({super.key, required this.onExit});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  late final Terminal _terminal;
  late final SshTerminalService _service;

  double _btnRight = 16;
  double _btnBottom = 80;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _service = SshTerminalService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final sshClient = ref.read(sshClientServiceProvider).client;
    if (sshClient == null) return;
    try {
      await _service.start(sshClient, _terminal);
      if (mounted) setState(() => _started = true);
    } catch (_) {}
  }

  void _sendControl(Uint8List bytes) {
    _service.write(bytes);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: TerminalView(
                _terminal,
                autofocus: true,
              ),
            ),
            _ShortcutBar(
              onSend: _sendControl,
              theme: theme,
            ),
            SizedBox(height: bottomInset),
          ],
        ),
        Positioned(
          right: _btnRight,
          bottom: _btnBottom + bottomInset,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _btnRight -= details.delta.dx;
                _btnBottom -= details.delta.dy;
              });
            },
            child: FloatingActionButton.small(
              heroTag: 'terminal_exit',
              onPressed: widget.onExit,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.9),
              child: const Icon(Icons.chat_bubble_outline),
            ),
          ),
        ),
        if (!_started)
          Container(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('正在启动终端...', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShortcutBar extends StatelessWidget {
  final void Function(Uint8List bytes) onSend;
  final ThemeData theme;

  const _ShortcutBar({required this.onSend, required this.theme});

  static final _keys = [
    ('Tab', Uint8List.fromList([0x09])),
    ('Esc', Uint8List.fromList([0x1b])),
    ('^C', Uint8List.fromList([0x03])),
    ('^D', Uint8List.fromList([0x04])),
    ('↑', Uint8List.fromList([0x1b, 0x5b, 0x41])),
    ('↓', Uint8List.fromList([0x1b, 0x5b, 0x42])),
    ('←', Uint8List.fromList([0x1b, 0x5b, 0x44])),
    ('→', Uint8List.fromList([0x1b, 0x5b, 0x43])),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: 6,
        bottom: 6 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _keys.map((entry) {
            final label = entry.$1;
            final bytes = entry.$2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _ShortcutKey(
                label: label,
                onTap: () => onSend(bytes),
                theme: theme,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ShortcutKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ShortcutKey({
    required this.label,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
