class Alert {
  final String id;
  final String type; // 'low-stock', 'expiring', 'restock', 'system'
  final String severity; // 'info', 'warning', 'critical'
  final String message;
  final String timestamp;
  bool read;
  final String? productId;

  Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.read = false,
    this.productId,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as String,
        type: json['type'] as String,
        severity: json['severity'] as String,
        message: json['message'] as String,
        timestamp: json['timestamp'] as String,
        read: json['read'] as bool? ?? false,
        productId: json['product_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'severity': severity,
        'message': message,
        'timestamp': timestamp,
        'read': read,
        'product_id': productId,
      };
}
