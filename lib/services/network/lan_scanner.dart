import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ssh_client/data/models/scan_result.dart';

class LanScanner {
  Future<List<ScanResult>> scan({
    required String subnet,
    int port = 22,
    int timeoutMs = 500,
  }) async {
    final results = <ScanResult>[];
    final ips = _generateIps(subnet);

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

  List<String> _generateIps(String subnet) {
    final parts = subnet.split('.');
    if (parts.length != 4) return [];

    final base = '${parts[0]}.${parts[1]}.${parts[2]}.';
    return List.generate(254, (i) => '$base${i + 1}');
  }

  String getLocalSubnet() {
    return '192.168.1';
  }
}
