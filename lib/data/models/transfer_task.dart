enum TransferDirection { upload, download }

enum TransferStatus { pending, transferring, completed, failed, cancelled }

class TransferTask {
  final String transferId;
  final String sessionId;
  final TransferDirection direction;
  final String localPath;
  final String remotePath;
  final String filename;
  final int fileSize;
  final int bytesTransferred;
  final TransferStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  const TransferTask({
    required this.transferId,
    required this.sessionId,
    required this.direction,
    required this.localPath,
    required this.remotePath,
    required this.filename,
    this.fileSize = 0,
    this.bytesTransferred = 0,
    this.status = TransferStatus.pending,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  double get progress => fileSize > 0 ? bytesTransferred / fileSize : 0.0;

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  TransferTask copyWith({
    String? transferId,
    String? sessionId,
    TransferDirection? direction,
    String? localPath,
    String? remotePath,
    String? filename,
    int? fileSize,
    int? bytesTransferred,
    TransferStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return TransferTask(
      transferId: transferId ?? this.transferId,
      sessionId: sessionId ?? this.sessionId,
      direction: direction ?? this.direction,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      filename: filename ?? this.filename,
      fileSize: fileSize ?? this.fileSize,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'transfer_id': transferId,
    'session_id': sessionId,
    'direction': direction.name,
    'local_path': localPath,
    'remote_path': remotePath,
    'filename': filename,
    'file_size': fileSize,
    'bytes_transferred': bytesTransferred,
    'status': status.name,
    'started_at': startedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'error_message': errorMessage,
  };

  factory TransferTask.fromJson(Map<String, dynamic> json) => TransferTask(
    transferId: json['transfer_id'] as String,
    sessionId: json['session_id'] as String,
    direction: TransferDirection.values.byName(json['direction'] as String),
    localPath: json['local_path'] as String,
    remotePath: json['remote_path'] as String,
    filename: json['filename'] as String,
    fileSize: json['file_size'] as int? ?? 0,
    bytesTransferred: json['bytes_transferred'] as int? ?? 0,
    status: TransferStatus.values.byName(json['status'] as String),
    startedAt: DateTime.parse(json['started_at'] as String),
    completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
    errorMessage: json['error_message'] as String?,
  );
}
