import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_client/data/models/chat_message.dart';

class MessageDao {
  final Database _db;

  MessageDao(this._db);

  List<ChatMessage> getMessagesBySession(String sessionId) {
    final result = _db.select(
      'SELECT * FROM chat_messages WHERE session_id = ? ORDER BY timestamp ASC',
      [sessionId],
    );
    return result.map((row) => _fromRow(row)).toList();
  }

  void insertMessage(ChatMessage message) {
    _db.execute('''
      INSERT INTO chat_messages
      (message_id, session_id, type, content, working_directory, timestamp, duration_ms)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      message.messageId,
      message.sessionId,
      message.type.name,
      message.content,
      message.workingDirectory,
      message.timestamp.toIso8601String(),
      message.durationMs,
    ]);
  }

  void insertMessages(List<ChatMessage> messages) {
    for (final msg in messages) {
      insertMessage(msg);
    }
  }

  void updateMessageContent(String messageId, String content) {
    _db.execute(
      'UPDATE chat_messages SET content = ? WHERE message_id = ?',
      [content, messageId],
    );
  }

  void deleteMessagesBySession(String sessionId) {
    _db.execute(
      'DELETE FROM chat_messages WHERE session_id = ?',
      [sessionId],
    );
  }

  ChatMessage _fromRow(Row row) => ChatMessage(
    messageId: row['message_id'] as String,
    sessionId: row['session_id'] as String,
    type: MessageType.values.byName(row['type'] as String),
    content: row['content'] as String,
    workingDirectory: row['working_directory'] as String?,
    timestamp: DateTime.parse(row['timestamp'] as String),
    durationMs: row['duration_ms'] as int?,
  );
}
