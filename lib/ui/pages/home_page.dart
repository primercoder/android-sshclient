import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/providers/ssh_connection_provider.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/direct_connect_info.dart';
import 'package:ssh_client/data/models/ssh_connection_info.dart';
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

  bool _isHostConnected(Host host) {
    final conn = ref.read(sshConnectionProvider.notifier).activeConnection;
    return conn != null && conn.host == host.currentIp && conn.port == host.port;
  }

  Future<void> _connectAndNavigate(Host host) async {
    final notifier = ref.read(sshConnectionProvider.notifier);

    if (_isHostConnected(host)) {
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatPage(host: host)));
      return;
    }

    final connInfo = SshConnectionInfo(
      host: host.currentIp, port: host.port,
      username: host.username, password: host.password,
    );

    if (!mounted) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final ok = await notifier.connect(connInfo);

    if (!mounted) return;
    Navigator.pop(context);

    if (ok) {
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatPage(host: host)));
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('连接失败'),
          content: Text(notifier.errorMessage ?? '未知错误'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
        ),
      );
    }
  }

  void _disconnectHost(Host host) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('断开连接'),
        content: Text('确定断开与 ${host.displayName} 的 SSH 连接？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            ref.read(sshConnectionProvider.notifier).disconnect();
            Navigator.pop(ctx);
            setState(() {});
          }, child: const Text('断开')),
        ],
      ),
    );
  }

  Future<void> _directConnect() async {
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '22');
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<DirectConnectInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('直连主机'),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: ipCtrl,
                decoration: const InputDecoration(labelText: 'IP 地址', prefixIcon: Icon(Icons.computer), hintText: '192.168.1.100'),
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
                decoration: const InputDecoration(labelText: '端口', prefixIcon: Icon(Icons.numbers)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock)),
                obscureText: true,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(ctx, DirectConnectInfo(
              ip: ipCtrl.text.trim(),
              port: int.tryParse(portCtrl.text.trim()) ?? 22,
              username: userCtrl.text.trim(),
              password: passCtrl.text,
            ));
          }, child: const Text('连接')),
        ],
      ),
    );

    if (result == null || !mounted) return;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final connInfo = SshConnectionInfo(
      host: result.ip, port: result.port,
      username: result.username, password: result.password,
    );
    final ok = await ref.read(sshConnectionProvider.notifier).connect(connInfo);

    if (!mounted) return;
    Navigator.pop(context);

    if (ok) {
      if (!mounted) return;
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatPage(directConnectInfo: result)));
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('连接失败'),
          content: Text(ref.read(sshConnectionProvider.notifier).errorMessage ?? '未知错误'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
        ),
      );
    }
  }

  void _showAddFavoriteDialog() {
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '22');
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加收藏主机'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: '备注名称', prefixIcon: Icon(Icons.label))),
              const SizedBox(height: 8),
              TextFormField(
                controller: ipCtrl,
                decoration: const InputDecoration(labelText: 'IP 地址', prefixIcon: Icon(Icons.computer)),
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
              TextFormField(controller: portCtrl, decoration: const InputDecoration(labelText: '端口', prefixIcon: Icon(Icons.numbers)), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextFormField(controller: userCtrl, decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person)), validator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null),
              const SizedBox(height: 8),
              TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock)), obscureText: true),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final hostDao = await ref.read(hostDaoProvider.future);
            final now = DateTime.now();
            hostDao.insertHost(Host(
              hostId: ipCtrl.text.trim(),
              displayName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : ipCtrl.text.trim(),
              currentIp: ipCtrl.text.trim(),
              port: int.tryParse(portCtrl.text.trim()) ?? 22,
              username: userCtrl.text.trim(),
              password: passCtrl.text,
              hostKeyFingerprint: ipCtrl.text.trim(),
              firstSeenAt: now, lastSeenAt: now,
            ));
            Navigator.pop(ctx);
            _loadHosts();
          }, child: const Text('保存')),
        ],
      ),
    );
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
            ? _buildEmptyState(theme)
            : _buildHostList(theme),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add',
        onPressed: _showAddFavoriteDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
      Center(child: Column(children: [
        Icon(Icons.dns_outlined, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text('还没有收藏的主机', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
        const SizedBox(height: 24),
      ])),
      _buildActionButtons(theme),
    ]);
  }

  Widget _buildHostList(ThemeData theme) {
    ref.watch(sshConnectionProvider); // rebuild on connection changes
    return Column(children: [
      _buildActionButtons(theme),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
          itemCount: _hosts.length,
          itemBuilder: (context, index) {
            final host = _hosts[index];
            final activeConn = ref.read(sshConnectionProvider.notifier).activeConnection;
            final connected = activeConn != null &&
                activeConn.host == host.currentIp &&
                activeConn.port == host.port;
            return _HostCard(
              host: host,
              connected: connected,
              onTap: () => _connectAndNavigate(host),
              onLongPress: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => HostDetailPage(host: host))),
              onDisconnect: connected ? () => _disconnectHost(host) : null,
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScanPage())).then((_) => _loadHosts()),
            icon: const Icon(Icons.wifi_find), label: const Text('扫描'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _directConnect,
            icon: const Icon(Icons.flash_on), label: const Text('直连'),
          ),
        ),
      ]),
    );
  }
}

class _HostCard extends StatelessWidget {
  final Host host;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDisconnect;

  const _HostCard({
    required this.host, required this.connected,
    required this.onTap, required this.onLongPress, this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: connected
              ? Colors.green.withValues(alpha: 0.2)
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            connected ? Icons.check_circle : Icons.dns,
            color: connected ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(host.displayName.isNotEmpty ? host.displayName : host.currentIp),
        subtitle: Text('${host.username}@${host.currentIp}:${host.port}',
            style: theme.textTheme.bodySmall),
        trailing: GestureDetector(
          onTap: connected ? onDisconnect : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: connected
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: connected ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  connected ? '已连接' : '未连接',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: connected ? Colors.green[700] : Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
