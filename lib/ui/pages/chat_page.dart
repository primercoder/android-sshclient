import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/chat_message.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/direct_connect_info.dart';
import 'package:ssh_client/data/models/quick_command.dart';
import 'package:ssh_client/providers/chat_provider.dart';
import 'package:ssh_client/providers/ssh_connection_provider.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/ui/widgets/chat/chat_bubble.dart';
import 'package:ssh_client/ui/widgets/chat/terminal_screen.dart';
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
  bool _inTerminalMode = false;
  double _terminalBtnRight = 16;
  double _terminalBtnBottom = 140;

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
      final newId = dao.insert(QuickCommand(
        label: nameCtrl.text.trim(),
        command: cmdCtrl.text.trim(),
      ));
      _quickCommands = dao.getAll();
      final idx = _quickCommands.indexWhere((c) => c.commandId == newId);
      if (idx > 0) {
        final cmd = _quickCommands.removeAt(idx);
        _quickCommands.insert(0, cmd);
        for (int i = 0; i < _quickCommands.length; i++) {
          dao.update(_quickCommands[i].copyWith(sortOrder: i));
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _editQuickCommand(QuickCommand cmd) async {
    final nameCtrl = TextEditingController(text: cmd.label);
    final cmdCtrl = TextEditingController(text: cmd.command);
    final formKey = GlobalKey<FormState>();

    await showDialog(
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
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
          }, child: const Text('保存')),
        ],
      ),
    );
    _loadQuickCommands();
  }

  Future<void> _deleteQuickCommand(QuickCommand cmd) async {
    try {
      final dao = await ref.read(quickCommandDaoProvider.future);
      dao.delete(cmd.commandId!);
      _loadQuickCommands();
    } catch (_) {}
  }

  Future<void> _reorderQuickCommand(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final cmd = _quickCommands.removeAt(oldIndex);
    _quickCommands.insert(newIndex, cmd);
    try {
      final dao = await ref.read(quickCommandDaoProvider.future);
      for (int i = 0; i < _quickCommands.length; i++) {
        dao.update(_quickCommands[i].copyWith(sortOrder: i));
      }
    } catch (_) {}
    setState(() {});
  }

  void _showManageSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final cmds = List<QuickCommand>.from(_quickCommands);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('快捷命令管理',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            _addQuickCommand().then((_) {
                              _loadQuickCommands().then((_) => setSheetState(() {}));
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('添加'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  if (cmds.isEmpty)
                    const Padding(padding: EdgeInsets.all(24), child: Text('暂无快捷命令'))
                  else
                    SizedBox(
                      height: (cmds.length * 64.0).clamp(0, 6 * 64.0),
                      child: ReorderableListView.builder(
                        itemCount: cmds.length,
                        onReorder: (o, n) {
                          final adjustedN = n > o ? n - 1 : n;
                          final cmd = cmds.removeAt(o);
                          cmds.insert(adjustedN, cmd);
                          _reorderQuickCommand(o, n).then((_) => setSheetState(() {}));
                        },
                        itemBuilder: (ctx, i) {
                          final cmd = cmds[i];
                          return ListTile(
                            key: ValueKey(cmd.commandId ?? i),
                            leading: const Icon(Icons.drag_handle),
                            title: Text(cmd.label, style: const TextStyle(fontSize: 14)),
                            subtitle: Text(cmd.command,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                                  onPressed: () {
                                    _editQuickCommand(cmd).then((_) {
                                      _loadQuickCommands().then((_) => setSheetState(() {}));
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 18, color: Colors.red[300]),
                                  onPressed: () {
                                    _deleteQuickCommand(cmd).then((_) {
                                      _loadQuickCommands().then((_) => setSheetState(() {}));
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
    _jumpToBottom();
    _prevMsgCount = ref.read(chatProvider).messages.length;
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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

  void _enterTerminalMode() {
    ref.read(chatProvider.notifier).addSystemMessage('已进入终端模式');
    setState(() => _inTerminalMode = true);
  }

  void _exitTerminalMode() {
    setState(() => _inTerminalMode = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSshAfterTerminal());
  }

  Future<void> _checkSshAfterTerminal() async {
    final sshService = ref.read(sshClientServiceProvider);
    final chat = ref.read(chatProvider.notifier);
    try {
      await sshService.execute('echo alive');
    } catch (_) {
      if (!mounted) return;
      chat.addSystemMessage('SSH 会话已结束');
      chat.endSession(hostId);
      ref.read(sshConnectionProvider.notifier).reset();
      Navigator.of(context).pop();
    }
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
        if (_inTerminalMode) {
          _exitTerminalMode();
          return;
        }
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
        body: _inTerminalMode
          ? TerminalScreen(onExit: _exitTerminalMode)
          : Stack(
              children: [
                Column(
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
                      onManage: _showManageSheet,
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
                if (_connected)
                  Positioned(
                    right: _terminalBtnRight,
                    bottom: _terminalBtnBottom,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _terminalBtnRight -= details.delta.dx;
                          _terminalBtnBottom -= details.delta.dy;
                        });
                      },
                      child: FloatingActionButton.small(
                        heroTag: 'terminal_enter',
                        onPressed: _enterTerminalMode,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.terminal),
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}
