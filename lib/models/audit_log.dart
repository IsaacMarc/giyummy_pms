class AuditLog {
  final String id;
  final String userId;
  final String username;
  final String action;
  final String module;
  final String details;
  final String timestamp;

  AuditLog({
    required this.id,
    required this.userId,
    required this.username,
    required this.action,
    required this.module,
    required this.details,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        username: json['username'] as String,
        action: json['action'] as String,
        module: json['module'] as String,
        details: json['details'] as String,
        timestamp: json['timestamp'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'username': username,
        'action': action,
        'module': module,
        'details': details,
        'timestamp': timestamp,
      };
}
