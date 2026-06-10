import 'dart:async';
import 'package:flutter/material.dart';
import 'package:product_management/views/dashboard_screen.dart';
import 'package:product_management/views/register_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _error;
  bool _obscure = true;
  bool _loading = false;

  // --- SECURITY LOCKOUT VARIABLES ---
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _checkSystemInitialization();
    _loadLockoutState();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSystemInitialization() async {
    final users = await StorageService.instance.getUsers();
    
    if (!mounted) return;
    
    if (users.isEmpty) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const RegisterScreen())
      );
    }
  }

  // --- SECURITY LOGIC ---
  Future<void> _loadLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt('login_failed_attempts') ?? 0;
    
    final lockoutStr = prefs.getString('login_lockout_time');
    if (lockoutStr != null) {
      _lockoutEndTime = DateTime.parse(lockoutStr);
      if (_lockoutEndTime!.isAfter(DateTime.now())) {
        _startLockoutTimer();
      } else {
        _resetLockout(); // Time has passed, unlock!
      }
    }
  }

  void _startLockoutTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      final now = DateTime.now();
      if (_lockoutEndTime!.isAfter(now)) {
        final diff = _lockoutEndTime!.difference(now);
        final minutes = diff.inMinutes.toString().padLeft(2, '0');
        final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
        
        setState(() {
          _error = "Account locked due to multiple failed attempts.\nTry again in $minutes:$seconds";
        });
      } else {
        _resetLockout();
      }
    });
  }

  Future<void> _resetLockout() async {
    _countdownTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_failed_attempts');
    await prefs.remove('login_lockout_time');
    
    if (mounted) {
      setState(() {
        _failedAttempts = 0;
        _lockoutEndTime = null;
        if (_error != null && _error!.contains('Account locked')) {
          _error = null;
        }
      });
    }
  }

  Future<void> _handleFailedAttempt(String originalError) async {
    _failedAttempts++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('login_failed_attempts', _failedAttempts);

    if (_failedAttempts >= 5) {
      // Trigger the 10-minute lockout
      _lockoutEndTime = DateTime.now().add(const Duration(minutes: 10));
      await prefs.setString('login_lockout_time', _lockoutEndTime!.toIso8601String());
      _startLockoutTimer();
      
      setState(() => _loading = false);
    } else {
      // Show remaining attempts
      setState(() {
        _error = "$originalError. ${5 - _failedAttempts} attempts remaining.";
        _loading = false;
      });
    }
  }
    
  void _login() async { 
    // Prevent execution if currently locked out
    if (_lockoutEndTime != null && _lockoutEndTime!.isAfter(DateTime.now())) {
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final err = await context
          .read<AppProvider>()
          .login(_usernameCtrl.text.trim(), _passwordCtrl.text);

      if (!mounted) return;

      if (err != null) {
        await _handleFailedAttempt(err);
      } else {
        // Success! Reset security counters.
        await _resetLockout();
        setState(() => _loading = false);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()), 
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Database Crash: $e"; 
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputFillColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final inputBorderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    // Check if the UI should disable inputs based on lockout state
    final isLockedOut = _lockoutEndTime != null && _lockoutEndTime!.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // --- MAIN BACKGROUND ---
          Container(
             width: double.infinity,
             height: double.infinity,
             decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [const Color.fromARGB(255, 29, 29, 29), const Color.fromARGB(255, 48, 48, 48) ]
                  : [const Color.fromARGB(255, 48, 48, 48), const Color.fromARGB(255, 48, 48, 48)], 
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 600,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!isDark) 
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Image(image: AssetImage("assets/images/giyummy.png"), width: 150, height: 150),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'GIYUMMY STAFF LOGIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.red[800]! : Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(isLockedOut ? Icons.lock_clock : Icons.error_outline,
                                  color: isDark ? Colors.red[300] : Colors.red[700], size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: isDark ? Colors.red[300] : Colors.red[700], fontSize: 13, fontWeight: isLockedOut ? FontWeight.bold : FontWeight.normal)),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _usernameCtrl,
                        enabled: !isLockedOut,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          
                          labelText: 'Username',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.person_outline, color: subTextColor),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                        ],
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordCtrl,
                        enabled: !isLockedOut,
                        obscureText: _obscure,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.lock_outline, color: subTextColor),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility,
                                color: subTextColor),
                            onPressed: isLockedOut ? null : () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_loading || isLockedOut) ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : const Color.fromARGB(255, 31, 31, 31),
                            foregroundColor: isDark ? Colors.black :  Colors.white ,
                            disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                            disabledForegroundColor: isDark ? Colors.grey[500] : Colors.grey[500],
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(isLockedOut ? 'Locked' : 'Sign In',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text("Trouble signing in? Contact your administrator.", 
                          style: TextStyle(color: subTextColor)
                        )
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // --- THEME TOGGLE BUTTON (PINNED TO TOP RIGHT) ---
          Positioned(
            top: 32,
            right: 32,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                color: isDark ? Colors.yellow[400] : Colors.blueGrey[700],
                tooltip: 'Toggle Theme',
                onPressed: () {
                  context.read<AppProvider>().toggleTheme();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}