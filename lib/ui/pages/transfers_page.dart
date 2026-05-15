import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/transfer_task.dart';
import 'package:ssh_client/providers/transfer_provider.dart';

class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key});

  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(transferProvider.notifier).loadTransfers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(transferProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('文件传输')),
      body: state.activeTransfers.isEmpty && state.historyTransfers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download, size: 80,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('暂无传输记录',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (state.activeTransfers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('正在传输',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        )),
                  ),
                  ...state.activeTransfers.map((task) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        task.direction == TransferDirection.upload
                            ? Icons.upload_file : Icons.download,
                        color: task.direction == TransferDirection.upload
                            ? Colors.orange : Colors.blue,
                      ),
                      title: Text(task.filename),
                      subtitle: LinearProgressIndicator(value: task.progress),
                    ),
                  )),
                ],
                if (state.historyTransfers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text('传输历史',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        )),
                  ),
                  ...state.historyTransfers.map((task) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        task.status == TransferStatus.completed
                            ? Icons.check_circle : Icons.error,
                        color: task.status == TransferStatus.completed
                            ? Colors.green : Colors.red,
                      ),
                      title: Text(task.filename),
                      subtitle: Text(task.formattedSize),
                    ),
                  )),
                ],
              ],
            ),
    );
  }
}
