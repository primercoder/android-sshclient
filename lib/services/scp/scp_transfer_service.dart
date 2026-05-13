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

  ScpTransferService(this._client);

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

    try {
      scpSession.stdin.add(Uint8List.fromList(utf8.encode('C0644 $fileSize $filename\n')));
      await utf8.decodeStream(scpSession.stdout).timeout(const Duration(seconds: 5));

      final stream = file.openRead();
      int bytesSent = 0;

      await for (final chunk in stream) {
        scpSession.stdin.add(Uint8List.fromList(chunk));
        bytesSent += chunk.length;
      }

      scpSession.stdin.add(Uint8List.fromList([0]));
      await scpSession.done;

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: bytesSent,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      scpSession.close();
      return task.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
    }
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

    try {
      scpSession.stdin.add(Uint8List.fromList([0]));

      final header = await utf8.decodeStream(scpSession.stdout).timeout(const Duration(seconds: 5));
      final parts = header.split(' ');
      if (parts.length < 3) {
        throw Exception('Unexpected SCP response: $header');
      }

      final _ = int.tryParse(parts[1]) ?? 0;

      scpSession.stdin.add(Uint8List.fromList([0]));

      final sink = localFile.openWrite();
      int bytesReceived = 0;

      await for (final chunk in scpSession.stdout) {
        sink.add(chunk);
        bytesReceived += chunk.length;
      }

      await sink.flush();
      await sink.close();
      await scpSession.done;

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: bytesReceived,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      scpSession.close();
      return task.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }
}
