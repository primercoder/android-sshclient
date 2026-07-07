import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

class SshTerminalService {
  SSHSession? _session;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  bool _disposed = false;

  bool get isActive => _session != null && !_disposed;

  Future<void> start(SSHClient client, Terminal terminal) async {
    await stop();

    _session = await client.shell(
      pty: SSHPtyConfig(
        type: 'xterm-256color',
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _session?.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };

    terminal.onOutput = (data) {
      if (_session != null && !_disposed) {
        try {
          _session!.write(Uint8List.fromList(utf8.encode(data)));
        } catch (_) {}
      }
    };

    _stdoutSub = _session!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(
          (data) {
            if (!_disposed) terminal.write(data);
          },
          onError: (_) {},
          cancelOnError: false,
        );

    _stderrSub = _session!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(
          (data) {
            if (!_disposed) terminal.write(data);
          },
          onError: (_) {},
          cancelOnError: false,
        );
  }

  void write(Uint8List data) {
    if (_session != null && !_disposed) {
      try {
        _session!.write(data);
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    await _stderrSub?.cancel();
    _stderrSub = null;

    if (_session != null) {
      try {
        _session!.close();
      } catch (_) {}
      _session = null;
    }
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
