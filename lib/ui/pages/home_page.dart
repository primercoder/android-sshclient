import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/direct_connect_info.dart';
import 'package:ssh_client/ui/pages/scan_page.dart';
import 'package:ssh_client/ui/pages/chat_page.dart';
import 'package:ssh_client/ui/pages/host_detail_page.dart';
import 'package:ssh_client/ui/pages/history_page.dart';
import 'package:ssh_client/ui/pages/settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<Host> _hosts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHosts());
  }

  Future<void> _loadHosts() async {
    final dao = await ref.read(hostDaoProvider.future);
    final hosts = dao.getAllHosts();
    setState(() => _hosts = hosts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryPage())).then((_) => _loadHosts()),
            tooltip: '历史记录',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
            tooltip: '设置',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHosts,
        child: _hosts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dns_outlined, size: 80,
                        color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('还没有保存的主机',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('点击下方按钮扫描局域网或手动添加',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ScanPage())).then((_) => _loadHosts()),
                      icon: const Icon(Icons.wifi_find),
                      label: const Text('扫描局域网'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ScanPage())).then((_) => _loadHosts()),
                        icon: const Icon(Icons.wifi_find),
                        label: const Text('扫描局域网'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _hosts.length,
                      itemBuilder: (context, index) => _HostCard(
                        host: _hosts[index],
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ChatPage(host: _hosts[index]))),
                        onLongPress: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => HostDetailPage(host: _hosts[index]))),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add',
        onPressed: () => _showConnectDialog(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showConnectDialog(BuildContext context) {
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '22');
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('连接主机'),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP 地址',
                    prefixIcon: Icon(Icons.computer),
                    hintText: '192.168.1.100',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入 IP';
                    final parts = v.trim().split('.');
                    if (parts.length != 4) return 'IP 格式错误';
                    for (final p in parts) {
                      final n = int.tryParse(p);
                      if (n == null || n < 0 || n > 255) return 'IP 格式错误';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: portCtrl,
                  decoration: const InputDecoration(
                    labelText: '端口',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;

            final ip = ipCtrl.text.trim();
            final port = int.tryParse(portCtrl.text.trim()) ?? 22;
            final user = userCtrl.text.trim();
            final pass = passCtrl.text;

            Navigator.pop(ctx);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => ChatPage(
                  host: null,
                  directConnectInfo: DirectConnectInfo(
                    ip: ip, port: port, username: user, password: pass,
                  ),
                )));
          }, child: const Text('连接')),
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  final Host host;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HostCard({
    required this.host,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.dns, color: theme.colorScheme.primary),
        ),
        title: Text(
          host.displayName.isNotEmpty ? host.displayName : host.currentIp,
        ),
        subtitle: Text(
          '${host.currentIp}:${host.port}'
          '${host.macAddress != null ? ' | ${host.macAddress}' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${host.connectionCount} 次',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          ),
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
