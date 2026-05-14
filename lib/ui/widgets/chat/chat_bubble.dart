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

  Widget _buildCommandBubble(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.only(left: 14, top: 10, right: 6, bottom: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: Radius.zero,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _wrapped
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
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Icon(Icons.copy, size: 13,
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _wrapped = !_wrapped),
                        child: Icon(
                          _wrapped ? Icons.swap_horiz : Icons.text_snippet,
                          size: 14,
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.only(left: 14, top: 10, right: 6, bottom: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: Radius.zero,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _wrapped
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
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Icon(Icons.copy, size: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _wrapped = !_wrapped),
                        child: Icon(
                          _wrapped ? Icons.swap_horiz : Icons.text_snippet,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
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
