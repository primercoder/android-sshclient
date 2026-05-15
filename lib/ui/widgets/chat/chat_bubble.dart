import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssh_client/data/models/chat_message.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _wrapped = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = widget.message;

    switch (msg.type) {
      case MessageType.command:
        return _buildCommandBubble(theme);
      case MessageType.output:
        return _buildOutputBubble(theme);
      case MessageType.system:
        return _buildSystemMessage(theme);
      case MessageType.fileTransfer:
        return const SizedBox.shrink();
    }
  }

  Widget _iconRow(ThemeData theme, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: widget.message.content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
            );
          },
          child: Icon(Icons.copy, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => setState(() => _wrapped = !_wrapped),
          child: Icon(
            _wrapped ? Icons.swap_horiz : Icons.text_snippet,
            size: 16,
            color: iconColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCommandBubble(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: Radius.zero,
                    ),
                  ),
                  child: _wrapped
                      ? Text(
                          widget.message.content,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            widget.message.content,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                _iconRow(theme, theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputBubble(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: Radius.zero,
                    ),
                  ),
                  child: _wrapped
                      ? SelectableText(
                          widget.message.content,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            widget.message.content,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                _iconRow(theme, theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ],
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
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.message.content,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
