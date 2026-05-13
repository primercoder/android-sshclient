import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/chat_message.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/direct_connect_info.dart';
import 'package:ssh_client/providers/chat_provider.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/ui/widgets/chat/chat_bubble.dart';
import 'package:ssh_client/ui/widgets/chat/chat_input_bar.dart';
import 'package:ssh_client/ui/widgets/chat/chat_file_panel.dart';
import 'package:ssh_client/ui/widgets/chat/chat_path_indicator.dart';
import 'package:ssh_client/ui/widgets/chat/chat_suggestion_chips.dart';
import 'package:ssh_client/ui/widgets/transfer/transfer_bubble.dart';

class ChatPage extends ConsumerStatefulWidget {
  final Host? host;
  final DirectConnectInfo? directConnectInfo;
  final bool readOnly;

  const ChatPage({
    super.key,
    this.host,
    this.directConnectInfo,
    this.readOnly = false,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _showFilePanel = false;
  StreamSubscription<String>? _outputSubscription;
  bool _connected = false;
  bool _error = false;
  String _errorMsg = '';

  String get _title {
    if (widget.host != null) {
      return widget.host!.displayName.isNotEmpty
          ? widget.host!.displayName
          : widget.host!.currentIp;
    }
    if (widget.directConnectInfo != null) {
      return '${widget.directConnectInfo!.username}@${widget.directConnectInfo!.ip}';
    }
    return 'SSH';
  }

  String get _subtitle {
    if (widget.host != null) return widget.host!.currentIp;
    if (widget.directConnectInfo != null) {
      return '${widget.directConnectInfo!.ip}:${widget.directConnectInfo!.port}';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    if (!widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
    }
  }

  Future<void> _initSession() async {
    final sshService = ref.read(sshClientServiceProvider);
    final chat = ref.read(chatProvider.notifier);

    String hostId;
    if (widget.host != null) {
      hostId = widget.host!.hostId;
    } else if (widget.directConnectInfo != null) {
      hostId = widget.directConnectInfo!.ip;
    } else {
      return;
    }

    await chat.startNewSession(hostId);

    // Check if SSH client is already connected
    if (sshService.client == null || sshService.shellSession == null) {
      setState(() {
        _error = true;
        _errorMsg = 'SSH 未连接，请返回重试';
      });
      await chat.addSystemMessage('错误: SSH 未连接，请返回主页重新连接');
      return;
    }

    setState(() => _connected = true);
    await chat.addSystemMessage('连接已建立 | $_subtitle');

    // Subscribe to output stream
    final outputStream = sshService.outputStream;
    if (outputStream != null && _outputSubscription == null) {
      _outputSubscription = outputStream.listen((data) {
        chat.addOutput(data);
        _scrollToBottom();
      });
    }

    await chat.addSystemMessage('提示: 在下方输入命令，按回车发送');

    // Try to get initial shell prompt
    sshService.sendShellCommand('');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendCommand(String command) async {
    if (command.trim().isEmpty || !_connected) return;

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

  void _retry() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
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
            Text(_title),
            if (_subtitle.isNotEmpty)
              Text(_subtitle, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          ],
        ),
        actions: [
          if (_connected)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('在线', style: TextStyle(fontSize: 12, color: Colors.green[700])),
                ],
              ),
            ),
          if (!widget.readOnly && _connected)
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: () => setState(() => _showFilePanel = !_showFilePanel),
              tooltip: '文件传输',
            ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.readOnly && _connected) const ChatPathIndicator(),

          Expanded(
            child: chatState.messages.isEmpty && !_error
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('连接中...', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
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

          if (_error)
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.errorContainer,
              child: Column(
                children: [
                  Text(_errorMsg,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _retry,
                    child: const Text('返回重试'),
                  ),
                ],
              ),
            ),

          if (!widget.readOnly && _connected)
            ChatSuggestionChips(onTap: _sendCommand),

          if (!widget.readOnly && _connected && _showFilePanel && widget.host != null)
            ChatFilePanel(
              host: widget.host!,
              sessionId: chatState.currentSession?.sessionId ?? '',
              currentDirectory: chatState.currentDirectory,
            ),

          if (widget.readOnly)
            Container(
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('只读模式 — 历史会话回放',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            )
          else if (!_error)
            ChatInputBar(
              controller: _inputController,
              focusNode: _inputFocus,
              onSend: _connected ? _sendMessage : null,
              onFileTap: () => setState(() => _showFilePanel = !_showFilePanel),
            ),
        ],
      ),
    );
  }
}
