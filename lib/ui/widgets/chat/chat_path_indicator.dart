import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/chat_provider.dart';

class ChatPathIndicator extends ConsumerStatefulWidget {
  final Future<String> Function(String command) onExecute;

  const ChatPathIndicator({super.key, required this.onExecute});

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
      onTap: () {
        if (_overlay != null) {
          _overlay!.remove();
          _overlay = null;
        } else {
          _showDirDropdown();
        }
      },
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  chatState.currentDirectory,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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
    setState(() => _loading = true);

    try {
      final raw = await widget.onExecute('ls -la');
      final lines = raw.trim().split('\n');
      if (lines.isEmpty) { setState(() => _loading = false); return; }

      final newPwd = lines.last.trim();
      if (newPwd.startsWith('/')) {
        ref.read(chatProvider.notifier).setDirectory(newPwd);
      }

      final dirs = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.length < 2 || !trimmed.startsWith('d')) continue;
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 9) {
          final name = parts.sublist(8).join(' ');
          if (name != '.' && name.isNotEmpty) {
            dirs.add(name);
          }
        }
      }
      // '..' first, then non-hidden dirs (alpha), then hidden dirs (alpha)
      dirs.sort((a, b) {
        if (a == '..') return -1;
        if (b == '..') return 1;
        final aHidden = a.startsWith('.');
        final bHidden = b.startsWith('.');
        if (aHidden != bHidden) return aHidden ? 1 : -1;
        return a.compareTo(b);
      });

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
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
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
                              shrinkWrap: true, padding: EdgeInsets.zero,
                              itemCount: _dirs.length,
                              itemBuilder: (context, index) {
                                final dir = _dirs[index];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.folder,
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

  Future<void> _cdInto(String dir) async {
    try {
      await widget.onExecute('cd "$dir"');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录切换失败: $e')),
      );
    }
  }
}
