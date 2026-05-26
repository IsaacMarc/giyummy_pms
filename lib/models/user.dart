class User {
  final String id;          // Keep final (ID never changes)
  final String username;    // Keep final (Username never changes)
  String passwordHash;
  String role;              // Removed final so admins can change roles
  String email;             // Removed final
  final String createdAt;   // Keep final
  String? lastLogin;
  bool isActive;
  String department;        // Removed final
  String phone;             // Removed final
  
  // --- NEW FIELDS (Removed 'final' so they can be edited) ---
  String employeeId;
  String firstName;
  String middleInitial;
  String lastName;

  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.email,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
    this.department = '',
    this.phone = '',
    this.employeeId = '',
    this.firstName = '',
    this.middleInitial = '',
    this.lastName = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      passwordHash: json['passwordHash'] as String,
      role: json['role'] as String,
      email: json['email'] as String,
      createdAt: json['createdAt'] as String,
      lastLogin: json['lastLogin'] as String?,
      isActive: json['isActive'] == 1 || json['isActive'] == true,
      department: json['department'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      middleInitial: json['middleInitial'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
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
      'isActive': isActive ? 1 : 0,
      'department': department,
      'phone': phone,
      'employeeId': employeeId,
      'firstName': firstName,
      'middleInitial': middleInitial,
      'lastName': lastName,
    };
  }
}