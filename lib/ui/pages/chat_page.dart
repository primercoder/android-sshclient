import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/chat_message.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/direct_connect_info.dart';
import 'package:ssh_client/data/models/quick_command.dart';
import 'package:ssh_client/data/database/dao/quick_command_dao.dart';
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
  bool _connected = false;
  bool _error = false;
  String _errorMsg = '';
  int _prevMsgCount = 0;
  List<QuickCommand> _quickCommands = [];

  String get hostId {
    if (widget.host != null) return widget.host!.hostId;
    if (widget.directConnectInfo != null) return widget.directConnectInfo!.ip;
    return '';
  }

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initSession();
        _loadQuickCommands();
      });
    }
  }

  Future<void> _loadQuickCommands() async {
    try {
      final dao = await ref.read(quickCommandDaoProvider.future);
      if (mounted) setState(() => _quickCommands = dao.getAll());
    } catch (_) {}
  }

  Future<void> _addQuickCommand() async {
    final nameCtrl = TextEditingController();
    final cmdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加快捷命令'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '显示名称', hintText: '例如: ls',
                isDense: false,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: cmdCtrl,
              decoration: const InputDecoration(
                labelText: '命令', hintText: '例如: ls -la',
                isDense: false,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入命令' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(ctx, true);
          }, child: const Text('添加')),
        ],
      ),
    );
    if (result != true || !mounted) return;

    try {
      final dao = await ref.read(quickCommandDaoProvider.future);
      dao.insert(QuickCommand(
        label: nameCtrl.text.trim(),
        command: cmdCtrl.text.trim(),
      ));
      _loadQuickCommands();
    } catch (_) {}
  }

  void _editQuickCommand(QuickCommand cmd) {
    final nameCtrl = TextEditingController(text: cmd.label);
    final cmdCtrl = TextEditingController(text: cmd.command);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑快捷命令'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '显示名称', hintText: '例如: ls',
                isDense: false,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: cmdCtrl,
              decoration: const InputDecoration(
                labelText: '命令', hintText: '例如: ls -la',
                isDense: false,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入命令' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final dao = await ref.read(quickCommandDaoProvider.future);
            dao.update(cmd.copyWith(
              label: nameCtrl.text.trim(),
              command: cmdCtrl.text.trim(),
            ));
            Navigator.pop(ctx);
            _loadQuickCommands();
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  void _deleteQuickCommand(QuickCommand cmd) async {
    try {
      final dao = await ref.read(quickCommandDaoProvider.future);
      dao.delete(cmd.commandId!);
      _loadQuickCommands();
    } catch (_) {}
  }

  String get _hostName {
    if (widget.host != null) {
      return widget.host!.displayName.isNotEmpty ? widget.host!.displayName : widget.host!.currentIp;
    }
    if (widget.directConnectInfo != null) return widget.directConnectInfo!.username;
    return '';
  }

  String get _hostIp {
    if (widget.host != null) return widget.host!.currentIp;
    if (widget.directConnectInfo != null) return widget.directConnectInfo!.ip;
    return '';
  }

  Future<void> _initSession() async {
    final sshService = ref.read(sshClientServiceProvider);
    final sshConn = ref.read(sshConnectionProvider.notifier);
    final chat = ref.read(chatProvider.notifier);

    if (!sshConn.isConnected || sshService.client == null) {
      setState(() { _error = true; _errorMsg = 'SSH 未连接，请返回重试'; });
      return;
    }

    setState(() => _connected = true);
    final reused = await chat.startNewSession(hostId, hostName: _hostName, hostIp: _hostIp);

    if (reused) {
      // Restore last-known directory by verifying it still exists
      final lastDir = ref.read(chatProvider).currentDirectory;
      try {
        final result = await sshService.execute('cd "$lastDir" && pwd');
        final verified = result.trim();
        if (verified.isNotEmpty && verified.startsWith('/')) {
          chat.setDirectory(verified);
        }
      } catch (_) {
        try {
          final homeDir = await sshService.getHomeDirectory();
          if (homeDir.isNotEmpty) chat.setDirectory(homeDir);
        } catch (_) {}
      }
    } else {
      await chat.addSystemMessage('连接已建立 | $_subtitle');
      try {
        final homeDir = await sshService.getHomeDirectory();
        if (homeDir.isNotEmpty) {
          chat.setDirectory(homeDir);
        }
      } catch (_) {}
      await chat.addSystemMessage('提示: 在下方输入命令，按回车发送');
    }
    _scrollToBottom();
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

  /// Execute a raw command wrapped with cd prefix and pwd suffix,
  /// parse the new working directory from the last output line,
  /// update the path bar, and return the raw output (caller uses it
  /// for parsing directory listings etc.).  Does NOT add anything to chat.
  Future<String> _executeWrapped(String command) async {
    final sshService = ref.read(sshClientServiceProvider);
    final currentPwd = ref.read(chatProvider).currentDirectory;

    final wrapped = 'cd "$currentPwd" && $command && pwd';
    final raw = await sshService.executeCombined(wrapped);
    final output = raw.trim();

    if (output.isNotEmpty) {
      final lines = output.split('\n');
      final newPwd = lines.last.trim();
      if (newPwd.isNotEmpty && newPwd.startsWith('/')) {
        ref.read(chatProvider.notifier).setDirectory(newPwd);
      }
    }
    return output;
  }

  void _appendCommand(String command) {
    final existing = _inputController.text;
    if (existing.isNotEmpty && !existing.endsWith(' ')) {
      _inputController.text = '$existing $command';
    } else {
      _inputController.text = '$existing$command';
    }
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
  }

  Future<void> _sendCommand(String command) async {
    if (command.trim().isEmpty || !_connected) return;

    final chat = ref.read(chatProvider.notifier);

    await chat.addCommand(command);

    try {
      final output = await _executeWrapped(command);

      if (output.isEmpty) return;

      final lines = output.split('\n');
      
      if (lines.length > 1) {
        final cmdOut = lines.sublist(0, lines.length - 1).join('\n');
        await chat.addOutput(cmdOut);
      } else if (output.isNotEmpty && !output.startsWith('/')) {
        await chat.addOutput(output);
      }
    } catch (e) {
      await chat.addSystemMessage('命令执行错误: $e');
    }
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _inputController.text;
    _inputController.clear();
    _sendCommand(text);
  }

  Future<bool> _onWillPop() async {
    if (_connected && !widget.readOnly) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('离开会话'),
          content: const Text('SSH 连接仍保持活跃，可在主页管理。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('保持会话'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(chatProvider.notifier).endSession(hostId);
                ref.read(sshConnectionProvider.notifier).disconnect();
                Navigator.pop(ctx, 'disconnect');
              },
              child: const Text('断开连接'),
            ),
          ],
        ),
      );
      return result != null;
    }
    return true;
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

    if (chatState.messages.length > _prevMsgCount) {
      _prevMsgCount = chatState.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('在线', style: TextStyle(fontSize: 12, color: Colors.green[700])),
                  ],
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (!widget.readOnly && _connected) ChatPathIndicator(onExecute: _executeWrapped),

            Expanded(
              child: GestureDetector(
                onTap: () => _inputFocus.unfocus(),
                child: chatState.messages.isEmpty && !_error
                  ? Center(
                      child: Text(_connected ? '等待输入命令...' : '连接中...',
                          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
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
            ),

            if (_error)
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.errorContainer,
                child: Column(children: [
                  Text(_errorMsg, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: () => Navigator.pop(context), child: const Text('返回重试')),
                ]),
              ),

            if (!widget.readOnly && _connected) ChatSuggestionChips(
              commands: _quickCommands,
              onSelected: _appendCommand,
              onAdd: _addQuickCommand,
              onEdit: _editQuickCommand,
              onDelete: _deleteQuickCommand,
            ),

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
      ),
    );
  }
}
