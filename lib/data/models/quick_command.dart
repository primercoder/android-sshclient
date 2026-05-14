class QuickCommand {
  final int? commandId;
  final String label;
  final String command;
  final String category;
  final int sortOrder;
  final bool isBuiltin;

  const QuickCommand({
    this.commandId,
    required this.label,
    required this.command,
    this.category = 'custom',
    this.sortOrder = 0,
    this.isBuiltin = false,
  });

  QuickCommand copyWith({
    int? commandId,
    String? label,
    String? command,
    String? category,
    int? sortOrder,
    bool? isBuiltin,
  }) {
    return QuickCommand(
      commandId: commandId ?? this.commandId,
      label: label ?? this.label,
      command: command ?? this.command,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      isBuiltin: isBuiltin ?? this.isBuiltin,
    );
  }

  Map<String, dynamic> toJson() => {
    if (commandId != null) 'command_id': commandId,
    'label': label,
    'command': command,
    'category': category,
    'sort_order': sortOrder,
    'is_builtin': isBuiltin ? 1 : 0,
  };

  factory QuickCommand.fromJson(Map<String, dynamic> json) => QuickCommand(
    commandId: json['command_id'] as int?,
    label: json['label'] as String,
    command: json['command'] as String,
    category: json['category'] as String? ?? 'custom',
    sortOrder: json['sort_order'] as int? ?? 0,
    isBuiltin: (json['is_builtin'] as int? ?? 0) == 1,
  );
}
