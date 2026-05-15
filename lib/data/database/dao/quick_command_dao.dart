import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_client/data/models/quick_command.dart';

class QuickCommandDao {
  final Database _db;

  QuickCommandDao(this._db);

  List<QuickCommand> getAll() {
    final result = _db.select(
      'SELECT * FROM quick_commands ORDER BY sort_order ASC, command_id ASC',
    );
    return result.map((row) => _fromRow(row)).toList();
  }

  int insert(QuickCommand cmd) {
    _db.execute('''
      INSERT INTO quick_commands (label, command, sort_order, is_builtin)
      VALUES (?, ?, ?, ?)
    ''', [
      cmd.label,
      cmd.command,
      cmd.sortOrder,
      cmd.isBuiltin ? 1 : 0,
    ]);
    return _db.lastInsertRowId;
  }

  void update(QuickCommand cmd) {
    _db.execute('''
      UPDATE quick_commands SET label = ?, command = ?, sort_order = ?
      WHERE command_id = ?
    ''', [
      cmd.label,
      cmd.command,
      cmd.sortOrder,
      cmd.commandId,
    ]);
  }

  void delete(int commandId) {
    _db.execute(
      'DELETE FROM quick_commands WHERE command_id = ?',
      [commandId],
    );
  }

  QuickCommand _fromRow(Row row) => QuickCommand(
    commandId: row['command_id'] as int,
    label: row['label'] as String,
    command: row['command'] as String,
    sortOrder: row['sort_order'] as int? ?? 0,
    isBuiltin: (row['is_builtin'] as int? ?? 0) == 1,
  );
}
