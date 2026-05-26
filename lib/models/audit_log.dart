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

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['userId'] as String, // <--- MUST BE camelCase
      username: json['username'] as String,
      action: json['action'] as String,
      module: json['module'] as String,
      details: json['details'] as String,
      timestamp: json['timestamp'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId, // <--- MUST BE camelCase
      'username': username,
      'action': action,
      'module': module,
      'details': details,
      'timestamp': timestamp,
    };
  }
}
