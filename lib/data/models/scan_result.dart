class ScanResult {
  final String ip;
  final int port;
  final String? macAddress;
  final String? sshBanner;
  final int responseTimeMs;

  const ScanResult({
    required this.ip,
    this.port = 22,
    this.macAddress,
    this.sshBanner,
    this.responseTimeMs = 0,
  });
}
