import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/scan_result.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/ui/pages/chat_page.dart';
import 'package:ssh_client/data/models/direct_connect_info.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  List<ScanResult> _results = [];
  bool _isScanning = false;
  String _subnet = '192.168.1';

  @override
  void initState() {
    super.initState();
    _detectSubnet();
  }

  void _detectSubnet() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              addr.address.startsWith('192.168.')) {
            final parts = addr.address.split('.');
            setState(() => _subnet = '${parts[0]}.${parts[1]}.${parts[2]}');
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    final scanner = ref.read(lanScannerProvider);

    try {
      final results = await scanner.scan(subnet: _subnet);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描出错: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _connectTo(String ip, {int port = 22}) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => ChatPage(
        host: null,
        directConnectInfo: DirectConnectInfo(
          ip: ip, port: port, username: 'root', password: '',
        ),
      )),
    );
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: '子网',
                          prefixIcon: Icon(Icons.network_check),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        controller: TextEditingController(text: _subnet),
                        onChanged: (v) => _subnet = v.trim(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isScanning ? null : _startScan,
                      child: Text(_isScanning ? '扫描中...' : '扫描'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isScanning
                      ? '正在扫描 $_subnet.0/24...'
                      : '发现 ${_results.length} 台主机 (端口 22)',
                  style: theme.textTheme.bodySmall,
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
                      _isScanning ? '扫描中，请稍候...' : '点击 "扫描" 按钮开始',
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
                          title: Text('${result.ip}:${result.port}'),
                          subtitle: Text(
                            'SSH: ${result.sshBanner ?? "未知"}'
                            '\n响应: ${result.responseTimeMs}ms',
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () => _connectTo(result.ip, port: result.port),
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
