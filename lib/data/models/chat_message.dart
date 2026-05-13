enum MessageType { command, output, system, fileTransfer }

class ChatMessage {
  final String messageId;
  final String sessionId;
  final MessageType type;
  final String content;
  final String? workingDirectory;
  final DateTime timestamp;
  final int? durationMs;

  const ChatMessage({
    required this.messageId,
    required this.sessionId,
    required this.type,
    required this.content,
    this.workingDirectory,
    required this.timestamp,
    this.durationMs,
  });

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'session_id': sessionId,
    'type': type.name,
    'content': content,
    'working_directory': workingDirectory,
    'timestamp': timestamp.toIso8601String(),
    'duration_ms': durationMs,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    messageId: json['message_id'] as String,
    sessionId: json['session_id'] as String,
    type: MessageType.values.byName(json['type'] as String),
    content: json['content'] as String,
    workingDirectory: json['working_directory'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    durationMs: json['duration_ms'] as int?,
  );
}
