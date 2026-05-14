import 'package:flutter/material.dart';
import 'package:ssh_client/data/models/quick_command.dart';

class ChatSuggestionChips extends StatelessWidget {
  final List<QuickCommand> commands;
  final void Function(String command) onSelected;
  final VoidCallback onManage;

  const ChatSuggestionChips({
    super.key,
    required this.commands,
    required this.onSelected,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: 36, height: 36,
            child: ActionChip(
              avatar: Icon(Icons.more_vert, size: 18,
                  color: theme.colorScheme.primary),
              label: const SizedBox.shrink(),
              onPressed: onManage,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          ...commands.map((cmd) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              label: Text(cmd.label, style: const TextStyle(fontSize: 12)),
              onPressed: () => onSelected(cmd.command),
              visualDensity: VisualDensity.compact,
            ),
          )),
        ],
      ),
    );
  }
}
