import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_client/data/models/transfer_task.dart';

class ScpTransferService {
  final SSHClient _client;

  ScpTransferService(this._client);

  void _write(SSHSession session, List<int> data) {
    session.stdin.add(Uint8List.fromList(data));
  }

  /// Read the next chunk from the SCP stdout stream iterator.
  Future<List<int>> _nextChunk(StreamIterator<List<int>> iter,
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (await iter.moveNext().timeout(timeout)) return iter.current;
    throw Exception('SCP stream ended unexpectedly');
  }

  /// Accumulate stdout chunks until a newline (0x0a) is found and return
  /// the line as a UTF-8 string (newline excluded).
  Future<String> _readLine(StreamIterator<List<int>> iter,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final buf = <int>[];
    while (true) {
      final chunk = await _nextChunk(iter, timeout: timeout);
      final nl = chunk.indexOf(0x0a);
      if (nl >= 0) {
        buf.addAll(chunk.sublist(0, nl));
        return utf8.decode(buf);
      }
      buf.addAll(chunk);
    }
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

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

    final session = await _client.execute('scp -t "$remotePath/"');
    final iter = StreamIterator(session.stdout);

    try {
      // SCP upload protocol:
      //   1. receiver sends \0 (ready)
      //   2. sender sends "C0644 <size> <name>\n"  (header)
      //   3. receiver sends \0 (header ack)
      //   4. sender sends <file data>
      //   5. sender sends \0 (eof)
      //   6. receiver sends \0 (done) & closes

      await _nextChunk(iter);                              // 1
      _write(session, utf8.encode('C0644 $fileSize $filename\n')); // 2
      await _nextChunk(iter);                              // 3

      int bytesSent = 0;
      final fileStream = file.openRead();
      await for (final chunk in fileStream) {
        _write(session, chunk);
        bytesSent += chunk.length;
      }

      _write(session, [0]);                                // 5
      await session.done;                                  // 6

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: bytesSent,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      return task.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Download
  // ---------------------------------------------------------------------------

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

    final session = await _client.execute('scp -f "$remotePath"');
    final iter = StreamIterator(session.stdout);

    try {
      // SCP download protocol:
      //   1. sender sends \0 (ready)
      //   2. receiver sends "C0644 <size> <name>\n"  (header)
      //   3. sender sends \0 (header ack)
      //   4. receiver sends <file data>  (<size> bytes)
      //   5. receiver sends \0 (done) & closes

      _write(session, [0]);                                // 1

      final header = await _readLine(iter);                // 2
      final parts = header.split(' ');
      if (parts.length < 3) {
        throw Exception('Unexpected SCP response: $header');
      }
      final fileSize = int.tryParse(parts[1]) ?? 0;

      _write(session, [0]);                                // 3

      final sink = localFile.openWrite();
      int bytesReceived = 0;
      while (bytesReceived < fileSize && await iter.moveNext()) {
        final chunk = iter.current;
        final remaining = fileSize - bytesReceived;
        final toWrite = chunk.length > remaining
            ? chunk.sublist(0, remaining)
            : chunk;
        sink.add(toWrite);
        bytesReceived += toWrite.length;
      }

      await sink.flush();
      await sink.close();
      await session.done;

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: bytesReceived,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      return task.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }
}
