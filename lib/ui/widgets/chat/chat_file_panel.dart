import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/transfer_task.dart';
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
      if (task.status == TransferStatus.completed) {
        final msg = '上传完成: ${file.name} → $remotePath';
        await chat.addSystemMessage('📄 $msg');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      } else {
        final err = task.errorMessage ?? '未知错误';
        await chat.addSystemMessage('⚠️ 上传失败: $err');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: $err'), backgroundColor: Colors.red[700]),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  void _showDownloadDialog(BuildContext context, WidgetRef ref) {
    final remoteCtrl = TextEditingController(text: '$currentDirectory/');
    final localCtrl = TextEditingController(text: ref.read(downloadDirProvider));

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
                labelText: '远程路径 (含文件名)',
                hintText: '/home/user/file.txt',
                prefixIcon: Icon(Icons.terminal),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: localCtrl,
              decoration: const InputDecoration(
                labelText: '保存到目录',
                hintText: '/storage/emulated/0/Download',
                prefixIcon: Icon(Icons.folder),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            final remotePath = remoteCtrl.text.trim();
            final localDir = localCtrl.text.trim();
            if (remotePath.isEmpty || localDir.isEmpty) return;
            Navigator.pop(ctx);
            await _downloadFile(remotePath, localDir, context, ref);
          }, child: const Text('下载')),
        ],
      ),
    );
  }

  Future<void> _downloadFile(String remotePath, String downloadDir, BuildContext context, WidgetRef ref) async {
    final filename = remotePath.split('/').last;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在准备下载...'), duration: Duration(seconds: 2)),
      );
    }

    // Determine a writable local path:
    //   1. Try the user-configured download directory
    //   2. Fall back to the app's documents directory
    String localPath;
    try {
      localPath = '${downloadDir.endsWith('/') ? downloadDir : '$downloadDir/'}$filename';
      // Verify the parent directory is writable
      final dir = Directory(localPath.substring(0, localPath.lastIndexOf('/')));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // Quick writeability test
      final testFile = File(localPath);
      await testFile.writeAsBytes([]);
      await testFile.delete();
    } catch (_) {
      // Configured directory not writable (scoped storage) — use app private dir
      final appDir = await getApplicationDocumentsDirectory();
      localPath = '${appDir.path}/$filename';
    }

    // Confirm with user
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载确认'),
        content: Text('下载 $remotePath\n到 $localPath'),
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在传输...'), duration: Duration(seconds: 1)),
      );
    }

    try {
      final transferService = ScpTransferService(sshService.client!);
      final task = await transferService.downloadFile(
        remotePath: remotePath,
        localPath: localPath,
        sessionId: sessionId,
        transferId: const Uuid().v4(),
      );

      await ref.read(transferProvider.notifier).addTransfer(task);
      final chat = ref.read(chatProvider.notifier);
      if (task.status == TransferStatus.completed) {
        final msg = '下载完成: $filename → $localPath';
        await chat.addSystemMessage('📥 $msg');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      } else {
        final err = task.errorMessage ?? '未知错误';
        await chat.addSystemMessage('⚠️ 下载失败: $err');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下载失败: $err'), backgroundColor: Colors.red[700]),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e'), backgroundColor: Colors.red[700]),
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
