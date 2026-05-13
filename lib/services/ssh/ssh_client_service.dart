import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_client/data/models/ssh_connection_info.dart';

class SshClientService {
  SSHClient? _client;
  SSHSession? _shellSession;
  StreamController<String>? _outputController;
  StreamSubscription<String>? _outputSubscription;
  Timer? _keepaliveTimer;
  SshConnectionInfo? _connectionInfo;

  SSHClient? get client => _client;
  SSHSession? get shellSession => _shellSession;
  Stream<String>? get outputStream => _outputController?.stream;
  SshConnectionInfo? get connectionInfo => _connectionInfo;

  String _fingerprintToString(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  Future<void> connect(SshConnectionInfo info, {
    void Function(String type, String fingerprint)? onHostKeyConfirm,
  }) async {
    _connectionInfo = info;

    try {
      final socket = await SSHSocket.connect(info.host, info.port,
          timeout: const Duration(seconds: 10));

      _client = SSHClient(
        socket,
        username: info.username,
        onPasswordRequest: () => info.password,
        onVerifyHostKey: (type, fingerprint) {
          final fp = _fingerprintToString(fingerprint);
          onHostKeyConfirm?.call(type, fp);
          return true;
        },
      );

      await _client!.authenticated;

      _shellSession = await _client!.shell(
        pty: const SSHPtyConfig(),
      );

      _outputController = StreamController<String>.broadcast();
      _outputSubscription = _shellSession!.stdout
          .transform(utf8.decoder as StreamTransformer<Uint8List, String>)
          .listen((data) {
        _outputController?.add(data);
      });

      _startKeepalive();
    } catch (e) {
      rethrow;
    }
  }

  Future<String> executeCommand(String command) async {
    if (_client == null) throw Exception('Not connected');

    final session = await _client!.execute(command, pty: const SSHPtyConfig());
    final output = await session.stdout.transform(utf8.decoder as StreamTransformer<Uint8List, String>).join();
    await session.done;
    return output;
  }

  void sendShellCommand(String command) {
    if (_shellSession == null) throw Exception('Shell session not open');
    _shellSession!.stdin.add(Uint8List.fromList(utf8.encode('$command\n')));
  }

  void _startKeepalive() {
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        _shellSession?.resizeTerminal(80, 24);
      } catch (_) {}
    });
  }

  Future<void> disconnect() async {
    _keepaliveTimer?.cancel();
    await _outputSubscription?.cancel();
    await _outputController?.close();
    _shellSession?.close();
    _client?.close();
  }

  void dispose() {
    disconnect();
  }
}
