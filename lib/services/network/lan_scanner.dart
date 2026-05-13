import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ssh_client/data/models/scan_result.dart';

class LanScanner {
  Future<List<ScanResult>> scan({
    required String cidr,
    int port = 22,
    int timeoutMs = 500,
  }) async {
    final results = <ScanResult>[];
    final ips = _cidrToIps(cidr);
    if (ips.isEmpty) return results;

    await Future.wait(ips.map((ip) async {
      final stopwatch = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          ip, port,
          timeout: Duration(milliseconds: timeoutMs),
        );
        stopwatch.stop();

        String? banner;
        try {
          final data = await socket
              .timeout(const Duration(milliseconds: 200))
              .transform(utf8.decoder as StreamTransformer<Uint8List, String>)
              .take(1)
              .join()
              .timeout(const Duration(milliseconds: 200));
          banner = data;
        } catch (_) {}

        await socket.close();

        results.add(ScanResult(
          ip: ip,
          port: port,
          sshBanner: banner?.trim(),
          responseTimeMs: stopwatch.elapsedMilliseconds,
        ));
      } catch (_) {}
    }));

    return results;
  }

  List<String> _cidrToIps(String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return [];

    final ipParts = parts[0].split('.');
    if (ipParts.length != 4) return [];
    final bits = int.tryParse(parts[1]);
    if (bits == null || bits < 16 || bits > 30) return [];

    final ipInt = (int.parse(ipParts[0]) << 24) |
        (int.parse(ipParts[1]) << 16) |
        (int.parse(ipParts[2]) << 8) |
        int.parse(ipParts[3]);

    final mask = bits == 0 ? 0 : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF;
    final network = ipInt & mask;
    final hostCount = (1 << (32 - bits)) - 2;

    if (hostCount <= 0 || hostCount > 1024) return [];

    return List.generate(hostCount, (i) {
      final addr = network + i + 1;
      return '${(addr >> 24) & 0xFF}.${(addr >> 16) & 0xFF}.${(addr >> 8) & 0xFF}.${addr & 0xFF}';
    }).where((ip) {
      final parts = ip.split('.').map(int.parse).toList();
      return parts[0] >= 1 && parts[0] <= 223 &&
          !(parts[0] == 10 && parts[3] == 1 ||
              parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31 && parts[3] == 1 ||
              parts[0] == 192 && parts[1] == 168 && parts[3] == 1);
    }).toList();
  }

  Future<(String cidr, String ip, int bits)> detectCurrentNetwork() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;
            return ('$ip/24', ip, 24);
          }
        }
      }
    } catch (_) {}
    return ('192.168.1.1/24', '192.168.1.1', 24);
  }

  bool isValidCidr(String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return false;
    final ipParts = parts[0].split('.');
    if (ipParts.length != 4) return false;
    for (final p in ipParts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    final bits = int.tryParse(parts[1]);
    if (bits == null || bits < 16 || bits > 30) return false;
    return true;
  }
}
