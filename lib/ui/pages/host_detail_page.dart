import 'package:flutter/material.dart';
import 'package:ssh_client/data/models/host.dart';

class HostDetailPage extends StatelessWidget {
  final Host host;

  const HostDetailPage({super.key, required this.host});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(host.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: '主机名', value: host.displayName),
                  _InfoRow(label: 'IP 地址', value: host.currentIp),
                  _InfoRow(label: '端口', value: host.port.toString()),
                  _InfoRow(label: 'MAC 地址',
                      value: host.macAddress ?? '未知'),
                  _InfoRow(label: 'SSH 指纹',
                      value: host.hostKeyFingerprint),
                  _InfoRow(label: '密钥算法',
                      value: host.hostKeyAlgorithm ?? '未知'),
                  _InfoRow(label: 'SSH 版本',
                      value: host.sshBanner ?? '未知'),
                  _InfoRow(label: '首次发现',
                      value: _formatDate(host.firstSeenAt)),
                  _InfoRow(label: '最后连接',
                      value: _formatDate(host.lastSeenAt)),
                  _InfoRow(label: '连接次数',
                      value: host.connectionCount.toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                )),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
