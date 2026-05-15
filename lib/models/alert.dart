class Alert {
  String id;
  String type;
  String severity;
  String message;
  String timestamp;
  String? productId;
  bool read;

  Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.productId,
    this.read = false,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String,
      message: json['message'] as String,
      timestamp: json['timestamp'] as String,
      productId: json['productId'] as String?, // Fixed from product_id
      // Convert SQLite integer back to boolean
      read: json['read'] == 1 || json['read'] == true, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'severity': severity,
      'message': message,
      'timestamp': timestamp,
      'productId': productId, // Fixed from product_id
      'read': read ? 1 : 0,   // Convert boolean to SQLite integer
    };
  }
}