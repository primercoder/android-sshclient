enum SshAuthMethod { password, publicKey, keyboardInteractive }

class SshConnectionInfo {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKeyPath;
  final String? privateKeyContent;
  final SshAuthMethod authMethod;

  const SshConnectionInfo({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKeyPath,
    this.privateKeyContent,
    this.authMethod = SshAuthMethod.password,
  });
}
