import 'package:ssh_client/data/models/host.dart';
import 'package:ssh_client/data/database/dao/host_dao.dart';

enum HostMatchLevel { exactFingerprint, macAddress, ipOnly, unknown }

class HostMatchResult {
  final Host? host;
  final HostMatchLevel level;
  final bool isIpChanged;

  const HostMatchResult({
    this.host,
    required this.level,
    this.isIpChanged = false,
  });
}

class HostIdentifier {
  final HostDao _hostDao;

  HostIdentifier(this._hostDao);

  Future<HostMatchResult> identifyHost({
    required String fingerprint,
    String? macAddress,
    required String currentIp,
    int port = 22,
  }) async {
    final byFingerprint = _hostDao.getHostById(fingerprint);
    if (byFingerprint != null) {
      final ipChanged = byFingerprint.currentIp != currentIp;
      return HostMatchResult(
        host: byFingerprint,
        level: HostMatchLevel.exactFingerprint,
        isIpChanged: ipChanged,
      );
    }

    if (macAddress != null) {
      final allHosts = _hostDao.getAllHosts();
      final byMac = allHosts.where((h) => h.macAddress == macAddress).toList();
      if (byMac.isNotEmpty) {
        return HostMatchResult(
          host: byMac.first,
          level: HostMatchLevel.macAddress,
        );
      }
    }

    final byIp = _hostDao.getHostByIp(currentIp);
    if (byIp != null) {
      return HostMatchResult(
        host: byIp,
        level: HostMatchLevel.ipOnly,
      );
    }

    return HostMatchResult(level: HostMatchLevel.unknown);
  }

  Future<Host> createNewHost({
    required String fingerprint,
    required String currentIp,
    int port = 22,
    String? macAddress,
    String? displayName,
    String? keyAlgorithm,
    String? sshBanner,
  }) async {
    final now = DateTime.now();
    final host = Host(
      hostId: fingerprint,
      displayName: displayName ?? currentIp,
      currentIp: currentIp,
      port: port,
      macAddress: macAddress,
      hostKeyFingerprint: fingerprint,
      hostKeyAlgorithm: keyAlgorithm,
      sshBanner: sshBanner,
      firstSeenAt: now,
      lastSeenAt: now,
      connectionCount: 1,
    );
    _hostDao.insertHost(host);
    return host;
  }
}
