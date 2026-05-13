class Session {
  final String sessionId;
  final String hostId;
  final DateTime startTime;
  final DateTime? endTime;
  final int commandCount;
  final String lastWorkingDir;

  const Session({
    required this.sessionId,
    required this.hostId,
    required this.startTime,
    this.endTime,
    this.commandCount = 0,
    this.lastWorkingDir = '/',
  });

  Session copyWith({
    String? sessionId,
    String? hostId,
    DateTime? startTime,
    DateTime? endTime,
    int? commandCount,
    String? lastWorkingDir,
  }) {
    return Session(
      sessionId: sessionId ?? this.sessionId,
      hostId: hostId ?? this.hostId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      commandCount: commandCount ?? this.commandCount,
      lastWorkingDir: lastWorkingDir ?? this.lastWorkingDir,
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'host_id': hostId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'command_count': commandCount,
    'last_working_dir': lastWorkingDir,
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    sessionId: json['session_id'] as String,
    hostId: json['host_id'] as String,
    startTime: DateTime.parse(json['start_time'] as String),
    endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
    commandCount: json['command_count'] as int? ?? 0,
    lastWorkingDir: json['last_working_dir'] as String? ?? '/',
  );
}
