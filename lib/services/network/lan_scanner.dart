import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ssh_client/data/models/scan_result.dart';

class ScanAbort {
  bool _stopped = false;
  Completer<void> _pauseCompleter = Completer<void>()..complete();

  void stop() { _stopped = true; resume(); }
  void pause() { if (!_pauseCompleter.isCompleted) return; _pauseCompleter = Completer<void>(); }
  void resume() { if (_pauseCompleter.isCompleted) return; _pauseCompleter.complete(); }
  bool get isStopped => _stopped;
  bool get isPaused => !_pauseCompleter.isCompleted;
  Future<void> get pauseSignal => _pauseCompleter.future;
}

class LanScanner {
  static const int _batchSize = 100;
  static const int _batchDelayMs = 3000;

  Future<List<ScanResult>> scan({
    required String cidr,
    int port = 22,
    int timeoutMs = 1000,
    void Function(ScanResult result)? onResult,
    void Function(int scanned, int total)? onProgress,
    ScanAbort? abort,
  }) async {
    final results = <ScanResult>[];
    final ips = _cidrToIps(cidr);
    final totalIps = ips.length;
    if (ips.isEmpty) return results;

    for (int start = 0; start < ips.length; start += _batchSize) {
      if (abort?.isStopped == true) break;
      while (abort?.isPaused == true) {
        try {
          await abort!.pauseSignal.timeout(const Duration(seconds: 30));
        } on TimeoutException {
          // resume polling when timeout expires
        }
      }
      if (abort?.isStopped == true) break;
      final end = (start + _batchSize > ips.length) ? ips.length : start + _batchSize;
      final batch = ips.sublist(start, end);

      await Future.wait(batch.map((ip) async {
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

          final result = ScanResult(
            ip: ip, port: port,
            sshBanner: banner?.trim(),
            responseTimeMs: stopwatch.elapsedMilliseconds,
          );
          results.add(result);
          onResult?.call(result);
        } catch (_) {}
      }));

      onProgress?.call(end, totalIps);

      if (end < ips.length) {
        await Future.delayed(const Duration(milliseconds: _batchDelayMs));
      }
    }

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

    if (hostCount <= 0 || hostCount > 131070) return [];

    return List.generate(hostCount, (i) {
      final addr = network + i + 1;
      return '${(addr >> 24) & 0xFF}.${(addr >> 16) & 0xFF}.${(addr >> 8) & 0xFF}.${addr & 0xFF}';
    }).where((ip) {
      final p = ip.split('.').map(int.parse).toList();
      return p[0] >= 1 && p[0] <= 223;
    }).toList();
  }

  Future<String> detectCurrentCidr() async {
    try {
      final route = await _readProcNetRoute();
      if (route != null) {
        final (ip, bits) = route;
        return '$ip/$bits';
      }
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return '${addr.address}/24';
          }
        }
      }
    } catch (_) {}
    return '192.168.1.1/24';
  }

  Future<(String ip, int bits)?> _readProcNetRoute() async {
    try {
      final file = File('/proc/net/route');
      if (!await file.exists()) return null;

      final lines = await file.readAsLines();
      for (final line in lines.skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 8) continue;

        final destHex = parts[1];
        final maskHex = parts[7];
        final iface = parts[0];

        if (destHex == '00000000' || iface.isEmpty) continue;

        final destIp = _hexToIp(destHex);
        if (destIp == null) continue;

        final maskBits = _maskHexToBits(maskHex);
        if (maskBits < 16 || maskBits > 30) continue;

        final ip = await _findInterfaceIp(iface);
        if (ip == null) continue;

        return (ip, maskBits);
      }
    } catch (_) {}
    return null;
  }

  String? _hexToIp(String hex) {
    if (hex.length != 8) return null;
    try {
      final val = int.parse(hex, radix: 16);
      return '${val & 0xFF}.${(val >> 8) & 0xFF}.${(val >> 16) & 0xFF}.${(val >> 24) & 0xFF}';
    } catch (_) {
      return null;
    }
  }

  int _maskHexToBits(String hex) {
    try {
      final val = int.parse(hex, radix: 16);
      return val.toRadixString(2).split('').where((c) => c == '1').length;
    } catch (_) {
      return 24;
    }
  }

  Future<String?> _findInterfaceIp(String ifaceName) async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        if (iface.name == ifaceName) {
          for (final addr in iface.addresses) {
            if (addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  int estimatedHostCount(String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return 0;
    final bits = int.tryParse(parts[1]);
    if (bits == null || bits < 16 || bits > 30) return 0;
    return (1 << (32 - bits)) - 2;
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
