import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_client/data/models/ssh_connection_info.dart';

class SshClientService {
  SSHClient? _client;
  SshConnectionInfo? _connectionInfo;

  SSHClient? get client => _client;
  SshConnectionInfo? get connectionInfo => _connectionInfo;
  bool get isConnected => _client != null;

  Future<void> connect(SshConnectionInfo info) async {
    await disconnect();
    _connectionInfo = info;

    final socket = await SSHSocket.connect(
      info.host, info.port,
      timeout: const Duration(seconds: 10),
    );

    _client = SSHClient(
      socket,
      username: info.username,
      onPasswordRequest: () => info.password,
      onVerifyHostKey: (type, fingerprint) => true,
    );

    await _client!.authenticated;
  }

  /// Execute a command and return stdout as a string.
  Future<String> execute(String command) async {
    if (_client == null) throw Exception('SSH not connected');

    final session = await _client!.execute(
      command,
      pty: const SSHPtyConfig(width: 160),
    );

    final output = await utf8.decodeStream(session.stdout);
    await session.done;
    return output;
  }

  /// Execute pwd to get the current working directory on the remote host.
  Future<String> getHomeDirectory() async {
    final output = await execute('echo ~');
    return output.trim();
  }

  Future<void> disconnect() async {
    if (_client != null) {
      try { _client!.close(); } catch (_) {}
      _client = null;
      _connectionInfo = null;
    }
  }
}
