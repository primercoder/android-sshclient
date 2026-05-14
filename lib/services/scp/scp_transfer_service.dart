import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:ssh_client/data/models/transfer_task.dart';

class ScpTransferService {
  final SSHClient _client;

  ScpTransferService(this._client);

  void _write(SSHSession s, List<int> data) =>
      s.stdin.add(Uint8List.fromList(data));

  /// Read the next chunk from the SCP stdout stream iterator.
  Future<List<int>> _nextChunk(StreamIterator<List<int>> iter,
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (await iter.moveNext().timeout(timeout)) return iter.current;
    throw Exception('SCP stream ended unexpectedly');
  }

  /// Snapshot stderr with a short timeout so callers never block forever.
  Future<String> _stderrSnapshot(SSHSession session) async {
    final buf = <int>[];
    try {
      await for (final chunk in session.stderr) {
        buf.addAll(chunk);
      }
    } catch (_) {}
    return utf8.decode(buf).trim();
  }

  /// Accumulate chunks until a newline (0x0a) and return the line as
  /// UTF-8 text (newline excluded).

  /// Read all remaining bytes from [iter] (up to [limit]).
  Future<List<int>> _readAll(StreamIterator<List<int>> iter,
      {int? limit, Duration timeout = const Duration(seconds: 30)}) async {
    final buf = <int>[];
    while ((limit == null || buf.length < limit) &&
        await iter.moveNext().timeout(timeout)) {
      final chunk = iter.current;
      if (limit != null) {
        final need = limit - buf.length;
        buf.addAll(chunk.length > need ? chunk.sublist(0, need) : chunk);
        if (buf.length >= limit) break;
      } else {
        buf.addAll(chunk);
      }
    }
    return buf;
  }

  /// Read an SCP acknowledgment chunk and throw on error.
  /// SCP ack:  \0 = success,  \001 + msg\n = error.
  Future<void> _expectAck(StreamIterator<List<int>> iter) async {
    final chunk = await _nextChunk(iter);
    if (chunk.isEmpty) throw Exception('Empty SCP response');
    if (chunk[0] == 0) return;
    if (chunk[0] == 1) {
      // Collect the rest of the error message from the stream
      String err;
      try {
        final rest = await _readAll(iter, timeout: const Duration(seconds: 3));
        err = '${utf8.decode(chunk.sublist(1))}${utf8.decode(rest)}'.trim();
      } catch (_) {
        err = utf8.decode(chunk.sublist(1)).trim();
      }
      throw Exception(err.isNotEmpty ? err : 'SCP error');
    }
    throw Exception('Unexpected SCP response byte: ${chunk[0]}');
  }

  // --------------------------------------------------------------------------
  // Upload  —  remote runs `scp -t <dir>` (receiver)
  // --------------------------------------------------------------------------
  //
  //   1. remote → \0            (ready)
  //   2. us     → C0644 <size> <name>\n
  //   3. remote → \0            (ack)  OR  \001 <err>\n  (error)
  //   4. us     → <file data>
  //   5. us     → close(stdin)  (EOF — remote read() returns 0, sink exits)
  //   6. session.done

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
      await _expectAck(iter);                                     // 1
      _write(session, utf8.encode('C0644 $fileSize $filename\n')); // 2
      await _expectAck(iter);                                     // 3

      int sent = 0;
      final src = file.openRead();
      await for (final chunk in src) {
        _write(session, chunk);
        sent += chunk.length;
      }
      await session.stdin.close();                                // 5
      await session.done;                                         // 6

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: sent,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      return task.copyWith(
        status: TransferStatus.failed,
        errorMessage: '$filename → ${task.remotePath}: ${e.toString()}',
      );
    }
  }

  // --------------------------------------------------------------------------
  // Download  —  read file via SSH exec cat (avoids SCP protocol deadlocks)
  // --------------------------------------------------------------------------
  //
  // Runs `cat "$remotePath"` on the remote and captures stdout as raw bytes.
  // Simpler than scp -f: no bidirectional ack protocol, no risk of deadlock.

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

    final session = await _client.execute('cat "$remotePath"');
    final sink = localFile.openWrite();
    int received = 0;

    try {
      await for (final chunk in session.stdout) {
        sink.add(chunk);
        received += chunk.length;
      }
      await sink.flush();
      await sink.close();
      await session.done;

      if (received == 0 && localFile.lengthSync() == 0) {
        final stderr = await _stderrSnapshot(session);
        localFile.deleteSync();
        throw Exception(stderr.isNotEmpty ? stderr : 'File not found or empty');
      }

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: received,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      // Close sink and remove the incomplete local file
      try { await sink.flush(); } catch (_) {}
      try { await sink.close(); } catch (_) {}
      try { await localFile.delete(); } catch (_) {}

      final stderr = await _stderrSnapshot(session);
      final detail = stderr.isNotEmpty ? stderr : e.toString();
      return task.copyWith(
        status: TransferStatus.failed,
        errorMessage: '$filename ← $remotePath: $detail',
      );
    }
  }
}
