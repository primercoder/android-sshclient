class Host {
  final String hostId;
  final String displayName;
  final String currentIp;
  final int port;
  final String username;
  final String password;
  final String? macAddress;
  final String hostKeyFingerprint;
  final String? hostKeyAlgorithm;
  final String? sshBanner;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final int connectionCount;
  final String? notes;

  const Host({
    required this.hostId,
    this.displayName = '',
    required this.currentIp,
    this.port = 22,
    this.username = 'root',
    this.password = '',
    this.macAddress,
    required this.hostKeyFingerprint,
    this.hostKeyAlgorithm,
    this.sshBanner,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.connectionCount = 0,
    this.notes,
  });

  Host copyWith({
    String? hostId,
    String? displayName,
    String? currentIp,
    int? port,
    String? username,
    String? password,
    String? macAddress,
    String? hostKeyFingerprint,
    String? hostKeyAlgorithm,
    String? sshBanner,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    int? connectionCount,
    String? notes,
  }) {
    return Host(
      hostId: hostId ?? this.hostId,
      displayName: displayName ?? this.displayName,
      currentIp: currentIp ?? this.currentIp,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      macAddress: macAddress ?? this.macAddress,
      hostKeyFingerprint: hostKeyFingerprint ?? this.hostKeyFingerprint,
      hostKeyAlgorithm: hostKeyAlgorithm ?? this.hostKeyAlgorithm,
      sshBanner: sshBanner ?? this.sshBanner,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      connectionCount: connectionCount ?? this.connectionCount,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'host_id': hostId,
    'display_name': displayName,
    'current_ip': currentIp,
    'port': port,
    'username': username,
    'password': password,
    'mac_address': macAddress,
    'host_key_fingerprint': hostKeyFingerprint,
    'host_key_algorithm': hostKeyAlgorithm,
    'ssh_banner': sshBanner,
    'first_seen_at': firstSeenAt.toIso8601String(),
    'last_seen_at': lastSeenAt.toIso8601String(),
    'connection_count': connectionCount,
    'notes': notes,
  };

  factory Host.fromJson(Map<String, dynamic> json) => Host(
    hostId: json['host_id'] as String,
    displayName: json['display_name'] as String? ?? '',
    currentIp: json['current_ip'] as String,
    port: json['port'] as int? ?? 22,
    username: json['username'] as String? ?? 'root',
    password: json['password'] as String? ?? '',
    macAddress: json['mac_address'] as String?,
    hostKeyFingerprint: json['host_key_fingerprint'] as String,
    hostKeyAlgorithm: json['host_key_algorithm'] as String?,
    sshBanner: json['ssh_banner'] as String?,
    firstSeenAt: DateTime.parse(json['first_seen_at'] as String),
    lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    connectionCount: json['connection_count'] as int? ?? 0,
    notes: json['notes'] as String?,
  );
}
