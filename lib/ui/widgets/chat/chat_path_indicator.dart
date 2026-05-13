import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/chat_provider.dart';

class ChatPathIndicator extends ConsumerWidget {
  const ChatPathIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);

    if (chatState.currentDirectory.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: chatState.currentDirectory));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('路径已复制'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withOpacity(0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_open, size: 14,
                color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                chatState.currentDirectory,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.copy, size: 12,
                color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
