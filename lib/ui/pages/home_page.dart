import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ssh_client/services/network/lan_scanner.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/providers/chat_provider.dart';
import 'package:ssh_client/providers/ssh_connection_provider.dart';
import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/models/direct_connect_info.dart';
import 'package:ssh_client/data/models/ssh_connection_info.dart';
import 'package:ssh_client/data/models/scan_result.dart';
import 'package:ssh_client/ui/pages/chat_page.dart';
import 'package:ssh_client/ui/pages/history_page.dart';
import 'package:ssh_client/ui/pages/settings_page.dart';
import 'package:ssh_client/services/crypto/key_service.dart';

enum ScanState { idle, scanning, paused }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<Host> _hosts = [];
  List<ScanResult> _scanResults = [];
  ScanState _scanState = ScanState.idle;
  int _totalIps = 0;
  int _scannedIps = 0;
  bool _showScanSettings = true;
  late TextEditingController _cidrCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _timeoutCtrl;
  final FocusNode _cidrFocus = FocusNode();
  String? _scanError;
  ScanAbort? _scanAbort;

  @override
  void initState() {
    super.initState();
    _cidrCtrl = TextEditingController();
    _portCtrl = TextEditingController(text: '22');
    _timeoutCtrl = TextEditingController(text: '1000');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHosts();
      _detectNetwork();
    });
  }

  Future<void> _loadHosts() async {
    final dao = await ref.read(hostDaoProvider.future);
    setState(() => _hosts = dao.getAllHosts());
  }

  void _detectNetwork() async {
    final scanner = ref.read(lanScannerProvider);
    final cidr = await scanner.detectCurrentCidr();
    _cidrCtrl.text = cidr;
  }

  Future<void> _startScan() async {
    final cidr = _cidrCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 22;
    final timeoutMs = int.tryParse(_timeoutCtrl.text.trim()) ?? 1000;
    final scanner = ref.read(lanScannerProvider);

    if (!scanner.isValidCidr(cidr)) {
      setState(() => _scanError = '格式错误，示例: 192.168.1.1/24');
      return;
    }

    final totalIps = scanner.estimatedHostCount(cidr);
    _scanAbort = ScanAbort();
    setState(() {
      _scanError = null;
      _scanState = ScanState.scanning;
      _scanResults = [];
      _totalIps = totalIps;
      _scannedIps = 0;
    });

    try {
      final results = await scanner.scan(
        cidr: cidr,
        port: port,
        timeoutMs: timeoutMs,
        onResult: (r) {
          if (mounted) setState(() => _scanResults.add(r));
        },
        onProgress: (scanned, total) {
          if (mounted) setState(() => _scannedIps = scanned);
        },
        abort: _scanAbort,
      );
      if (mounted && _scanAbort?.isStopped != true) {
        setState(() { _scanResults = results; _scanState = ScanState.idle; });
      }
    } catch (e) {
      if (mounted) setState(() => _scanError = '扫描出错: $e');
    } finally {
      if (mounted && _scanState != ScanState.paused) {
        setState(() => _scanState = ScanState.idle);
      }
      if (_scanAbort?.isStopped == true) _scanAbort = null;
    }
  }

  void _pauseScan() { _scanAbort?.pause(); setState(() => _scanState = ScanState.paused); }
  void _resumeScan() { _scanAbort?.resume(); setState(() => _scanState = ScanState.scanning); }
  void _stopScan() { _scanAbort?.stop(); setState(() { _scanState = ScanState.idle; _scannedIps = 0; }); }

  bool _isHostConnected(Host host) {
    final conn = ref.read(sshConnectionProvider.notifier).activeConnection;
    return conn != null && conn.host == host.currentIp && conn.port == host.port;
  }

  Future<void> _connectToHost({Host? host, String? ip, int port = 22, String? username, String? password, SshAuthMethod authMethod = SshAuthMethod.password, String? privateKeyContent, String? publicKeyContent}) async {
    final notifier = ref.read(sshConnectionProvider.notifier);
    final connState = ref.read(sshConnectionProvider);

    final connInfo = SshConnectionInfo(
      host: ip ?? host!.currentIp,
      port: host?.port ?? port,
      username: username ?? host?.username ?? 'root',
      password: password ?? host?.password ?? '',
      authMethod: host?.authMethod ?? authMethod,
      privateKeyContent: privateKeyContent ?? host?.privateKeyContent,
    );

    if (connState == SshConnectionState.connected &&
        notifier.activeConnection != null &&
        notifier.activeConnection!.host == connInfo.host &&
        notifier.activeConnection!.port == connInfo.port &&
        notifier.activeConnection!.username == connInfo.username &&
        notifier.activeConnection!.authMethod == connInfo.authMethod) {
      if (!mounted) return;
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatPage(
          host: host,
          directConnectInfo: host == null ? DirectConnectInfo(
            ip: connInfo.host, port: connInfo.port,
            username: connInfo.username, password: connInfo.password ?? '',
            authMethod: connInfo.authMethod,
            privateKeyContent: connInfo.privateKeyContent,
            publicKeyContent: publicKeyContent,
          ) : null,
        )),
      );
      return;
    }

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
            authMethod: connInfo.authMethod,
            privateKeyContent: connInfo.privateKeyContent,
            publicKeyContent: publicKeyContent,
          ) : null,
        )),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('断开连接'),
        content: const Text('确定断开当前 SSH 连接？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            final chatNotifier = ref.read(chatProvider.notifier);
            for (final hid in chatNotifier.activeHostIds) {
              chatNotifier.endSession(hid);
            }
            ref.read(sshConnectionProvider.notifier).disconnect();
            Navigator.pop(ctx);
            setState(() {});
          }, child: const Text('断开')),
        ],
      ),
    );
  }

  void _quickAddHost(ScanResult r) async {
    final dao = await ref.read(hostDaoProvider.future);
    final now = DateTime.now();
    dao.insertHost(Host(
      hostId: const Uuid().v4(),
      displayName: r.ip,
      currentIp: r.ip,
      port: r.port,
      username: 'root',
      hostKeyFingerprint: r.ip,
      firstSeenAt: now, lastSeenAt: now,
    ));
    _loadHosts();
  }

  Future<String> _getKeysDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/keys';
  }

  Widget _buildKeySection(void Function(void Function()) setSheetState, {
    required String? privateKeyPath,
    required String? publicKeyPath,
    required String? privateKeyContent,
    required String? publicKeyContent,
    required String hostId,
    required ValueChanged<String?> onPrivateKeyPath,
    required ValueChanged<String?> onPublicKeyPath,
    required ValueChanged<String?> onPrivateKeyContent,
    required ValueChanged<String?> onPublicKeyContent,
    required VoidCallback onRefresh,
    bool showUpload = false,
    String? hostIp,
    int hostPort = 22,
    String? username,
    String? password,
  }) {
    final keysConfirmed = privateKeyContent != null && publicKeyContent != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _keyFileRow(
        label: '私钥', path: privateKeyPath, hasContent: privateKeyContent != null,
        onImport: () => _importKeyFile(hostId, 'priv', onPrivateKeyPath, onPrivateKeyContent, onPublicKeyContent),
        onView: () => _showKeyContentDialog('私钥内容', privateKeyContent ?? '', canCopy: false),
        onDelete: () {
          onPrivateKeyPath(null);
          onPrivateKeyContent(null);
          onPublicKeyPath(null);
          onPublicKeyContent(null);
        },
      ),
      const SizedBox(height: 4),
      _keyFileRow(
        label: '公钥', path: publicKeyPath, hasContent: publicKeyContent != null,
        onImport: () => _importKeyFile(hostId, 'pub', onPublicKeyPath, onPublicKeyContent, null),
        onView: () => _showKeyContentDialog('公钥内容', publicKeyContent ?? '', canCopy: true, canExport: true, exportPath: publicKeyPath),
        onDelete: () {
          onPublicKeyPath(null);
          onPublicKeyContent(null);
        },
      ),
      const SizedBox(height: 6),
      TextButton.icon(
        onPressed: () async {
          final keysDir = await _getKeysDir();
          final shortId = KeyService.shortName(hostId);
          if (!mounted) return;
          if (File('$keysDir/$shortId.priv').existsSync() ||
              File('$keysDir/$shortId.pub').existsSync()) {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('密钥已存在'),
                content: const Text('该主机已有密钥对，是否覆盖？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('覆盖')),
                ],
              ),
            );
            if (ok != true) return;
          }
          final comment = '${username ?? 'root'}@${hostIp ?? 'host'}';
          final generated = await KeyService.generateKeyPair(
            hostId: hostId, comment: comment, keysDir: keysDir,
          );
          onPrivateKeyPath(generated.privateKeyPath);
          onPublicKeyPath(generated.publicKeyPath);
          onPrivateKeyContent(generated.privateKeyContent);
          onPublicKeyContent(generated.publicKeyContent);
          onRefresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ed25519 密钥对已生成')),
            );
          }
        },
        icon: const Icon(Icons.vpn_key, size: 18),
        label: const Text('生成密钥对'),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
      if (showUpload && hostIp != null)
        TextButton.icon(
          onPressed: keysConfirmed ? () => _uploadPublicKey(
            hostIp: hostIp, hostPort: hostPort,
            username: username ?? 'root',
            publicKeyContent: publicKeyContent,
            prefillPassword: password,
          ) : null,
          icon: const Icon(Icons.cloud_upload, size: 18),
          label: Text('上传公钥到主机',
              style: TextStyle(color: keysConfirmed ? null : Colors.grey)),
        ),
    ]);
  }

  Widget _keyFileRow({
    required String label,
    required String? path,
    required bool hasContent,
    required VoidCallback onImport,
    required VoidCallback onView,
    VoidCallback? onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(children: [
        Icon(hasContent ? Icons.check_circle : Icons.circle_outlined,
            size: 14, color: hasContent ? Colors.green : Colors.grey),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12)),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              path != null ? path.split('/').last : '未选择',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace',
                  color: hasContent ? null : Colors.grey),
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onSelected: (v) {
            if (v == 'import') onImport();
            if (v == 'view') onView();
            if (v == 'delete' && onDelete != null) onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'import',
                child: ListTile(leading: Icon(Icons.file_download, size: 16), title: Text('导入', style: TextStyle(fontSize: 13)), dense: true)),
            PopupMenuItem(
              value: 'view',
              enabled: hasContent,
              child: ListTile(leading: Icon(Icons.visibility, size: 16), title: Text('查看', style: TextStyle(fontSize: 13)), dense: true),
            ),
            if (onDelete != null)
              const PopupMenuItem(value: 'delete',
                  child: ListTile(leading: Icon(Icons.delete, size: 16), title: Text('删除', style: TextStyle(fontSize: 13)), dense: true)),
          ],
        ),
      ]),
    );
  }

  Future<void> _importKeyFile(String hostId, String suffix,
      ValueChanged<String?> onPath, ValueChanged<String?> onContent,
      ValueChanged<String?>? onOtherContent) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final srcPath = result.files.first.path;
    if (srcPath == null) return;

    final keysDir = await _getKeysDir();
    final shortId = KeyService.shortName(hostId);
    final fileName = '$shortId.$suffix';
    final dest = await KeyService.importKeyFile(srcPath, keysDir, fileName);
    if (dest != null) {
      final content = await KeyService.readKeyFile(dest);
      if (content == null) return;
      if (suffix == 'priv' && !KeyService.isValidPrivateKey(content)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无效的私钥文件格式')));
        }
        return;
      }
      onPath(dest);
      onContent(content);
      if (suffix == 'priv' && onOtherContent != null) {
        final pubLine = KeyService.extractPublicKeyLine(content, 'imported');
        if (pubLine != null) onOtherContent(pubLine);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件已复制到内部目录，您可以安全删除外部源文件')));
      }
    }
  }

  void _showKeyContentDialog(String title, String content, {bool canCopy = false, bool canExport = false, String? exportPath}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(content, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
        actions: [
          if (canCopy)
            TextButton(onPressed: () {
              // Copy to clipboard using Flutter's Clipboard
            }, child: const Text('复制')),
          if (canExport && exportPath != null)
            TextButton(onPressed: () async {
              final outDir = await FilePicker.platform.getDirectoryPath();
              if (outDir != null) {
                final ok = await KeyService.exportPublicKey(exportPath, '$outDir/${exportPath.split('/').last}');
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(ok ? '公钥已导出到 $outDir' : '导出失败')),
                  );
                }
              }
            }, child: const Text('导出')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _uploadPublicKey({required String hostIp, required int hostPort, required String username, required String publicKeyContent, String? prefillPassword}) {
    final passCtrl = TextEditingController(text: prefillPassword ?? '');
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('上传公钥'),
          content: TextField(
            controller: passCtrl,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: '密码 (用于 SSH 连接上传公钥)',
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setDialogState(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () async {
              final sshService = ref.read(sshClientServiceProvider);
              Navigator.pop(ctx);
              try {
                showDialog(context: context, barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()));
                await sshService.uploadPublicKey(
                  passwordInfo: SshConnectionInfo(
                    host: hostIp, port: hostPort,
                    username: username, password: passCtrl.text,
                    authMethod: SshAuthMethod.password,
                  ),
                  publicKeyLine: publicKeyContent,
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('公钥已上传到主机')),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('上传失败: $e')),
                );
              }
            }, child: const Text('上传')),
          ],
        ),
      ),
    );
  }

  Widget _buildCommonFields({
    required TextEditingController nameCtrl,
    required TextEditingController ipCtrl,
    required TextEditingController portCtrl,
    required TextEditingController userCtrl,
    String? Function(String?)? ipValidator,
    String? Function(String?)? userValidator,
  }) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: '标记名', prefixIcon: Icon(Icons.label), isDense: false)),
      const SizedBox(height: 8),
      TextFormField(
        controller: ipCtrl,
        decoration: const InputDecoration(labelText: 'IP 地址', prefixIcon: Icon(Icons.computer), isDense: false),
        validator: ipValidator ?? (v) {
          if (v == null || v.isEmpty) return '请输入 IP';
          final parts = v.trim().split('.');
          if (parts.length != 4) return 'IP 格式错误';
          for (final p in parts) { final n = int.tryParse(p); if (n == null || n < 0 || n > 255) return 'IP 格式错误'; }
          return null;
        },
      ),
      const SizedBox(height: 8),
      TextFormField(controller: portCtrl, decoration: const InputDecoration(labelText: '端口', prefixIcon: Icon(Icons.numbers), isDense: false), keyboardType: TextInputType.number),
      const SizedBox(height: 8),
      TextFormField(controller: userCtrl, decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person), isDense: false), validator: userValidator),
    ]);
  }

  void _showEditDialog(Host host) {
    final nameCtrl = TextEditingController(text: host.displayName);
    final ipCtrl = TextEditingController(text: host.currentIp);
    final portCtrl = TextEditingController(text: host.port.toString());
    final userCtrl = TextEditingController(text: host.username);
    final passCtrl = TextEditingController(text: host.password);
    final formKey = GlobalKey<FormState>();
    var authMethod = host.authMethod;
    var obscurePass = true;
    var privateKeyPath = host.privateKeyPath;
    var publicKeyPath = host.publicKeyPath;
    var privateKeyContent = host.privateKeyContent;
    var publicKeyContent = host.publicKeyContent;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑主机'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                _buildCommonFields(nameCtrl: nameCtrl, ipCtrl: ipCtrl, portCtrl: portCtrl, userCtrl: userCtrl),
                const SizedBox(height: 8),
                DropdownButtonFormField<SshAuthMethod>(
                  initialValue: authMethod,
                  decoration: const InputDecoration(labelText: '认证方式', isDense: false, prefixIcon: Icon(Icons.security)),
                  items: const [
                    DropdownMenuItem(value: SshAuthMethod.password, child: Text('密码认证')),
                    DropdownMenuItem(value: SshAuthMethod.publicKey, child: Text('公钥认证')),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => authMethod = v); },
                ),
                if (authMethod == SshAuthMethod.password) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                ],
                if (authMethod == SshAuthMethod.publicKey) ...[
                  const SizedBox(height: 8),
                  _buildKeySection(setDialogState,
                    privateKeyPath: privateKeyPath,
                    publicKeyPath: publicKeyPath,
                    privateKeyContent: privateKeyContent,
                    publicKeyContent: publicKeyContent,
                    hostId: host.hostId,
                    onPrivateKeyPath: (v) => setDialogState(() => privateKeyPath = v),
                    onPublicKeyPath: (v) => setDialogState(() => publicKeyPath = v),
                    onPrivateKeyContent: (v) => setDialogState(() => privateKeyContent = v),
                    onPublicKeyContent: (v) => setDialogState(() => publicKeyContent = v),
                    onRefresh: () {},
                    showUpload: true,
                    hostIp: ipCtrl.text,
                    hostPort: int.tryParse(portCtrl.text) ?? 22,
                    username: userCtrl.text,
                    password: passCtrl.text,
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (authMethod == SshAuthMethod.password && passCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('密码认证需填写密码')));
                return;
              }
              if (authMethod == SshAuthMethod.publicKey && privateKeyContent == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('公钥认证需选择或生成密钥')));
                return;
              }
              final dao = await ref.read(hostDaoProvider.future);
              dao.insertHost(Host(
                hostId: host.hostId,
                displayName: nameCtrl.text.trim(),
                currentIp: ipCtrl.text.trim(),
                port: int.tryParse(portCtrl.text.trim()) ?? 22,
                username: userCtrl.text.trim(), password: passCtrl.text,
                hostKeyFingerprint: host.hostKeyFingerprint,
                firstSeenAt: host.firstSeenAt, lastSeenAt: DateTime.now(),
                connectionCount: host.connectionCount,
                authMethod: authMethod,
                privateKeyPath: privateKeyPath,
                publicKeyPath: publicKeyPath,
                privateKeyContent: privateKeyContent,
                publicKeyContent: publicKeyContent,
              ));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadHosts();
            }, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Host host) async {
    _cidrFocus.unfocus();
    final hasActive = ref.read(chatProvider.notifier).hasActiveSession(host.hostId);

    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('删除主机'),
        content: Text(hasActive
            ? '主机 "${host.displayName}" 存在活跃会话。'
                '断开连接后历史记录保留不受影响，确定删除？'
            : '确定删除 "${host.displayName}"？\n历史会话记录不受影响。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('取消')),
          if (hasActive)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'force_delete'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('断开并删除'),
            ),
          if (!hasActive)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('删除'),
            ),
        ],
      ),
    );
    if (action == null || action == 'cancel') return;

    final dao = await ref.read(hostDaoProvider.future);

    if (hasActive) {
      ref.read(chatProvider.notifier).endSession(host.hostId);
    }

    final sessDao = await ref.read(sessionDaoProvider.future);
    sessDao.db.execute('PRAGMA foreign_keys = OFF');
    dao.deleteHost(host.hostId);
    sessDao.db.execute('PRAGMA foreign_keys = ON');

    _loadHosts();
  }

  @override
  void dispose() {
    _cidrCtrl.dispose();
    _portCtrl.dispose();
    _timeoutCtrl.dispose();
    _cidrFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(sshConnectionProvider);

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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: RefreshIndicator(
        onRefresh: _loadHosts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          children: [
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _showScanSettings = !_showScanSettings),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.tune, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text('扫描设置',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.primary)),
                                  const Spacer(),
                                  AnimatedRotation(
                                    turns: _showScanSettings ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(Icons.expand_more),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.topCenter,
                          child: _showScanSettings
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _cidrCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'CIDR 子网',
                                        hintText: '192.168.1.1/24',
                                        errorText: _scanError,
                                        isDense: true,
                                      ),
                                      onChanged: (_) {
                                        if (_scanError != null) setState(() => _scanError = null);
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _portCtrl,
                                      decoration: const InputDecoration(
                                        labelText: '扫描端口',
                                        hintText: '22',
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _timeoutCtrl,
                                      decoration: const InputDecoration(
                                        labelText: '响应超时 (ms)',
                                        hintText: '1000',
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                        if (_scanState != ScanState.idle)
                          Row(
                            children: [
                              if (_scanAbort?.isPaused == true)
                                FilledButton.tonalIcon(
                                  onPressed: _resumeScan,
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('继续'),
                                )
                              else
                                FilledButton.tonalIcon(
                                  onPressed: _pauseScan,
                                  icon: const Icon(Icons.pause, size: 18),
                                  label: const Text('暂停'),
                                ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _stopScan,
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                icon: const Icon(Icons.stop, size: 18),
                                label: const Text('停止'),
                              ),
                            ],
                          )
                        else
                          FilledButton.icon(
                            onPressed: _startScan,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('扫描'),
                          ),
                        const SizedBox(height: 8),
                        if (_scanState != ScanState.idle)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Column(children: [
                              if (_scanState == ScanState.scanning)
                                const LinearProgressIndicator()
                              else
                                LinearProgressIndicator(value: _totalIps > 0 ? _scannedIps / _totalIps : 0),
                              const SizedBox(height: 4),
                              Text(
                                _scanState == ScanState.paused
                                    ? '已暂停 ($_scannedIps/$_totalIps)'
                                    : '端口 ${_portCtrl.text} 扫描中 ($_scannedIps/$_totalIps)...',
                                style: TextStyle(fontSize: 11,
                                    color: _scanState == ScanState.paused
                                        ? Colors.grey[400]
                                        : Colors.grey[500]),
                              ),
                            ]),
                          ),
                        if (_scanResults.isEmpty && _scanState == ScanState.idle)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('设置参数后点击扫描', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          )
                        else
                          ..._scanResults.map((r) => _ScanResultCard(
                            result: r,
                            onAdd: () => _quickAddHost(r),
                            onDismiss: () => setState(() => _scanResults.remove(r)),
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
            ],
          ],
        ),
      ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'direct',
            mini: false,
            onPressed: () => _showDirectConnectDialog(),
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: const Icon(Icons.flash_on),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _showAddFavoriteDialog,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _showAddFavoriteDialog() {
    _cidrFocus.unfocus();
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '22');
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var authMethod = SshAuthMethod.password;
    var obscurePass = true;
    var privateKeyPath = null as String?;
    var publicKeyPath = null as String?;
    var privateKeyContent = null as String?;
    var publicKeyContent = null as String?;
    final hostId = const Uuid().v4();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加收藏主机'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                _buildCommonFields(nameCtrl: nameCtrl, ipCtrl: ipCtrl, portCtrl: portCtrl, userCtrl: userCtrl),
                const SizedBox(height: 8),
                DropdownButtonFormField<SshAuthMethod>(
                  initialValue: authMethod,
                  decoration: const InputDecoration(labelText: '认证方式', isDense: false, prefixIcon: Icon(Icons.security)),
                  items: const [
                    DropdownMenuItem(value: SshAuthMethod.password, child: Text('密码认证')),
                    DropdownMenuItem(value: SshAuthMethod.publicKey, child: Text('公钥认证')),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => authMethod = v); },
                ),
                if (authMethod == SshAuthMethod.password) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                ],
                if (authMethod == SshAuthMethod.publicKey) ...[
                  const SizedBox(height: 8),
                  _buildKeySection(setDialogState,
                    privateKeyPath: privateKeyPath,
                    publicKeyPath: publicKeyPath,
                    privateKeyContent: privateKeyContent,
                    publicKeyContent: publicKeyContent,
                    hostId: hostId,
                    onPrivateKeyPath: (v) => setDialogState(() => privateKeyPath = v),
                    onPublicKeyPath: (v) => setDialogState(() => publicKeyPath = v),
                    onPrivateKeyContent: (v) => setDialogState(() => privateKeyContent = v),
                    onPublicKeyContent: (v) => setDialogState(() => publicKeyContent = v),
                    onRefresh: () {},
                    showUpload: true,
                    hostIp: ipCtrl.text,
                    hostPort: int.tryParse(portCtrl.text) ?? 22,
                    username: userCtrl.text,
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (authMethod == SshAuthMethod.password && passCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('密码认证需填写密码')));
                return;
              }
              if (authMethod == SshAuthMethod.publicKey && privateKeyContent == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('公钥认证需选择或生成密钥')));
                return;
              }
              final dao = await ref.read(hostDaoProvider.future);
              final now = DateTime.now();
              dao.insertHost(Host(
                hostId: hostId,
                displayName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : ipCtrl.text.trim(),
                currentIp: ipCtrl.text.trim(),
                port: int.tryParse(portCtrl.text.trim()) ?? 22,
                username: userCtrl.text.trim(), password: passCtrl.text,
                hostKeyFingerprint: ipCtrl.text.trim(),
                firstSeenAt: now, lastSeenAt: now,
                authMethod: authMethod,
                privateKeyPath: privateKeyPath,
                publicKeyPath: publicKeyPath,
                privateKeyContent: privateKeyContent,
                publicKeyContent: publicKeyContent,
              ));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadHosts();
            }, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  void _showDirectConnectDialog() {
    _cidrFocus.unfocus();
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '22');
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var authMethod = SshAuthMethod.password;
    var obscurePass = true;
    var privateKeyPath = null as String?;
    var publicKeyPath = null as String?;
    var privateKeyContent = null as String?;
    var publicKeyContent = null as String?;
    final hostId = const Uuid().v4();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('直连主机'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                _buildCommonFields(
                  nameCtrl: nameCtrl, ipCtrl: ipCtrl, portCtrl: portCtrl, userCtrl: userCtrl,
                  ipValidator: (v) {
                    if (v == null || v.isEmpty) return '请输入 IP';
                    final parts = v.trim().split('.');
                    if (parts.length != 4) return 'IP 格式错误';
                    for (final p in parts) { final n = int.tryParse(p); if (n == null || n < 0 || n > 255) return 'IP 格式错误'; }
                    return null;
                  },
                  userValidator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<SshAuthMethod>(
                  initialValue: authMethod,
                  decoration: const InputDecoration(labelText: '认证方式', isDense: false, prefixIcon: Icon(Icons.security)),
                  items: const [
                    DropdownMenuItem(value: SshAuthMethod.password, child: Text('密码认证')),
                    DropdownMenuItem(value: SshAuthMethod.publicKey, child: Text('公钥认证')),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => authMethod = v); },
                ),
                if (authMethod == SshAuthMethod.password) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                ],
                if (authMethod == SshAuthMethod.publicKey) ...[
                  const SizedBox(height: 8),
                  _buildKeySection(setDialogState,
                    privateKeyPath: privateKeyPath,
                    publicKeyPath: publicKeyPath,
                    privateKeyContent: privateKeyContent,
                    publicKeyContent: publicKeyContent,
                    hostId: hostId,
                    onPrivateKeyPath: (v) => setDialogState(() => privateKeyPath = v),
                    onPublicKeyPath: (v) => setDialogState(() => publicKeyPath = v),
                    onPrivateKeyContent: (v) => setDialogState(() => privateKeyContent = v),
                    onPublicKeyContent: (v) => setDialogState(() => publicKeyContent = v),
                    onRefresh: () {},
                    showUpload: true,
                    hostIp: ipCtrl.text,
                    hostPort: int.tryParse(portCtrl.text) ?? 22,
                    username: userCtrl.text,
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (authMethod == SshAuthMethod.password && passCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('密码认证需填写密码')));
                return;
              }
              if (authMethod == SshAuthMethod.publicKey && privateKeyContent == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('公钥认证需选择或生成密钥')));
                return;
              }
              final ip = ipCtrl.text.trim();
              final port = int.tryParse(portCtrl.text.trim()) ?? 22;
              final user = userCtrl.text.trim();
              final pass = passCtrl.text;

              final dao = await ref.read(hostDaoProvider.future);
              final now = DateTime.now();
              dao.insertHost(Host(
                hostId: hostId,
                displayName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : ip,
                currentIp: ip, port: port,
                username: user, password: pass,
                hostKeyFingerprint: ip,
                firstSeenAt: now, lastSeenAt: now,
                authMethod: authMethod,
                privateKeyPath: privateKeyPath,
                publicKeyPath: publicKeyPath,
                privateKeyContent: privateKeyContent,
                publicKeyContent: publicKeyContent,
              ));
              await _loadHosts();

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _connectToHost(
                host: null, ip: ip, port: port,
                username: user, password: pass,
                authMethod: authMethod,
                privateKeyContent: privateKeyContent,
                publicKeyContent: publicKeyContent,
              );
            }, child: const Text('连接')),
          ],
        ),
      ),
    );
  }
}

// --- Widgets ---

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
        title: Text(host.displayName.isNotEmpty ? host.displayName : host.currentIp, style: const TextStyle(fontSize: 14)),
        subtitle: Text('${host.username}@${host.currentIp}:${host.port}', style: theme.textTheme.bodySmall),
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
                child: Text(connected ? '已连接' : '未连接',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                        color: connected ? Colors.green[700] : Colors.grey[600])),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); },
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
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const _ScanResultCard({required this.result, required this.onAdd, required this.onDismiss});

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
          backgroundColor: Colors.grey.withValues(alpha: 0.15),
          child: Icon(Icons.wifi_find, size: 16, color: Colors.grey[600]),
        ),
        title: Text('${result.ip}:${result.port}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        subtitle: result.sshBanner != null
            ? Text(result.sshBanner!, style: TextStyle(fontSize: 10, color: Colors.grey[500]))
            : Text('${result.responseTimeMs}ms', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonal(
              onPressed: onAdd,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
              child: const Text('添加', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
