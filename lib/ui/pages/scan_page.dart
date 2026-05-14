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
  late TextEditingController _cidrCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _cidrCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectNetwork());
  }

  void _detectNetwork() async {
    final scanner = ref.read(lanScannerProvider);
    final cidr = await scanner.detectCurrentCidr();
    _cidrCtrl.text = cidr;
  }

  Future<void> _startScan() async {
    final cidr = _cidrCtrl.text.trim();
    final scanner = ref.read(lanScannerProvider);

    if (!scanner.isValidCidr(cidr)) {
      setState(() => _errorText = '格式错误，示例: 192.168.1.1/24');
      return;
    }
    setState(() {
      _errorText = null;
      _isScanning = true;
      _results = [];
    });

    try {
      final results = await scanner.scan(cidr: cidr);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = '扫描出错: $e');
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
  void dispose() {
    _cidrCtrl.dispose();
    super.dispose();
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
                        controller: _cidrCtrl,
                        decoration: InputDecoration(
                          labelText: 'CIDR 子网',
                          hintText: '192.168.1.1/24',
                          prefixIcon: const Icon(Icons.network_check),
                          isDense: true,
                          errorText: _errorText,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.text,
                        onChanged: (_) {
                          if (_errorText != null) setState(() => _errorText = null);
                        },
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
                      ? '正在扫描 ${_cidrCtrl.text} ...'
                      : '发现 ${_results.length} 台主机 (端口 22)',
                  style: theme.textTheme.bodySmall,
                ),
                if (_isScanning)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: const LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _isScanning ? '' : '点击 "扫描" 按钮开始',
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
                            child: Icon(Icons.dns, color: theme.colorScheme.primary),
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
