import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _repoUrl = 'https://github.com/primercoder/android-sshclient';
  static const _licenseText = '''MIT License

Copyright (c) 2025 primercoder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

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
              onChanged: (v) => ref.read(isDarkModeProvider.notifier).update(v),
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
                  ref.read(downloadDirProvider.notifier).update(result);
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
                  trailing: const Text('1.0.1'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('开源协议'),
                  subtitle: const Text('MIT License'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicenseDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('GitHub'),
                  subtitle: const Text('github.com/primercoder/android-sshclient'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(Uri.parse(_repoUrl), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('MIT License'),
        content: SingleChildScrollView(
          child: SelectableText(
            _licenseText,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}
