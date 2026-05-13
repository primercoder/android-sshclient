import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

  Future<String> execute(String command) async {
    if (_client == null) throw Exception('SSH not connected');

    final session = await _client!.execute(
      command,
      pty: const SSHPtyConfig(width: 160),
    );

    final output = await session.stdout
        .transform(utf8.decoder as StreamTransformer<Uint8List, String>)
        .join();

    await session.done;
    return output;
  }

  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _connectionInfo = null;
  }
}
