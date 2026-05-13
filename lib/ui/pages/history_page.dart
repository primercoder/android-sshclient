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
  List<_HostWithSessions> _hosts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final sessDao = await ref.read(sessionDaoProvider.future);
    final hostDao = await ref.read(hostDaoProvider.future);

    final allSessions = sessDao.getAllSessions();
    final hostMap = <String, Host>{};
    for (final s in allSessions) {
      final h = hostDao.getHostById(s.hostId);
      if (h != null) hostMap[s.hostId] = h;
    }

    final grouped = <String, List<Session>>{};
    for (final s in allSessions) {
      grouped.putIfAbsent(s.hostId, () => []).add(s);
    }

    setState(() {
      _hosts = grouped.entries.map((e) => _HostWithSessions(
        host: hostMap[e.key],
        hostId: e.key,
        sessions: e.value,
      )).toList()
        ..sort((a, b) => b.sessions.first.startTime.compareTo(a.sessions.first.startTime));
    });
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _hosts.length,
              itemBuilder: (context, index) {
                final item = _hosts[index];
                final lastSession = item.sessions.first;
                final totalCmds = item.sessions.fold<int>(0, (s, e) => s + e.commandCount);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.dns,
                          color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      item.host?.displayName.isNotEmpty == true
                          ? item.host!.displayName
                          : item.hostId.substring(0, 16),
                    ),
                    subtitle: Text(
                      '${item.sessions.length} 次连接 | $totalCmds 条命令'
                      '\n${_formatDate(lastSession.startTime)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            _SessionReplayPage(hostId: item.hostId, sessions: item.sessions))),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _HostWithSessions {
  final Host? host;
  final String hostId;
  final List<Session> sessions;
  const _HostWithSessions({
    required this.host, required this.hostId, required this.sessions,
  });
}

class _SessionReplayPage extends ConsumerStatefulWidget {
  final String hostId;
  final List<Session> sessions;
  const _SessionReplayPage({required this.hostId, required this.sessions});

  @override
  ConsumerState<_SessionReplayPage> createState() => _SessionReplayPageState();
}

class _SessionReplayPageState extends ConsumerState<_SessionReplayPage> {
  List<ChatMessage> _messages = [];
  Session? _selectedSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sessions.isNotEmpty) {
        _selectSession(widget.sessions.first);
      }
    });
  }

  Future<void> _selectSession(Session session) async {
    final msgDao = await ref.read(messageDaoProvider.future);
    final msgs = msgDao.getMessagesBySession(session.sessionId);
    setState(() {
      _selectedSession = session;
      _messages = msgs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedSession != null
            ? '会话 ${_formatDate(_selectedSession!.startTime)}'
            : '历史会话'),
        actions: [
          PopupMenuButton<Session>(
            icon: const Icon(Icons.date_range),
            tooltip: '切换会话',
            onSelected: _selectSession,
            itemBuilder: (_) => widget.sessions.map((s) =>
              PopupMenuItem(value: s, child: Text(
                '${_formatDate(s.startTime)} (${s.commandCount} 条)',
              )),
            ).toList(),
          ),
        ],
      ),
      body: _messages.isEmpty
          ? Center(
              child: Text('该会话无消息记录',
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildReadonlyBubble(msg, theme);
              },
            ),
    );
  }

  Widget _buildReadonlyBubble(ChatMessage msg, ThemeData theme) {
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
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: Radius.zero,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        msg.content,
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 14,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(msg.timestamp),
                        style: TextStyle(
                          fontSize: 10, color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                        ),
                      ),
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
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: Radius.zero,
                    ),
                  ),
                  child: SelectableText(
                    msg.content,
                    style: TextStyle(
                      fontFamily: 'monospace', fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
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

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
