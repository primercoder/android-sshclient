import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('深色模式'),
              subtitle: Text(isDark ? '已开启' : '已关闭'),
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                  color: theme.colorScheme.primary),
              value: isDark,
              onChanged: (v) => ref.read(isDarkModeProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.download, color: theme.colorScheme.primary),
              title: const Text('下载目录'),
              subtitle: Text(ref.watch(downloadDirProvider)),
              onTap: () async {
                final ctrl = TextEditingController(
                  text: ref.read(downloadDirProvider),
                );
                final result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('下载目录'),
                    content: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        hintText: '/storage/emulated/0/Download',
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存')),
                    ],
                  ),
                );
                if (result != null && result.isNotEmpty) {
                  ref.read(downloadDirProvider.notifier).state = result;
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('关于', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('版本'),
                  trailing: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('技术栈'),
                  subtitle: const Text('Flutter + dartssh2 + SQLite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
