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
          Text('上传到: $currentDirectory',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
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
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final sshService = ref.read(sshClientServiceProvider);
    if (sshService.client == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SSH 未连接')),
        );
      }
      return;
    }

    final remotePath = '$currentDirectory/${file.name}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上传确认'),
        content: Text('上传 ${file.name} (${_formatBytes(file.size)})\n到: $remotePath'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('上传')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final transferService = ScpTransferService(sshService.client!);
    final transferNotifier = ref.read(transferProvider.notifier);

    try {
      final task = await transferService.uploadFile(
        localPath: file.path!,
        remotePath: currentDirectory,
        sessionId: sessionId,
        transferId: const Uuid().v4(),
      );
      await transferNotifier.addTransfer(task);
      final chat = ref.read(chatProvider.notifier);
      await chat.addSystemMessage('📄 上传完成: ${file.name} 到 $remotePath');
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
    final downloadDir = ref.read(downloadDirProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载文件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: remoteCtrl,
              decoration: const InputDecoration(
                labelText: '远程路径',
                hintText: '/home/user/file.txt',
                prefixIcon: Icon(Icons.terminal),
              ),
            ),
            const SizedBox(height: 8),
            Text('下载到: $downloadDir', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            final remotePath = remoteCtrl.text.trim();
            if (remotePath.isEmpty) return;
            Navigator.pop(ctx);
            await _downloadFile(remotePath, downloadDir, context, ref);
          }, child: const Text('下载')),
        ],
      ),
    );
  }

  Future<void> _downloadFile(
      String remotePath, String localDir, BuildContext context, WidgetRef ref) async {
    final filename = remotePath.split('/').last;
    final localPath = '$localDir/$filename';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载确认'),
        content: Text('下载 $remotePath\n到: $localPath'),
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

    final transferService = ScpTransferService(sshService.client!);
    final transferNotifier = ref.read(transferProvider.notifier);

    try {
      final task = await transferService.downloadFile(
        remotePath: remotePath,
        localPath: localPath,
        sessionId: sessionId,
        transferId: const Uuid().v4(),
      );
      await transferNotifier.addTransfer(task);
      final chat = ref.read(chatProvider.notifier);
      await chat.addSystemMessage('📥 下载完成: $filename 到 $localPath');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
