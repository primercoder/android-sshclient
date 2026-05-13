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
          top: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
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
              const SizedBox(width: 12),
              _FileActionButton(
                icon: Icons.folder_open,
                label: '浏览远程',
                onTap: () => _browseRemote(context, ref),
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

    final transferService = ScpTransferService(sshService.client!);
    final transferNotifier = ref.read(transferProvider.notifier);

    final task = await transferService.uploadFile(
      localPath: file.path!,
      remotePath: currentDirectory,
      sessionId: sessionId,
      transferId: const Uuid().v4(),
    );

    await transferNotifier.addTransfer(task);

    final chat = ref.read(chatProvider.notifier);
    await chat.addSystemMessage(
      '📄 文件上传完成: ${file.name} (${task.formattedSize})',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传完成: ${file.name}')),
      );
    }
  }

  void _showDownloadDialog(BuildContext context, WidgetRef ref) {
    final remoteCtrl = TextEditingController(
      text: '$currentDirectory/',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载文件'),
        content: TextField(
          controller: remoteCtrl,
          decoration: const InputDecoration(
            labelText: '远程文件路径',
            hintText: '/home/user/file.txt',
            prefixIcon: Icon(Icons.terminal),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _downloadFile(remoteCtrl.text, context, ref);
            },
            child: const Text('下载'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(
      String remotePath, BuildContext context, WidgetRef ref) async {
    if (remotePath.isEmpty) return;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '保存文件',
      fileName: remotePath.split('/').last,
    );
    if (savePath == null) return;

    final sshService = ref.read(sshClientServiceProvider);
    if (sshService.client == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SSH 未连接')),
        );
      }
      return;
    }

    final transferService = ScpTransferService(sshService.client!);
    final transferNotifier = ref.read(transferProvider.notifier);

    final task = await transferService.downloadFile(
      remotePath: remotePath,
      localPath: savePath,
      sessionId: sessionId,
      transferId: const Uuid().v4(),
    );

    await transferNotifier.addTransfer(task);

    final chat = ref.read(chatProvider.notifier);
    await chat.addSystemMessage(
      '📥 文件下载完成: ${remotePath.split('/').last}',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载完成: ${remotePath.split('/').last}')),
      );
    }
  }

  void _browseRemote(BuildContext context, WidgetRef ref) {
    final dirCtrl = TextEditingController(text: currentDirectory);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('远程目录'),
        content: TextField(
          controller: dirCtrl,
          decoration: const InputDecoration(
            labelText: '远程路径',
            prefixIcon: Icon(Icons.folder),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('浏览'),
          ),
        ],
      ),
    );
  }
}

class _FileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
