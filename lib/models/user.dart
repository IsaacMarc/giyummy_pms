class User {
  final String id;
  final String username;
  String passwordHash;
  final String role; 
  String email;
  final String createdAt;
  String? lastLogin;
  bool isActive;
  String department; // Added
  String phone;      // Added

  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.email,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true, // Default to true
    this.department = '', // Default to empty string
    this.phone = '',      // Default to empty string
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      passwordHash: json['passwordHash'] as String,
      role: json['role'] as String,
      email: json['email'] as String? ?? '',
      createdAt: json['createdAt'] as String,
      lastLogin: json['lastLogin'] as String?,
      // SQLite stores booleans as 1 or 0, so we check if it equals 1 or true
      isActive: json['isActive'] == 1 || json['isActive'] == true,
      department: json['department'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'passwordHash': passwordHash,
      'role': role,
      'email': email,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'isActive': isActive ? 1 : 0, // Convert to SQLite integer format
      'department': department,
      'phone': phone,
    };
  }
}