class Backup {
  final String id;
  final String filename;
  final int size;
  final String timestamp;
  final String type; // 'auto', 'manual'

  Backup({
    required this.id,
    required this.filename,
    required this.size,
    required this.timestamp,
    this.type = 'manual',
  });

  factory Backup.fromJson(Map<String, dynamic> json) => Backup(
        id: json['id'] as String,
        filename: json['filename'] as String,
        size: json['size'] as int,
        timestamp: json['timestamp'] as String,
        type: json['type'] as String? ?? 'manual',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'size': size,
        'timestamp': timestamp,
        'type': type,
      };
}
