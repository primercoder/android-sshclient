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

    List<SSHKeyPair>? identities;
    if (info.authMethod == SshAuthMethod.publicKey && info.privateKeyContent != null) {
      try {
        identities = SSHKeyPair.fromPem(info.privateKeyContent!);
      } catch (_) {}
    }

    _client = SSHClient(
      socket,
      username: info.username,
      onPasswordRequest: info.authMethod == SshAuthMethod.password
          ? () => info.password ?? ''
          : null,
      identities: identities,
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

    final output = await utf8.decodeStream(session.stdout);
    await session.done;
    return output;
  }

  Future<String> executeCombined(String command) async {
    if (_client == null) throw Exception('SSH not connected');

    final session = await _client!.execute(
      command,
      pty: const SSHPtyConfig(width: 160),
    );

    final results = await Future.wait([
      utf8.decodeStream(session.stdout),
      utf8.decodeStream(session.stderr),
    ]);
    await session.done;

    final out = results[0].trim();
    final err = results[1].trim();
    if (err.isNotEmpty) return '$out\n$err';
    return out;
  }

  Future<String> getHomeDirectory() async {
    final output = await execute('echo ~');
    return output.trim();
  }

  /// Upload a public key to the remote host's authorized_keys using password auth.
  Future<void> uploadPublicKey({
    required SshConnectionInfo passwordInfo,
    required String publicKeyLine,
  }) async {
    await disconnect();

    final socket = await SSHSocket.connect(
      passwordInfo.host, passwordInfo.port,
      timeout: const Duration(seconds: 10),
    );

    _client = SSHClient(
      socket,
      username: passwordInfo.username,
      onPasswordRequest: () => passwordInfo.password ?? '',
      onVerifyHostKey: (type, fingerprint) => true,
    );

    await _client!.authenticated;

    final escapedKey = publicKeyLine.replaceAll("'", "'\\''");
    final cmd = 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && '
        "echo '$escapedKey' >> ~/.ssh/authorized_keys && "
        'chmod 600 ~/.ssh/authorized_keys';

    final session = await _client!.execute(cmd);
    await session.done;

    await disconnect();
  }

  Future<void> disconnect() async {
    if (_client != null) {
      try { _client!.close(); } catch (_) {}
      _client = null;
      _connectionInfo = null;
    }
  }
}
