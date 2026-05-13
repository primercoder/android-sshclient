import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_client/data/models/host.dart';

class HostDao {
  final Database _db;

  HostDao(this._db);

  List<Host> getAllHosts() {
    final result = _db.select('SELECT * FROM hosts ORDER BY last_seen_at DESC');
    return result.map((row) => _fromRow(row)).toList();
  }

  Host? getHostById(String hostId) {
    final result = _db.select(
      'SELECT * FROM hosts WHERE host_id = ?',
      [hostId],
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first);
  }

  Host? getHostByIp(String ip) {
    final result = _db.select(
      'SELECT * FROM hosts WHERE current_ip = ?',
      [ip],
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first);
  }

  void insertHost(Host host) {
    _db.execute('''
      INSERT OR REPLACE INTO hosts
      (host_id, display_name, current_ip, port, username, password, mac_address,
       host_key_fingerprint, host_key_algorithm, ssh_banner,
       first_seen_at, last_seen_at, connection_count, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      host.hostId,
      host.displayName,
      host.currentIp,
      host.port,
      host.username,
      host.password,
      host.macAddress,
      host.hostKeyFingerprint,
      host.hostKeyAlgorithm,
      host.sshBanner,
      host.firstSeenAt.toIso8601String(),
      host.lastSeenAt.toIso8601String(),
      host.connectionCount,
      host.notes,
    ]);
  }

  void updateHost(Host host) {
    _db.execute('''
      UPDATE hosts SET
        display_name = ?, current_ip = ?, port = ?, username = ?, password = ?,
        mac_address = ?, host_key_fingerprint = ?, host_key_algorithm = ?,
        ssh_banner = ?, first_seen_at = ?, last_seen_at = ?,
        connection_count = ?, notes = ?
      WHERE host_id = ?
    ''', [
      host.displayName,
      host.currentIp,
      host.port,
      host.username,
      host.password,
      host.macAddress,
      host.hostKeyFingerprint,
      host.hostKeyAlgorithm,
      host.sshBanner,
      host.firstSeenAt.toIso8601String(),
      host.lastSeenAt.toIso8601String(),
      host.connectionCount,
      host.notes,
      host.hostId,
    ]);
  }

  void deleteHost(String hostId) {
    _db.execute('DELETE FROM hosts WHERE host_id = ?', [hostId]);
  }

  Host _fromRow(Row row) => Host(
    hostId: row['host_id'] as String,
    displayName: row['display_name'] as String? ?? '',
    currentIp: row['current_ip'] as String,
    port: row['port'] as int? ?? 22,
    username: row['username'] as String? ?? 'root',
    password: row['password'] as String? ?? '',
    macAddress: row['mac_address'] as String?,
    hostKeyFingerprint: row['host_key_fingerprint'] as String,
    hostKeyAlgorithm: row['host_key_algorithm'] as String?,
    sshBanner: row['ssh_banner'] as String?,
    firstSeenAt: DateTime.parse(row['first_seen_at'] as String),
    lastSeenAt: DateTime.parse(row['last_seen_at'] as String),
    connectionCount: row['connection_count'] as int? ?? 0,
    notes: row['notes'] as String?,
  );
}
