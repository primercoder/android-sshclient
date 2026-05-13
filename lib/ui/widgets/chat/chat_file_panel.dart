import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/services/scp/scp_transfer_service.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/providers/chat_provider.dart';
import 'package:ssh_client/providers/transfer_provider.dart';
import 'package:uuid/uuid.dart';

class ChatFilePanel extends ConsumerWidget {
  final Host host;
  final String sessionId;
  final String currentDirectory;

  const ChatFilePanel({
    super.key,
    required this.host,
    required this.sessionId,
    required this.currentDirectory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件传输', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              _FileActionButton(
                icon: Icons.upload_file,
                label: '上传文件',
                onTap: () => _uploadFile(context, ref),
              ),
              const SizedBox(width: 12),
              _FileActionButton(
                icon: Icons.download,
                label: '下载文件',
                onTap: () => _showDownloadDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFile(BuildContext context, WidgetRef ref) async {
    final remotePathCtrl = TextEditingController(text: currentDirectory);

    final fileResult = await FilePicker.platform.pickFiles();
    if (fileResult == null || fileResult.files.isEmpty) return;
    final file = fileResult.files.first;
    if (file.path == null) return;

    final remotePath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上传路径'),
        content: TextField(
          controller: remotePathCtrl,
          decoration: const InputDecoration(
            labelText: '远程路径',
            hintText: '/home/user/',
            prefixIcon: Icon(Icons.folder),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, remotePathCtrl.text.trim()), child: const Text('上传')),
        ],
      ),
    );
    if (remotePath == null || remotePath.isEmpty || !context.mounted) return;

    final sshService = ref.read(sshClientServiceProvider);
    if (sshService.client == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SSH 未连接')));
      return;
    }

    try {
      final transferService = ScpTransferService(sshService.client!);
      final task = await transferService.uploadFile(
        localPath: file.path!,
        remotePath: remotePath,
        sessionId: sessionId,
        transferId: const Uuid().v4(),
      );
      await ref.read(transferProvider.notifier).addTransfer(task);
      final chat = ref.read(chatProvider.notifier);
      await chat.addSystemMessage('📄 上传完成: ${file.name} → $remotePath');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  void _showDownloadDialog(BuildContext context, WidgetRef ref) {
    final remoteCtrl = TextEditingController(text: '$currentDirectory/');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载文件'),
        content: TextField(
          controller: remoteCtrl,
          decoration: const InputDecoration(
            labelText: '远程路径',
            hintText: '/home/user/file.txt',
            prefixIcon: Icon(Icons.terminal),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            final remotePath = remoteCtrl.text.trim();
            if (remotePath.isEmpty) return;
            Navigator.pop(ctx);
            await _downloadFile(remotePath, context, ref);
          }, child: const Text('下载')),
        ],
      ),
    );
  }

  Future<void> _downloadFile(String remotePath, BuildContext context, WidgetRef ref) async {
    final filename = remotePath.split('/').last;

    // Use SAF to pick save location (works on Android 14+)
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '保存文件',
      fileName: filename,
    );
    if (savePath == null || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载确认'),
        content: Text('下载 $remotePath\n到 $savePath'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('下载')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final sshService = ref.read(sshClientServiceProvider);
    if (sshService.client == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SSH 未连接')));
      return;
    }

    try {
      final transferService = ScpTransferService(sshService.client!);
      final task = await transferService.downloadFile(
        remotePath: remotePath,
        localPath: savePath,
        sessionId: sessionId,
        transferId: const Uuid().v4(),
      );

      await ref.read(transferProvider.notifier).addTransfer(task);
      final chat = ref.read(chatProvider.notifier);
      await chat.addSystemMessage('📥 下载完成: $filename → $savePath');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存到: $savePath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
}

class _FileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FileActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
