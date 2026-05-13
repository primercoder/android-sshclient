import 'package:flutter/material.dart';

class ChatSuggestionChips extends StatelessWidget {
  final void Function(String command) onTap;

  const ChatSuggestionChips({super.key, required this.onTap});

  static const _commands = [
    ('ls', 'ls -la'),
    ('df', 'df -h'),
    ('ps', 'ps aux'),
    ('free', 'free -h'),
    ('net', 'netstat -tlnp'),
    ('ip', 'ip a'),
    ('uptime', 'uptime'),
    ('pwd', 'pwd'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _commands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cmd = _commands[index];
          return ActionChip(
            label: Text(cmd.$1, style: const TextStyle(fontSize: 12)),
            onPressed: () => onTap(cmd.$2),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
