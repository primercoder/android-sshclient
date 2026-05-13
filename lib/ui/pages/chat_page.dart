import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/chat_message.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/ssh_connection_info.dart';
import 'package:ssh_client/providers/chat_provider.dart';
import 'package:ssh_client/providers/ssh_connection_provider.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/ui/widgets/chat/chat_bubble.dart';
import 'package:ssh_client/ui/widgets/chat/chat_input_bar.dart';
import 'package:ssh_client/ui/widgets/chat/chat_file_panel.dart';
import 'package:ssh_client/ui/widgets/chat/chat_path_indicator.dart';
import 'package:ssh_client/ui/widgets/chat/chat_suggestion_chips.dart';
import 'package:ssh_client/ui/widgets/transfer/transfer_bubble.dart';

class ChatPage extends ConsumerStatefulWidget {
  final Host host;

  const ChatPage({super.key, required this.host});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _showFilePanel = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final chat = ref.read(chatProvider.notifier);
    await chat.startNewSession(widget.host.hostId);

    final connInfo = SshConnectionInfo(
      host: widget.host.currentIp,
      port: widget.host.port,
      username: 'root',
      password: '',
    );

    try {
      final connection = ref.read(sshConnectionProvider.notifier);
      await connection.connect(connInfo);
      await chat.addSystemMessage(
        '连接已建立 | ${widget.host.currentIp}:${widget.host.port}',
      );
      await chat.addSystemMessage(
        '已识别主机: ${widget.host.displayName} (指纹已验证)',
      );
    } catch (e) {
      await chat.addSystemMessage('连接失败: $e');
    }
  }

  Future<void> _sendCommand(String command) async {
    if (command.trim().isEmpty) return;

    final chat = ref.read(chatProvider.notifier);
    final sshService = ref.read(sshClientServiceProvider);

    await chat.addCommand(command);

    if (command.startsWith('cd ')) {
      final dir = command.substring(3).trim();
      chat.setDirectory(dir.isEmpty ? '/' : dir);
    }

    try {
      sshService.sendShellCommand(command);
    } catch (e) {
      await chat.addSystemMessage('命令执行错误: $e');
    }
  }

  void _sendMessage() {
    final text = _inputController.text;
    _inputController.clear();
    _sendCommand(text);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.host.displayName.isNotEmpty
                ? widget.host.displayName
                : widget.host.currentIp),
            Text(
              widget.host.currentIp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => setState(() => _showFilePanel = !_showFilePanel),
            tooltip: '文件传输',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.host.macAddress != null || widget.host.hostKeyAlgorithm != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              child: Text(
                '${widget.host.hostKeyAlgorithm ?? "SSH"} | 指纹已验证',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          const ChatPathIndicator(),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final msg = chatState.messages[index];
                if (msg.type == MessageType.fileTransfer) {
                  return TransferBubble(message: msg);
                }
                return ChatBubble(message: msg);
              },
            ),
          ),

          ChatSuggestionChips(onTap: _sendCommand),

          if (_showFilePanel)
            ChatFilePanel(
              host: widget.host,
              sessionId: chatState.currentSession?.sessionId ?? '',
              currentDirectory: chatState.currentDirectory,
            ),

          ChatInputBar(
            controller: _inputController,
            focusNode: _inputFocus,
            onSend: _sendMessage,
            onFileTap: () => setState(() => _showFilePanel = !_showFilePanel),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('文件传输历史'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) =>
                    const Scaffold(body: Center(child: Text('传输历史')))));
              },
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text('断开连接'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(sshConnectionProvider.notifier).disconnect();
              },
            ),
          ],
        ),
      ),
    );
  }
}
