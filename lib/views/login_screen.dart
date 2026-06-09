import 'package:flutter/material.dart';
import 'package:product_management/views/dashboard_screen.dart';
import 'package:product_management/views/register_screen.dart';
import 'package:provider/provider.dart';
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

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkSystemInitialization();
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
    
  void _login() async { 
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
        setState(() {
          _error = err; 
          _loading = false;
        });
      } else {
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Use a Stack so we can easily pin the toggle button to the top right
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
                  : [const Color.fromARGB(255, 48, 48, 48), const Color.fromARGB(255, 48, 48, 48)], // Light mode gradient
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 600,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: cardColor, // Adapts to theme
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!isDark) // Only show heavy shadow in light mode
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
                              Icon(Icons.error_outline,
                                  color: isDark ? Colors.red[300] : Colors.red[700], size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: isDark ? Colors.red[300] : Colors.red[700], fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _usernameCtrl,
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
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                        ],
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordCtrl,
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
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility,
                                color: subTextColor),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : const Color.fromARGB(255, 31, 31, 31),
                            foregroundColor: isDark ? Colors.black :  Colors.white ,
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
                              : const Text('Sign In',
                                  style: TextStyle(
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