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

  /// Accumulate chunks until a newline (0x0a) and return the line as
  /// UTF-8 text (newline excluded).
  Future<String> _readLine(StreamIterator<List<int>> iter,
      {List<int>? firstChunk,
      Duration timeout = const Duration(seconds: 15)}) async {
    final buf = <int>[];
    if (firstChunk != null) buf.addAll(firstChunk);
    while (true) {
      final nl = buf.indexOf(0x0a);
      if (nl >= 0) return utf8.decode(buf.sublist(0, nl));
      final chunk = await _nextChunk(iter, timeout: timeout);
      buf.addAll(chunk);
    }
  }

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
        errorMessage: e.toString(),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Download  —  remote runs `scp -f <file>` (sender)
  // --------------------------------------------------------------------------
  //
  //   1. remote → C<perms> <size> <name>\n   (header)
  //               OR  \001 <err>\n            (error)
  //   2. us     → \0                          (header ack)
  //   3. remote → <file data>                (<size> bytes)
  //   4. remote → \0                          (done via transmit())
  //   5. us     → \0                          (final ack)
  //   6. remote exits, session.done

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
      // 1. First chunk — check for error marker (0x01) or header (C...)
      final first = await _nextChunk(iter);
      if (first.isNotEmpty && first[0] == 1) {
        String err;
        try {
          final rest = await _readAll(iter, timeout: const Duration(seconds: 3));
          err = '${utf8.decode(first.sublist(1))}${utf8.decode(rest)}'.trim();
        } catch (_) {
          err = utf8.decode(first.sublist(1)).trim();
        }
        throw Exception(err.isNotEmpty ? err : 'File not found');
      }
      final header = await _readLine(iter, firstChunk: first);
      final parts = header.split(' ');
      if (parts.length < 3) {
        throw Exception('Unexpected SCP header: $header');
      }
      final fileSize = int.tryParse(parts[1]) ?? 0;

      // 2. Acknowledge header
      _write(session, [0]);

      // 3+4. Read file data (fileSize bytes), ignore trailing \0
      final sink = localFile.openWrite();
      int received = 0;
      while (received < fileSize && await iter.moveNext()) {
        final chunk = iter.current;
        final need = fileSize - received;
        final toWrite = chunk.length > need ? chunk.sublist(0, need) : chunk;
        sink.add(toWrite);
        received += toWrite.length;
      }
      await sink.flush();
      await sink.close();

      // 5. Final ack — remote waits for \0 then exits
      _write(session, [0]);
      await session.done;

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: received,
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
