import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

class AppDatabase {
  static const int _version = 3;
  static AppDatabase? _instance;
  late final Database _db;

  AppDatabase._() {
    _init();
  }

  static Future<AppDatabase> getInstance() async {
    if (_instance == null) {
      _instance = AppDatabase._();
      await _instance!._ensureInitialized();
    }
    return _instance!;
  }

  Future<void> _ensureInitialized() async {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ssh_client.db'));

    _db = sqlite3.open(file.path, uri: false);
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA journal_mode = WAL');

    _migrate();
  }

  void _init() {}

  void _migrate() {
    final oldVersion = _db.select('PRAGMA user_version').first.values.first as int;

    _db.execute('''
      CREATE TABLE IF NOT EXISTS hosts (
        host_id            TEXT PRIMARY KEY,
        display_name       TEXT NOT NULL DEFAULT '',
        current_ip         TEXT NOT NULL,
        port               INTEGER NOT NULL DEFAULT 22,
        username           TEXT NOT NULL DEFAULT 'root',
        password           TEXT NOT NULL DEFAULT '',
        mac_address        TEXT,
        host_key_fingerprint TEXT NOT NULL,
        host_key_algorithm   TEXT,
        ssh_banner         TEXT,
        first_seen_at      TEXT NOT NULL,
        last_seen_at       TEXT NOT NULL,
        connection_count   INTEGER NOT NULL DEFAULT 0,
        notes              TEXT
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        session_id         TEXT PRIMARY KEY,
        host_id            TEXT NOT NULL REFERENCES hosts(host_id),
        start_time         TEXT NOT NULL,
        end_time           TEXT,
        command_count      INTEGER NOT NULL DEFAULT 0,
        last_working_dir   TEXT DEFAULT '/'
      )
    ''');

    if (oldVersion < 2) {
      _tryAddColumn('sessions', 'host_name', 'TEXT NOT NULL DEFAULT \'\'');
      _tryAddColumn('sessions', 'host_ip', 'TEXT NOT NULL DEFAULT \'\'');
    }

    if (oldVersion < 3) {
      _tryAddColumn('hosts', 'auth_method', 'TEXT DEFAULT \'password\'');
      _tryAddColumn('hosts', 'private_key_path', 'TEXT');
      _tryAddColumn('hosts', 'public_key_path', 'TEXT');
      _tryAddColumn('hosts', 'private_key_content', 'TEXT');
      _tryAddColumn('hosts', 'public_key_content', 'TEXT');
    }

    _db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        message_id         TEXT PRIMARY KEY,
        session_id         TEXT NOT NULL REFERENCES sessions(session_id),
        type               TEXT NOT NULL CHECK(type IN ('command','output','system','file_transfer')),
        content            TEXT NOT NULL,
        working_directory  TEXT,
        timestamp          TEXT NOT NULL,
        duration_ms        INTEGER
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS transfer_tasks (
        transfer_id        TEXT PRIMARY KEY,
        session_id         TEXT NOT NULL REFERENCES sessions(session_id),
        direction          TEXT NOT NULL CHECK(direction IN ('upload','download')),
        local_path         TEXT NOT NULL,
        remote_path        TEXT NOT NULL,
        filename           TEXT NOT NULL,
        file_size          INTEGER NOT NULL DEFAULT 0,
        bytes_transferred  INTEGER NOT NULL DEFAULT 0,
        status             TEXT NOT NULL CHECK(status IN ('pending','transferring','completed','failed','cancelled')),
        started_at         TEXT NOT NULL,
        completed_at       TEXT,
        error_message      TEXT
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS quick_commands (
        command_id         INTEGER PRIMARY KEY AUTOINCREMENT,
        label              TEXT NOT NULL,
        command            TEXT NOT NULL,
        sort_order         INTEGER NOT NULL DEFAULT 0,
        is_builtin         INTEGER NOT NULL DEFAULT 0
      )
    ''');

    _db.execute('PRAGMA user_version = $_version');

    _seedDefaultCommands();
  }

  void _tryAddColumn(String table, String column, String type) {
    try {
      _db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (_) {}
  }

  void _seedDefaultCommands() {
    final count = _db.select('SELECT COUNT(*) FROM quick_commands').first;
    if (count.values.first == 0) {
      final commands = [
        ('ls', 'ls -la', 1),
        ('df', 'df -h', 2),
        ('ps', 'ps aux', 3),
        ('free', 'free -h', 4),
        ('netstat', 'netstat -tlnp', 5),
        ('ip', 'ip a', 6),
        ('uptime', 'uptime', 7),
        ('pwd', 'pwd', 8),
      ];

      for (final cmd in commands) {
        _db.execute(
          'INSERT INTO quick_commands (label, command, sort_order, is_builtin) VALUES (?, ?, ?, 0)',
          [cmd.$1, cmd.$2, cmd.$3],
        );
      }
    }
  }

  Database get db => _db;

  void close() {
    _db.close();
    _instance = null;
  }
}
