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
      (session_id, host_id, host_name, host_ip, start_time, end_time, command_count, last_working_dir)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      session.sessionId,
      session.hostId,
      session.hostName,
      session.hostIp,
      session.startTime.toIso8601String(),
      session.endTime?.toIso8601String(),
      session.commandCount,
      session.lastWorkingDir,
    ]);
  }

  void updateSession(Session session) {
    _db.execute('''
      UPDATE sessions SET
        host_name = ?, host_ip = ?, end_time = ?, command_count = ?, last_working_dir = ?
      WHERE session_id = ?
    ''', [
      session.hostName,
      session.hostIp,
      session.endTime?.toIso8601String(),
      session.commandCount,
      session.lastWorkingDir,
      session.sessionId,
    ]);
  }

  void deleteSessionsByHostId(String hostId) {
    _db.execute('DELETE FROM sessions WHERE host_id = ?', [hostId]);
  }

  void deleteSession(String sessionId) {
    _db.execute('DELETE FROM sessions WHERE session_id = ?', [sessionId]);
  }

  int countSessionsByHost(String hostId) {
    final result = _db.select(
      'SELECT COUNT(*) AS cnt FROM sessions WHERE host_id = ?',
      [hostId],
    );
    return result.first['cnt'] as int;
  }

  Database get db => _db;

  Session _fromRow(Row row) => Session(
    sessionId: row['session_id'] as String,
    hostId: row['host_id'] as String,
    hostName: row['host_name'] as String? ?? '',
    hostIp: row['host_ip'] as String? ?? '',
    startTime: DateTime.parse(row['start_time'] as String),
    endTime: row['end_time'] != null ? DateTime.parse(row['end_time'] as String) : null,
    commandCount: row['command_count'] as int? ?? 0,
    lastWorkingDir: row['last_working_dir'] as String? ?? '/',
  );
}
