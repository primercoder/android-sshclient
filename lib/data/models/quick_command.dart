class QuickCommand {
  final int? commandId;
  final String label;
  final String command;
  final int sortOrder;
  final bool isBuiltin;

  const QuickCommand({
    this.commandId,
    required this.label,
    required this.command,
    this.sortOrder = 0,
    this.isBuiltin = false,
  });

  QuickCommand copyWith({
    int? commandId,
    String? label,
    String? command,
    int? sortOrder,
    bool? isBuiltin,
  }) {
    return QuickCommand(
      commandId: commandId ?? this.commandId,
      label: label ?? this.label,
      command: command ?? this.command,
      sortOrder: sortOrder ?? this.sortOrder,
      isBuiltin: isBuiltin ?? this.isBuiltin,
    );
  }

  Map<String, dynamic> toJson() => {
    if (commandId != null) 'command_id': commandId,
    'label': label,
    'command': command,
    'sort_order': sortOrder,
    'is_builtin': isBuiltin ? 1 : 0,
  };

  factory QuickCommand.fromJson(Map<String, dynamic> json) => QuickCommand(
    commandId: json['command_id'] as int?,
    label: json['label'] as String,
    command: json['command'] as String,
    sortOrder: json['sort_order'] as int? ?? 0,
    isBuiltin: (json['is_builtin'] as int? ?? 0) == 1,
  );
}
