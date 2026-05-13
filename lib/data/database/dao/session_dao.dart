import 'package:sqlite3/sqlite3.dart' hide Session;
import 'package:ssh_client/data/models/session.dart';

class SessionDao {
  final Database _db;

  SessionDao(this._db);

  List<Session> getSessionsByHost(String hostId) {
    final result = _db.select(
      'SELECT * FROM sessions WHERE host_id = ? ORDER BY start_time DESC',
      [hostId],
    );
    return result.map((row) => _fromRow(row)).toList();
  }

  List<Session> getAllSessions() {
    final result = _db.select(
      'SELECT * FROM sessions ORDER BY start_time DESC',
    );
    return result.map((row) => _fromRow(row)).toList();
  }

  Session? getSessionById(String sessionId) {
    final result = _db.select(
      'SELECT * FROM sessions WHERE session_id = ?',
      [sessionId],
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first);
  }

  Session? getLatestSessionByHost(String hostId) {
    final result = _db.select(
      'SELECT * FROM sessions WHERE host_id = ? ORDER BY start_time DESC LIMIT 1',
      [hostId],
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first);
  }

  void insertSession(Session session) {
    _db.execute('''
      INSERT INTO sessions
      (session_id, host_id, start_time, end_time, command_count, last_working_dir)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      session.sessionId,
      session.hostId,
      session.startTime.toIso8601String(),
      session.endTime?.toIso8601String(),
      session.commandCount,
      session.lastWorkingDir,
    ]);
  }

  void updateSession(Session session) {
    _db.execute('''
      UPDATE sessions SET
        end_time = ?, command_count = ?, last_working_dir = ?
      WHERE session_id = ?
    ''', [
      session.endTime?.toIso8601String(),
      session.commandCount,
      session.lastWorkingDir,
      session.sessionId,
    ]);
  }

  Session _fromRow(Row row) => Session(
    sessionId: row['session_id'] as String,
    hostId: row['host_id'] as String,
    startTime: DateTime.parse(row['start_time'] as String),
    endTime: row['end_time'] != null ? DateTime.parse(row['end_time'] as String) : null,
    commandCount: row['command_count'] as int? ?? 0,
    lastWorkingDir: row['last_working_dir'] as String? ?? '/',
  );
}
