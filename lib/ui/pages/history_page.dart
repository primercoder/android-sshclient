import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/session.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/chat_message.dart';
import 'package:ssh_client/providers/providers.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  List<_HostWithMessages> _hosts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final sessDao = await ref.read(sessionDaoProvider.future);
    final hostDao = await ref.read(hostDaoProvider.future);
    final msgDao = await ref.read(messageDaoProvider.future);

    final allSessions = sessDao.getAllSessions();
    final hostMap = <String, Host>{};
    for (final s in allSessions) {
      hostMap.putIfAbsent(s.hostId, () => hostDao.getHostById(s.hostId) ?? Host(
        hostId: s.hostId, currentIp: s.hostId, hostKeyFingerprint: s.hostId,
        firstSeenAt: s.startTime, lastSeenAt: s.startTime,
      ));
    }

    final result = <_HostWithMessages>[];
    for (final entry in hostMap.entries) {
      final hostSessions = allSessions.where((s) => s.hostId == entry.key).toList();
      final msgs = <ChatMessage>[];
      for (final s in hostSessions) {
        msgs.addAll(msgDao.getMessagesBySession(s.sessionId));
      }
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (msgs.isNotEmpty) {
        result.add(_HostWithMessages(host: entry.value, sessions: hostSessions, messages: msgs));
      }
    }
    result.sort((a, b) => b.messages.last.timestamp.compareTo(a.messages.last.timestamp));

    if (mounted) setState(() => _hosts = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: _hosts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('暂无历史记录',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _hosts.length,
              itemBuilder: (context, index) {
                final item = _hosts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.dns, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      item.host.displayName.isNotEmpty
                          ? item.host.displayName
                          : item.host.currentIp,
                    ),
                    subtitle: Text(
                      '${item.messages.length} 条消息 | ${_formatDate(item.messages.last.timestamp)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chevron_right),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('删除历史'),
                                content: Text('删除 ${item.host.displayName} 的所有会话记录？'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final sessDao = await ref.read(sessionDaoProvider.future);
                              final msgDao = await ref.read(messageDaoProvider.future);
                              for (final s in item.sessions) {
                                msgDao.deleteMessagesBySession(s.sessionId);
                                sessDao.deleteSession(s.sessionId);
                              }
                              _load();
                            }
                          },
                          child: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            _HistoryReplayPage(host: item.host, messages: item.messages))),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _HostWithMessages {
  final Host host;
  final List<Session> sessions;
  final List<ChatMessage> messages;
  const _HostWithMessages({required this.host, required this.sessions, required this.messages});
}

class _HistoryReplayPage extends StatelessWidget {
  final Host host;
  final List<ChatMessage> messages;
  const _HistoryReplayPage({required this.host, required this.messages});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(host.displayName.isNotEmpty ? host.displayName : host.currentIp),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          return _buildBubble(msg, theme);
        },
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, ThemeData theme) {
    switch (msg.type) {
      case MessageType.command:
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
                    borderRadius: BorderRadius.circular(16).copyWith(bottomRight: Radius.zero),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(msg.content,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 14,
                              color: theme.colorScheme.onPrimaryContainer)),
                      const SizedBox(height: 2),
                      Text(_formatTime(msg.timestamp),
                          style: TextStyle(fontSize: 10,
                              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case MessageType.output:
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
                    borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
                  ),
                  child: SelectableText(msg.content,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13,
                          color: theme.colorScheme.onSurface)),
                ),
              ),
            ],
          ),
        );
      case MessageType.system:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(msg.content,
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600])),
            ),
          ),
        );
      case MessageType.fileTransfer:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
