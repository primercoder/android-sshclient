import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssh_client/data/models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (message.type) {
      case MessageType.command:
        return _buildCommandBubble(theme, context);
      case MessageType.output:
        return _buildOutputBubble(theme, context);
      case MessageType.system:
        return _buildSystemMessage(theme);
      case MessageType.fileTransfer:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCommandBubble(ThemeData theme, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: Radius.zero,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Icon(Icons.copy, size: 13,
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputBubble(ThemeData theme, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: Radius.zero,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      message.content,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Icon(Icons.copy, size: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
