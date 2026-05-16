import 'package:ssh_client/data/models/ssh_connection_info.dart';

class DirectConnectInfo {
  final String ip;
  final int port;
  final String username;
  final String? password;
  final SshAuthMethod authMethod;
  final String? privateKeyContent;
  final String? publicKeyContent;

  const DirectConnectInfo({
    required this.ip,
    required this.port,
    required this.username,
    this.password,
    this.authMethod = SshAuthMethod.password,
    this.privateKeyContent,
    this.publicKeyContent,
  });
}
