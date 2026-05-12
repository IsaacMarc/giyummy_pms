import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/models.dart';

class AuthService {
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }

  static bool checkPermission(User user, String requiredRole) {
    const hierarchy = {'Admin': 3, 'Manager': 2, 'Employee': 1};
    final userLevel = hierarchy[user.role] ?? 0;
    final requiredLevel = hierarchy[requiredRole] ?? 0;
    return userLevel >= requiredLevel;
  }
}
