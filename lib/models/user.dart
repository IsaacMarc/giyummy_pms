class User {
  final String id;
  String username;
  String passwordHash;
  String role; // 'Admin', 'Manager', 'Employee'
  String email;
  final String createdAt;
  bool isActive;
  String? lastLogin;
  String phone;
  String department;

  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.email,
    required this.createdAt,
    this.isActive = true,
    this.lastLogin,
    this.phone = '',
    this.department = '',
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        username: json['username'] as String,
        passwordHash: json['password_hash'] as String,
        role: json['role'] as String,
        email: json['email'] as String,
        createdAt: json['created_at'] as String,
        isActive: json['is_active'] as bool? ?? true,
        lastLogin: json['last_login'] as String?,
        phone: json['phone'] as String? ?? '',
        department: json['department'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'password_hash': passwordHash,
        'role': role,
        'email': email,
        'created_at': createdAt,
        'is_active': isActive,
        'last_login': lastLogin,
        'phone': phone,
        'department': department,
      };

  User copyWith({
    String? username,
    String? passwordHash,
    String? role,
    String? email,
    bool? isActive,
    String? lastLogin,
    String? phone,
    String? department,
  }) =>
      User(
        id: id,
        username: username ?? this.username,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role ?? this.role,
        email: email ?? this.email,
        createdAt: createdAt,
        isActive: isActive ?? this.isActive,
        lastLogin: lastLogin ?? this.lastLogin,
        phone: phone ?? this.phone,
        department: department ?? this.department,
      );
}
