import 'package:flutter/material.dart';

class ChatSuggestionChips extends StatelessWidget {
  final void Function(String command) onSelected;

  const ChatSuggestionChips({super.key, required this.onSelected});

  static const _commands = [
    ('pwd', 'pwd'),
    ('find', 'find . -name'),
    ('grep', 'grep'),
    ('|', '|'),
    ('ls', 'ls'),
    ('du', 'du -sh'),
    ('df', 'df -lh'),
    ('free', 'free -h'),
    ('ip', 'ifconfig'),
    ('ps', 'ps -ef'),
    ('uptime', 'uptime'),
    ('uname', 'uname -a'),
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
            onPressed: () => onSelected(cmd.$2),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
