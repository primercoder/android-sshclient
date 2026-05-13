import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_client/data/models/transfer_task.dart';

class ScpProgress {
  final int bytesTransferred;
  final int totalBytes;
  final double speedBytesPerSec;

  const ScpProgress({
    required this.bytesTransferred,
    required this.totalBytes,
    this.speedBytesPerSec = 0,
  });

  double get progress => totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;
}

class ScpTransferService {
  final SSHClient _client;
  final StreamController<ScpProgress> _progressController =
      StreamController<ScpProgress>.broadcast();

  ScpTransferService(this._client);

  Stream<ScpProgress> get progressStream => _progressController.stream;

  Future<TransferTask> uploadFile({
    required String localPath,
    required String remotePath,
    required String sessionId,
    required String transferId,
  }) async {
    final file = File(localPath);
    final fileSize = await file.length();
    final filename = file.uri.pathSegments.last;

    final task = TransferTask(
      transferId: transferId,
      sessionId: sessionId,
      direction: TransferDirection.upload,
      localPath: localPath,
      remotePath: '$remotePath/$filename',
      filename: filename,
      fileSize: fileSize,
      status: TransferStatus.transferring,
      startedAt: DateTime.now(),
    );

    final scpSession = await _client.execute('scp -t "$remotePath/"');

    scpSession.stdin.add(Uint8List.fromList(utf8.encode('C0644 $fileSize $filename\n')));
    await scpSession.stdout.first;

    final stream = file.openRead();
    int bytesSent = 0;
    final stopwatch = Stopwatch()..start();

    await for (final chunk in stream) {
      scpSession.stdin.add(Uint8List.fromList(chunk));
      bytesSent += chunk.length;

      final elapsed = stopwatch.elapsedMilliseconds / 1000;
      final speed = elapsed > 0 ? bytesSent / elapsed : 0.0;

      _progressController.add(ScpProgress(
        bytesTransferred: bytesSent,
        totalBytes: fileSize,
        speedBytesPerSec: speed,
      ));
    }

      scpSession.stdin.add(Uint8List.fromList([0]));
    await scpSession.done;
    stopwatch.stop();

    return task.copyWith(
      status: TransferStatus.completed,
      bytesTransferred: fileSize,
      completedAt: DateTime.now(),
    );
  }

  Future<TransferTask> downloadFile({
    required String remotePath,
    required String localPath,
    required String sessionId,
    required String transferId,
  }) async {
    final filename = remotePath.split('/').last;
    final localFile = File(localPath);

    final task = TransferTask(
      transferId: transferId,
      sessionId: sessionId,
      direction: TransferDirection.download,
      localPath: localPath,
      remotePath: remotePath,
      filename: filename,
      status: TransferStatus.transferring,
      startedAt: DateTime.now(),
    );

    final scpSession = await _client.execute('scp -f "$remotePath"');

    scpSession.stdin.add(Uint8List.fromList([0]));

    final header = await scpSession.stdout.transform(
      utf8.decoder as StreamTransformer<Uint8List, String>,
    ).first;
    final parts = header.split(' ');
    if (parts.length >= 3) {
      final fileSize = int.tryParse(parts[1]) ?? 0;

    scpSession.stdin.add(Uint8List.fromList([0]));

      final sink = localFile.openWrite();
      int bytesReceived = 0;
      final stopwatch = Stopwatch()..start();

      await for (final chunk in scpSession.stdout) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        final elapsed = stopwatch.elapsedMilliseconds / 1000;
        final speed = elapsed > 0 ? bytesReceived / elapsed : 0.0;

        if (fileSize > 0) {
          _progressController.add(ScpProgress(
            bytesTransferred: bytesReceived,
            totalBytes: fileSize,
            speedBytesPerSec: speed,
          ));
        }
      }

      await sink.flush();
      await sink.close();
      stopwatch.stop();
    }

    await scpSession.done;

    final completedFile = File(localPath);
    final actualSize = await completedFile.length();

    return task.copyWith(
      status: TransferStatus.completed,
      bytesTransferred: actualSize,
      completedAt: DateTime.now(),
    );
  }

  void dispose() {
    _progressController.close();
  }
}
