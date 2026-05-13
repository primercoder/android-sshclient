import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/chat_provider.dart';
import 'package:ssh_client/providers/providers.dart';

class ChatPathIndicator extends ConsumerStatefulWidget {
  const ChatPathIndicator({super.key});

  @override
  ConsumerState<ChatPathIndicator> createState() => _ChatPathIndicatorState();
}

class _ChatPathIndicatorState extends ConsumerState<ChatPathIndicator> {
  OverlayEntry? _overlay;
  List<String> _dirs = [];
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);

    if (chatState.currentDirectory.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _showDirDropdown,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_open, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                chatState.currentDirectory,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: chatState.currentDirectory));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('路径已复制'), duration: Duration(seconds: 1)),
                );
              },
              child: Icon(Icons.copy, size: 14, color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
      ),
    );
  }

  void _showDirDropdown() async {
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
      return;
    }

    setState(() => _loading = true);
    final path = ref.read(chatProvider).currentDirectory;
    final ssh = ref.read(sshClientServiceProvider);

    try {
      final output = await ssh.execute('cd "$path" && ls -a && pwd');
      final lines = output.trim().split('\n');
      final newPwd = lines.isNotEmpty ? lines.last.trim() : path;
      if (newPwd.startsWith('/')) {
        ref.read(chatProvider.notifier).setDirectory(newPwd);
      }

      // Collect directory names from ls -a
      final names = <String>[];
      for (final line in lines) {
        final name = line.trim();
        if (name.isEmpty || name == path || name == '.' ||
            name.startsWith('/') || name == newPwd) continue;
        names.add(name);
      }

      // Find which are directories
      final dirs = <String>['..'];
      for (final d in names) {
        try {
          final t = await ssh.execute('cd "$newPwd" && test -d "$d" && echo d');
          if (t.trim() == 'd') dirs.add(d);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() { _dirs = dirs; _loading = false; });
      _showOverlay();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取目录失败: $e')),
      );
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    _overlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            onTap: () { _overlay?.remove(); _overlay = null; },
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + box.size.height,
            right: 12,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Row(children: [
                        Text('子目录', style: Theme.of(context).textTheme.labelSmall),
                        const Spacer(),
                        GestureDetector(
                          onTap: () { _overlay?.remove(); _overlay = null; },
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ]),
                    ),
                    Flexible(
                      child: _dirs.isEmpty
                          ? const Padding(padding: EdgeInsets.all(16), child: Text('空目录'))
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _dirs.length,
                              itemBuilder: (context, index) {
                                final dir = _dirs[index];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    dir == '..' ? Icons.subdirectory_arrow_left : Icons.folder,
                                    size: 18, color: Colors.amber[700],
                                  ),
                                  title: Text(dir, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                                  trailing: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                                  onTap: () {
                                    _overlay?.remove();
                                    _overlay = null;
                                    _cdInto(dir);
                                  },
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

  void _cdInto(String dir) {
    final path = ref.read(chatProvider).currentDirectory;
    final ssh = ref.read(sshClientServiceProvider);

    String newPath;
    if (dir == '..') {
      if (path == '/') return;
      newPath = path.substring(0, path.lastIndexOf('/'));
      if (newPath.isEmpty) newPath = '/';
    } else {
      newPath = path == '/' ? '/$dir' : '$path/$dir';
    }

    ref.read(chatProvider.notifier).setDirectory(newPath);
    ssh.execute('cd "$newPath"').catchError((_) => '');
  }
}
