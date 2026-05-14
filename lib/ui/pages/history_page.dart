import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/session.dart';
import 'package:ssh_client/data/models/chat_message.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/ui/widgets/chat/chat_bubble.dart';
import 'package:ssh_client/ui/widgets/transfer/transfer_bubble.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  List<_SessionWithMessages> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final sessDao = await ref.read(sessionDaoProvider.future);
    final msgDao = await ref.read(messageDaoProvider.future);

    final allSessions = sessDao.getAllSessions();
    final items = <_SessionWithMessages>[];
    for (final s in allSessions) {
      if (s.endTime == null) continue; // skip active sessions
      final msgs = msgDao.getMessagesBySession(s.sessionId);
      if (msgs.isEmpty) continue;
      items.add(_SessionWithMessages(session: s, messages: msgs));
    }

    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: _items.isEmpty
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
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final session = item.session;
                final hostLabel = session.hostName.isNotEmpty
                    ? session.hostName
                    : session.hostIp;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.dns, color: theme.colorScheme.primary),
                    ),
                    title: Text(hostLabel,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${session.hostIp} | ${item.messages.length} 条消息 | ${_formatDate(session.startTime)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _showSessionInfo(session),
                          child: Icon(Icons.info_outline, size: 18,
                              color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('删除历史'),
                                content: Text('删除此次会话（$hostLabel）记录？'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('取消')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('删除'),
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red)),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final sessDao = await ref.read(sessionDaoProvider.future);
                              final msgDao = await ref.read(messageDaoProvider.future);
                              msgDao.deleteMessagesBySession(session.sessionId);
                              sessDao.deleteSession(session.sessionId);
                              setState(() {
                                _items.removeWhere((i) => i.session.sessionId == session.sessionId);
                              });
                            }
                          },
                          child: Icon(Icons.delete_outline, size: 18,
                              color: Colors.red[300]),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            _HistoryReplayPage(session: session, messages: item.messages))),
                  ),
                );
              },
            ),
    );
  }

  void _showSessionInfo(Session session) {
    final hostLabel = session.hostName.isNotEmpty ? session.hostName : session.hostIp;
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('会话详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('主机', hostLabel),
            _infoRow('IP', session.hostIp),
            _infoRow('会话 ID', session.sessionId),
            _infoRow('开始时间', _formatDateTime(session.startTime)),
            if (session.endTime != null)
              _infoRow('结束时间', _formatDateTime(session.endTime!)),
            if (duration != null)
              _infoRow('持续时长', _formatDuration(duration)),
            _infoRow('命令数', '${session.commandCount}'),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text('$label：',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}时${m}分${s}秒';
    if (m > 0) return '${m}分${s}秒';
    return '${s}秒';
  }
}

class _SessionWithMessages {
  final Session session;
  final List<ChatMessage> messages;
  const _SessionWithMessages({required this.session, required this.messages});
}

class _HistoryReplayPage extends StatelessWidget {
  final Session session;
  final List<ChatMessage> messages;
  const _HistoryReplayPage({required this.session, required this.messages});

  @override
  Widget build(BuildContext context) {
    final hostLabel = session.hostName.isNotEmpty ? session.hostName : session.hostIp;

    return Scaffold(
      appBar: AppBar(
        title: Text(hostLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '会话详情',
            onPressed: () {
              final duration = session.endTime != null
                  ? session.endTime!.difference(session.startTime)
                  : null;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('会话详情'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('主机', hostLabel),
                      _infoRow('IP', session.hostIp),
                      _infoRow('会话 ID', session.sessionId),
                      _infoRow('开始时间', _formatDateTime(session.startTime)),
                      if (session.endTime != null)
                        _infoRow('结束时间', _formatDateTime(session.endTime!)),
                      if (duration != null)
                        _infoRow('持续时长', _formatDuration(duration)),
                      _infoRow('命令数', '${session.commandCount}'),
                    ],
                  ),
                  actions: [
                    FilledButton(onPressed: () => Navigator.pop(ctx),
                        child: const Text('关闭')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: messages.isEmpty
          ? const Center(child: Text('无消息'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                if (msg.type == MessageType.fileTransfer) {
                  return TransferBubble(message: msg);
                }
                return ChatBubble(message: msg);
              },
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text('$label：',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}时${m}分${s}秒';
    if (m > 0) return '${m}分${s}秒';
    return '${s}秒';
  }
}
