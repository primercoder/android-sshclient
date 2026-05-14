import 'package:flutter/material.dart';
import 'package:ssh_client/data/models/quick_command.dart';

class ChatSuggestionChips extends StatelessWidget {
  final List<QuickCommand> commands;
  final void Function(String command) onSelected;
  final VoidCallback onAdd;
  final void Function(QuickCommand cmd) onEdit;
  final void Function(QuickCommand cmd) onDelete;

  const ChatSuggestionChips({
    super.key,
    required this.commands,
    required this.onSelected,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
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
          ActionChip(
            avatar: Icon(Icons.add, size: 16,
                color: theme.colorScheme.primary),
            label: const Text(''),
            onPressed: onAdd,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 4),
          ...commands.map((cmd) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onLongPress: () => _showPopup(context, cmd),
              child: ActionChip(
                label: Text(cmd.label, style: const TextStyle(fontSize: 12)),
                onPressed: () => onSelected(cmd.command),
                visualDensity: VisualDensity.compact,
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _showPopup(BuildContext context, QuickCommand cmd) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, size: 20),
              title: const Text('编辑'),
              onTap: () { Navigator.pop(ctx); onEdit(cmd); },
            ),
            ListTile(
              leading: Icon(Icons.delete, size: 20, color: Colors.red[300]),
              title: Text('删除', style: TextStyle(color: Colors.red[300])),
              onTap: () { Navigator.pop(ctx); onDelete(cmd); },
            ),
          ],
        ),
      ),
    );
  }
}
