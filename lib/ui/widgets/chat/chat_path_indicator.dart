import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_client/providers/chat_provider.dart';
import 'package:ssh_client/providers/providers.dart';

class _RemoteEntry {
  final String name;
  final bool isDir;
  final String type;
  final String size;
  final String perms;

  const _RemoteEntry({
    required this.name,
    required this.isDir,
    this.type = 'other',
    this.size = '',
    this.perms = '',
  });

  IconData get icon {
    if (name == '..') return Icons.subdirectory_arrow_left;
    if (isDir) return Icons.folder;
    switch (type) {
      case 'text': return Icons.description;
      case 'image': return Icons.image;
      case 'video': return Icons.videocam;
      case 'audio': return Icons.audiotrack;
      default: return Icons.help_outline;
    }
  }
}

class ChatPathIndicator extends ConsumerStatefulWidget {
  const ChatPathIndicator({super.key});

  @override
  ConsumerState<ChatPathIndicator> createState() => _ChatPathIndicatorState();
}

class _ChatPathIndicatorState extends ConsumerState<ChatPathIndicator> {
  List<_RemoteEntry>? _entries;
  bool _loading = false;
  OverlayEntry? _overlay;

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);

    if (chatState.currentDirectory.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _toggleDirectoryList,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 14,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  chatState.currentDirectory,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: chatState.currentDirectory,
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('路径已复制'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(Icons.copy, size: 14,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleDirectoryList() {
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
      return;
    }
    _loadDirectoryList();
  }

  Future<void> _loadDirectoryList() async {
    setState(() => _loading = true);
    final chatState = ref.read(chatProvider);
    final sshService = ref.read(sshClientServiceProvider);

    try {
      final session = await sshService.client!.execute(
        'ls -la "${chatState.currentDirectory}"',
        pty: const SSHPtyConfig(width: 200),
      );
      final output = await session.stdout.transform(
        utf8.decoder as StreamTransformer<Uint8List, String>,
      ).join();
      await session.done;

      final entries = _parseLsOutput(output);
      setState(() {
        _entries = entries;
        _loading = false;
      });
      _showOverlay();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法获取目录: $e')),
        );
      }
    }
  }

  List<_RemoteEntry> _parseLsOutput(String output) {
    final entries = <_RemoteEntry>[
      const _RemoteEntry(name: '..', isDir: true),
    ];
    final lines = output.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('total ')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 9) continue;

      final perms = parts[0];
      final isDir = perms.startsWith('d');
      final size = parts[4];
      final name = parts.sublist(8).join(' ');

      if (name == '.' || name == '..') continue;

      String type = 'other';
      if (!isDir) {
        final lower = name.toLowerCase();
        if (RegExp(r'\.(txt|md|json|xml|yaml|yml|conf|cfg|ini|log|sh|py|js|ts|dart|java|kt|c|cpp|h|rb|go|rs|toml)$').hasMatch(lower)) {
          type = 'text';
        } else if (RegExp(r'\.(png|jpg|jpeg|gif|bmp|svg|webp|ico)$').hasMatch(lower)) {
          type = 'image';
        } else if (RegExp(r'\.(mp4|avi|mkv|mov|wmv|flv|webm)$').hasMatch(lower)) {
          type = 'video';
        } else if (RegExp(r'\.(mp3|wav|flac|aac|ogg|wma|m4a)$').hasMatch(lower)) {
          type = 'audio';
        }
      }

      entries.add(_RemoteEntry(
        name: name,
        isDir: isDir,
        type: type,
        size: size,
        perms: perms,
      ));
    }
    return entries;
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    _overlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            onTap: () {
              _overlay?.remove();
              _overlay = null;
            },
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + box.size.height,
            right: MediaQuery.of(context).size.width - position.dx,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '目录内容',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _overlay?.remove();
                              _overlay = null;
                            },
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _entries?.length ?? 0,
                        itemBuilder: (context, index) {
                          final entry = _entries![index];
                          return ListTile(
                            dense: true,
                            leading: Icon(entry.icon, size: 18,
                                color: entry.isDir
                                    ? Colors.amber[700]
                                    : Colors.grey[600]),
                            title: Text(entry.name,
                                style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                            subtitle: entry.size.isNotEmpty && !entry.isDir
                                ? Text(entry.size, style: const TextStyle(fontSize: 11))
                                : null,
                            trailing: entry.isDir
                                ? Icon(Icons.chevron_right, size: 16, color: Colors.grey[400])
                                : Icon(Icons.download, size: 16, color: Colors.blue[300]),
                            onTap: () => _onEntryTap(entry),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlay!);
  }

  void _onEntryTap(_RemoteEntry entry) {
    _overlay?.remove();
    _overlay = null;

    final chatState = ref.read(chatProvider);
    final chat = ref.read(chatProvider.notifier);

    if (entry.isDir) {
      String newPath;
      if (entry.name == '..') {
        final current = chatState.currentDirectory;
        if (current == '/') return;
        newPath = current.substring(0, current.lastIndexOf('/'));
        if (newPath.isEmpty) newPath = '/';
      } else {
        newPath = chatState.currentDirectory == '/'
            ? '/${entry.name}'
            : '${chatState.currentDirectory}/${entry.name}';
      }
      chat.setDirectory(newPath);
      _sendCommand('cd "$newPath"');
    } else {
      _promptDownload(entry);
    }
  }

  void _sendCommand(String cmd) {
    final sshService = ref.read(sshClientServiceProvider);
    try {
      sshService.sendShellCommand(cmd);
    } catch (_) {}
  }

  void _promptDownload(_RemoteEntry entry) {
    final chatState = ref.read(chatProvider);
    final path = chatState.currentDirectory == '/'
        ? '/${entry.name}'
        : '${chatState.currentDirectory}/${entry.name}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载文件'),
        content: Text('是否下载 "$path"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(onPressed: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('开始下载: $path')),
            );
          }, child: const Text('下载')),
        ],
      ),
    );
  }
}
