import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_client/data/models/transfer_task.dart';

class TransferDao {
  final Database _db;

  TransferDao(this._db);

  List<TransferTask> getTransfersBySession(String sessionId) {
    final result = _db.select(
      'SELECT * FROM transfer_tasks WHERE session_id = ? ORDER BY started_at DESC',
      [sessionId],
    );
    return result.map((row) => _fromRow(row)).toList();
  }

  List<TransferTask> getAllTransfers() {
    final result = _db.select(
      'SELECT * FROM transfer_tasks ORDER BY started_at DESC',
    );
    return result.map((row) => _fromRow(row)).toList();
  }

  void insertTransfer(TransferTask task) {
    _db.execute('''
      INSERT INTO transfer_tasks
      (transfer_id, session_id, direction, local_path, remote_path, filename,
       file_size, bytes_transferred, status, started_at, completed_at, error_message)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      task.transferId,
      task.sessionId,
      task.direction.name,
      task.localPath,
      task.remotePath,
      task.filename,
      task.fileSize,
      task.bytesTransferred,
      task.status.name,
      task.startedAt.toIso8601String(),
      task.completedAt?.toIso8601String(),
      task.errorMessage,
    ]);
  }

  void updateTransfer(TransferTask task) {
    _db.execute('''
      UPDATE transfer_tasks SET
        bytes_transferred = ?, status = ?, completed_at = ?, error_message = ?
      WHERE transfer_id = ?
    ''', [
      task.bytesTransferred,
      task.status.name,
      task.completedAt?.toIso8601String(),
      task.errorMessage,
      task.transferId,
    ]);
  }

  TransferTask _fromRow(Row row) => TransferTask(
    transferId: row['transfer_id'] as String,
    sessionId: row['session_id'] as String,
    direction: TransferDirection.values.byName(row['direction'] as String),
    localPath: row['local_path'] as String,
    remotePath: row['remote_path'] as String,
    filename: row['filename'] as String,
    fileSize: row['file_size'] as int? ?? 0,
    bytesTransferred: row['bytes_transferred'] as int? ?? 0,
    status: TransferStatus.values.byName(row['status'] as String),
    startedAt: DateTime.parse(row['started_at'] as String),
    completedAt: row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null,
    errorMessage: row['error_message'] as String?,
  );
}
