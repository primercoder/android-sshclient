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

  /// Accumulate stdout chunks until a newline (0x0a) and return the
  /// line as UTF-8 text (newline excluded).
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

  /// Collect all stderr output from [session] into a single string,
  /// with a short timeout so the method doesn't block indefinitely.
  Future<String> _collectStderr(SSHSession session) async {
    final buf = <int>[];
    try {
      await for (final chunk in session.stderr) {
        buf.addAll(chunk);
      }
    } catch (_) {}
    return utf8.decode(buf).trim();
  }

  // --------------------------------------------------------------------------
  // Upload  –  remote runs `scp -t <dir>` (receiver)
  // --------------------------------------------------------------------------
  //
  // Protocol:
  //   1. remote → \0         (ready)
  //   2. us     → "C<perms> <size> <name>\n"
  //   3. remote → \0         (header ack)
  //   4. us     → <file data>
  //   5. us     → \0         (eof)
  //   6. remote → \0         (done) & closes channel

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
      await _nextChunk(iter);                                    // 1
      _write(session, utf8.encode('C0644 $fileSize $filename\n')); // 2
      await _nextChunk(iter);                                    // 3

      int sent = 0;
      final src = file.openRead();
      await for (final chunk in src) {
        _write(session, chunk);
        sent += chunk.length;
      }
      _write(session, [0]);                                      // 5
      await session.done;                                        // 6

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: sent,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      final stderr = await _collectStderr(session);
      return task.copyWith(
        status: TransferStatus.failed,
        errorMessage: stderr.isNotEmpty ? stderr : e.toString(),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Download  –  remote runs `scp -f <file>` (sender)
  // --------------------------------------------------------------------------
  //
  // Protocol:
  //   1. remote → "C<perms> <size> <name>\n"
  //   2. us     → \0                            (header ack)
  //   3. remote → <file data>                   (<size> bytes)
  //   4. remote → \0                            (done marker via transmit())
  //   5. us     → \0                            (final ack)
  //   6. remote closes channel

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
      // 1. Remote sends header first (no init needed from us)
      final header = await _readLine(iter);
      final parts = header.split(' ');
      if (parts.length < 3) {
        throw Exception('Unexpected SCP header: $header');
      }
      final fileSize = int.tryParse(parts[1]) ?? 0;

      // 2. Acknowledge header – remote proceeds to send file data
      _write(session, [0]);

      // 3+4. Read file data (fileSize bytes).  The trailing \0 from
      // the remote's transmit() may be in the same or the next chunk.
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

      // 5. Send final ack – remote reads \0 and exits
      _write(session, [0]);
      await session.done;

      return task.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: received,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      final stderr = await _collectStderr(session);
      return task.copyWith(
        status: TransferStatus.failed,
        errorMessage: stderr.isNotEmpty ? stderr : e.toString(),
      );
    }
  }
}
