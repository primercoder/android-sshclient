import 'package:flutter/material.dart';
import 'package:ssh_client/data/models/chat_message.dart';

class TransferBubble extends StatelessWidget {
  final ChatMessage message;

  const TransferBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = message.content;

    final isUpload = t.length > 1 && t.codeUnitAt(1) == 0x2b06;
    final isTransferring = t.isNotEmpty && t.codeUnitAt(0) == 0x23f3;
    final isSuccess = t.startsWith('✅');
    final isError = t.startsWith('⚠');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isUpload ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isError
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isUpload ? null : Radius.zero,
                  bottomRight: isUpload ? Radius.zero : null,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTransferring)
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    )
                  else if (isSuccess)
                    Icon(isUpload ? Icons.upload_file : Icons.download,
                        size: 18,
                        color: theme.colorScheme.onTertiaryContainer)
                  else if (isError)
                    Icon(Icons.error_outline, size: 18,
                        color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isTransferring ? FontWeight.w400 : FontWeight.w500,
                        color: isError
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
