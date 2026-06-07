import 'package:flutter/material.dart';
import 'package:product_management/views/login_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _empIdCtrl = TextEditingController();
  final _fNameCtrl = TextEditingController();
  final _miCtrl = TextEditingController();
  final _lNameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  String? _error;
  bool _isLoading = false;

void _setupSuperAdmin() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty || _fNameCtrl.text.isEmpty || _lNameCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill out all required fields.');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _error = null; 
      _isLoading = true;
    });
    
    try {
      final provider = context.read<AppProvider>();
      final err = await provider.adminAddUser(
        _userCtrl.text.trim(), 
        '', 
        _passCtrl.text, 
        'Admin', 
        'Administration', 
        '', 
        _empIdCtrl.text.trim(),
        _fNameCtrl.text.trim(),
        _miCtrl.text.trim(),
        _lNameCtrl.text.trim(),
      );

      if (!mounted) return;

      if (err != null) {
        setState(() {
          _error = err;
          _isLoading = false;
        });
      } else {
        // SUCCESS: Stop the spinner and route to Login Screen
        if (mounted) {
          setState(() => _isLoading = false);
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Database Crash: $e";
        _isLoading = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SizedBox(
          width: 500,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings, size: 64, color: Colors.blue[800]),
                  const SizedBox(height: 16),
                  const Text('System Initialization', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Create the Super Admin account to begin.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      color: Colors.red[50],
                      child: Text(_error!, style: TextStyle(color: Colors.red[800])),
                    ),

                  Row(
                    children: [
                      Expanded(flex: 3, child: _field(_fNameCtrl, 'First Name *')),
                      const SizedBox(width: 8),
                      Expanded(flex: 1, child: _field(_miCtrl, 'M.I.')),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: _field(_lNameCtrl, 'Last Name *')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field(_empIdCtrl, 'Employee ID / Badge Number'),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _field(_userCtrl, 'Admin Username *'),
                  const SizedBox(height: 16),
                  _field(_passCtrl, 'Master Password *', isPassword: true),
                  const SizedBox(height: 16),
                  _field(_confirmCtrl, 'Confirm Password *', isPassword: true),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _setupSuperAdmin,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('Initialize System', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool isPassword = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}