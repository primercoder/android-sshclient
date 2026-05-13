import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/providers/ssh_connection_provider.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/direct_connect_info.dart';
import 'package:ssh_client/data/models/ssh_connection_info.dart';
import 'package:ssh_client/data/models/scan_result.dart';
import 'package:ssh_client/ui/pages/chat_page.dart';
import 'package:ssh_client/ui/pages/history_page.dart';
import 'package:ssh_client/ui/pages/settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<Host> _hosts = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late TextEditingController _cidrCtrl;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _cidrCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHosts();
      _detectNetwork();
    });
  }

  Future<void> _loadHosts() async {
    final dao = await ref.read(hostDaoProvider.future);
    final hosts = dao.getAllHosts();
    setState(() => _hosts = hosts);
  }

  void _detectNetwork() async {
    final scanner = ref.read(lanScannerProvider);
    final (cidr, _, _) = await scanner.detectCurrentNetwork();
    _cidrCtrl.text = cidr;
  }

  Future<void> _startScan() async {
    final cidr = _cidrCtrl.text.trim();
    final scanner = ref.read(lanScannerProvider);

    if (!scanner.isValidCidr(cidr)) {
      setState(() => _scanError = '格式错误，示例: 192.168.1.1/24');
      return;
    }
    setState(() { _scanError = null; _isScanning = true; _scanResults = []; });

    try {
      final results = await scanner.scan(cidr: cidr);
      if (mounted) setState(() => _scanResults = results);
    } catch (e) {
      if (mounted) setState(() => _scanError = '扫描出错: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  bool _isHostConnected(Host host) {
    final conn = ref.read(sshConnectionProvider.notifier).activeConnection;
    return conn != null && conn.host == host.currentIp && conn.port == host.port;
  }

  bool _isIpConnected(String ip, int port) {
    final conn = ref.read(sshConnectionProvider.notifier).activeConnection;
    return conn != null && conn.host == ip && conn.port == port;
  }

  Future<void> _connectToHost({Host? host, String? ip, int port = 22, String? username, String? password}) async {
    final notifier = ref.read(sshConnectionProvider.notifier);

    final connInfo = SshConnectionInfo(
      host: ip ?? host!.currentIp,
      port: host?.port ?? port,
      username: username ?? host?.username ?? 'root',
      password: password ?? host?.password ?? '',
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
        MaterialPageRoute(builder: (_) => ChatPage(
          host: host,
          directConnectInfo: host == null ? DirectConnectInfo(
            ip: connInfo.host, port: connInfo.port,
            username: connInfo.username, password: connInfo.password ?? '',
          ) : null,
        )),
      );
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

  void _disconnectHost() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('断开连接'),
        content: const Text('确定断开当前 SSH 连接？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            ref.read(sshConnectionProvider.notifier).disconnect();
            Navigator.pop(ctx);
          }, child: const Text('断开')),
        ],
      ),
    );
  }

  void _showEditDialog(Host host) {
    final nameCtrl = TextEditingController(text: host.displayName);
    final ipCtrl = TextEditingController(text: host.currentIp);
    final portCtrl = TextEditingController(text: host.port.toString());
    final userCtrl = TextEditingController(text: host.username);
    final passCtrl = TextEditingController(text: host.password);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑主机'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: '标记名', prefixIcon: Icon(Icons.label))),
              const SizedBox(height: 8),
              TextFormField(
                controller: ipCtrl,
                decoration: const InputDecoration(labelText: 'IP 地址', prefixIcon: Icon(Icons.computer)),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入 IP';
                  final parts = v.trim().split('.');
                  if (parts.length != 4) return 'IP 格式错误';
                  for (final p in parts) { final n = int.tryParse(p); if (n == null || n < 0 || n > 255) return 'IP 格式错误'; }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(controller: portCtrl, decoration: const InputDecoration(labelText: '端口', prefixIcon: Icon(Icons.numbers)), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextFormField(controller: userCtrl, decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 8),
              TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock)), obscureText: true),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final dao = await ref.read(hostDaoProvider.future);
            dao.insertHost(Host(
              hostId: host.hostId,
              displayName: nameCtrl.text.trim(),
              currentIp: ipCtrl.text.trim(),
              port: int.tryParse(portCtrl.text.trim()) ?? 22,
              username: userCtrl.text.trim(),
              password: passCtrl.text,
              hostKeyFingerprint: host.hostKeyFingerprint,
              firstSeenAt: host.firstSeenAt,
              lastSeenAt: DateTime.now(),
              connectionCount: host.connectionCount,
            ));
            Navigator.pop(ctx);
            _loadHosts();
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  void _confirmDelete(Host host) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除主机'),
        content: Text('确定删除 "${host.displayName}"？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            final dao = await ref.read(hostDaoProvider.future);
            dao.deleteHost(host.hostId);
            Navigator.pop(ctx);
            _loadHosts();
          }, child: const Text('删除'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
  }

  void _showScanCredentialDialog(ScanResult scanResult) {
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: scanResult.ip);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('连接 ${scanResult.ip}:${scanResult.port}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: '标记名', prefixIcon: Icon(Icons.label))),
              const SizedBox(height: 8),
              TextFormField(controller: userCtrl, decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 8),
              TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock)), obscureText: true),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            Navigator.pop(ctx);
            _connectToHost(
              ip: scanResult.ip, port: scanResult.port,
              username: userCtrl.text.trim(), password: passCtrl.text,
            );
          }, child: const Text('连接')),
        ],
      ),
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
    ref.watch(sshConnectionProvider);

    final activeConn = ref.read(sshConnectionProvider.notifier).activeConnection;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Client'),
        actions: [
          if (activeConn != null)
            GestureDetector(
              onTap: _disconnectHost,
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('已连接: ${activeConn.host}', style: TextStyle(fontSize: 11, color: Colors.green[700])),
                ]),
              ),
            ),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          children: [
            // --- Action buttons ---
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryPage())),
                  icon: const Icon(Icons.history), label: const Text('历史'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showDirectConnectDialog(),
                  icon: const Icon(Icons.flash_on), label: const Text('直连'),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // --- Saved hosts section ---
            if (_hosts.isNotEmpty) ...[
              Text('已添加的主机', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 4),
              ..._hosts.map((host) => _HostCard(
                host: host,
                connected: _isHostConnected(host),
                onTap: () => _connectToHost(host: host),
                onEdit: () => _showEditDialog(host),
                onDelete: () => _confirmDelete(host),
                onDisconnect: _isHostConnected(host) ? _disconnectHost : null,
              )),
              const SizedBox(height: 12),
            ],

            // --- Scan section ---
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                title: const Text('局域网扫描'),
                leading: const Icon(Icons.wifi_find),
                initiallyExpanded: _hosts.isEmpty,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _cidrCtrl,
                            decoration: InputDecoration(
                              labelText: 'CIDR',
                              hintText: '192.168.1.1/24',
                              isDense: true,
                              errorText: _scanError,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) { if (_scanError != null) setState(() => _scanError = null); },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _isScanning ? null : _startScan,
                          child: Text(_isScanning ? '...' : '扫描'),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      if (_isScanning) const LinearProgressIndicator(),
                      if (_scanResults.isEmpty && !_isScanning)
                        Text('输入 CIDR 点击扫描', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))
                      else
                        ..._scanResults.map((r) => _ScanResultCard(
                          result: r,
                          connected: _isIpConnected(r.ip, r.port),
                          onConnect: () => _showScanCredentialDialog(r),
                          onDisconnect: _isIpConnected(r.ip, r.port) ? _disconnectHost : null,
                        )),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: '标记名', prefixIcon: Icon(Icons.label))),
              const SizedBox(height: 8),
              TextFormField(
                controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP 地址', prefixIcon: Icon(Icons.computer)),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入 IP';
                  final parts = v.trim().split('.');
                  if (parts.length != 4) return 'IP 格式错误';
                  for (final p in parts) { final n = int.tryParse(p); if (n == null || n < 0 || n > 255) return 'IP 格式错误'; }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(controller: portCtrl, decoration: const InputDecoration(labelText: '端口', prefixIcon: Icon(Icons.numbers)), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextFormField(controller: userCtrl, decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 8),
              TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock)), obscureText: true),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final dao = await ref.read(hostDaoProvider.future);
            final now = DateTime.now();
            dao.insertHost(Host(
              hostId: ipCtrl.text.trim(),
              displayName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : ipCtrl.text.trim(),
              currentIp: ipCtrl.text.trim(),
              port: int.tryParse(portCtrl.text.trim()) ?? 22,
              username: userCtrl.text.trim(), password: passCtrl.text,
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

  void _showDirectConnectDialog() {
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '22');
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('直连主机'),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP 地址', prefixIcon: Icon(Icons.computer)),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入 IP';
                  final parts = v.trim().split('.');
                  if (parts.length != 4) return 'IP 格式错误';
                  for (final p in parts) { final n = int.tryParse(p); if (n == null || n < 0 || n > 255) return 'IP 格式错误'; }
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
            final ip = ipCtrl.text.trim();
            final port = int.tryParse(portCtrl.text.trim()) ?? 22;
            final user = userCtrl.text.trim();
            final pass = passCtrl.text;

            // Add to favorites automatically
            final dao = await ref.read(hostDaoProvider.future);
            final now = DateTime.now();
            dao.insertHost(Host(
              hostId: ip,
              displayName: ip,
              currentIp: ip, port: port,
              username: user, password: pass,
              hostKeyFingerprint: ip,
              firstSeenAt: now, lastSeenAt: now,
            ));
            await _loadHosts();

            Navigator.pop(ctx);
            _connectToHost(ip: ip, port: port, username: user, password: pass);
          }, child: const Text('连接')),
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  final Host host;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onDisconnect;

  const _HostCard({
    required this.host, required this.connected,
    required this.onTap, required this.onEdit, required this.onDelete, this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: connected ? Colors.green.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.dns, size: 18, color: connected ? Colors.green : Colors.grey),
        ),
        title: Text(host.displayName.isNotEmpty ? host.displayName : host.currentIp,
            style: const TextStyle(fontSize: 14)),
        subtitle: Text('${host.username}@${host.currentIp}:${host.port}',
            style: theme.textTheme.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: connected ? onDisconnect : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: connected ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  connected ? '已连接' : '未连接',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: connected ? Colors.green[700] : Colors.grey[600]),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text('编辑'), dense: true)),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Colors.red), title: Text('删除', style: TextStyle(color: Colors.red)), dense: true)),
              ],
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  final ScanResult result;
  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;

  const _ScanResultCard({
    required this.result, required this.connected,
    required this.onConnect, this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(top: 6),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: connected ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15),
          child: Icon(Icons.wifi_find, size: 16, color: connected ? Colors.green : Colors.grey[600]),
        ),
        title: Text('${result.ip}:${result.port}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        subtitle: result.sshBanner != null
            ? Text(result.sshBanner!, style: TextStyle(fontSize: 10, color: Colors.grey[500]))
            : Text('${result.responseTimeMs}ms', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        trailing: connected
            ? GestureDetector(
                onTap: onDisconnect,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('已连接', style: TextStyle(fontSize: 10, color: Colors.green[700])),
                ),
              )
            : FilledButton.tonal(
                onPressed: onConnect,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                child: const Text('连接', style: TextStyle(fontSize: 11)),
              ),
      ),
    );
  }
}
