import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/scan_result.dart';
import 'package:ssh_client/providers/providers.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  List<ScanResult> _results = [];
  bool _isScanning = false;

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    final scanner = ref.read(lanScannerProvider);
    final subnet = scanner.getLocalSubnet();

    try {
      final results = await scanner.scan(subnet: subnet);
      setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描出错: $e')),
        );
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('局域网扫描'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                Icon(Icons.wifi_find, size: 40,
                    color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  _isScanning ? '正在扫描 192.168.1.0/24...' : '发现 ${_results.length} 台主机',
                  style: theme.textTheme.titleMedium,
                ),
                if (_isScanning)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _isScanning ? '扫描中...' : '点击右上角刷新开始扫描',
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.dns,
                                color: theme.colorScheme.primary),
                          ),
                          title: Text(result.ip),
                          subtitle: Text(
                            'SSH: ${result.sshBanner ?? "未知"}'
                            '\n响应: ${result.responseTimeMs}ms',
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () {
                              // Navigate to chat with this host
                              Navigator.pop(context, result.ip);
                            },
                            child: const Text('连接'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
