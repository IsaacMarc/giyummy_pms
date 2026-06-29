import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; 
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 1. Store Details
  final _storeNameCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _storeContactCtrl = TextEditingController();

  // 2. Network
  final _serverIpCtrl = TextEditingController();
  bool _isTestingNetwork = false;

  // 4. System Preferences
  String _defaultTab = 'dashboard'; // Default route key
  int _sessionTimeout = 15;

  bool _isLoading = true;

  // Map friendly names to actual route keys
  final Map<String, String> _tabOptions = {
    'Dashboard': 'dashboard',
    'Sales / POS': 'sales',
    'Inventory': 'inventory',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _storeAddressCtrl.dispose();
    _storeContactCtrl.dispose();
    _serverIpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeNameCtrl.text = prefs.getString('storeName') ?? 'GiYummy Main Branch';
      _storeAddressCtrl.text = prefs.getString('storeAddress') ?? '';
      _storeContactCtrl.text = prefs.getString('storeContact') ?? '';
      
      _serverIpCtrl.text = prefs.getString('serverIp') ?? '127.0.0.1';
      
      // Ensure the loaded value is a valid route key, fallback to 'dashboard'
      final savedTab = prefs.getString('defaultTab') ?? 'dashboard';
      if (_tabOptions.values.contains(savedTab)) {
        _defaultTab = savedTab;
      } else {
        _defaultTab = 'dashboard';
      }

      _sessionTimeout = prefs.getInt('sessionTimeout') ?? 15;
      
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('storeName', _storeNameCtrl.text.trim());
    await prefs.setString('storeAddress', _storeAddressCtrl.text.trim());
    await prefs.setString('storeContact', _storeContactCtrl.text.trim());
    
    await prefs.setString('serverIp', _serverIpCtrl.text.trim());
    
    await prefs.setString('defaultTab', _defaultTab);
    await prefs.setInt('sessionTimeout', _sessionTimeout);

    if (!mounted) return;

    // ---> THIS IS THE FIX: Tell AppProvider to refresh the store details instantly! <---
    await context.read<AppProvider>().loadSystemSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green)
    );
  }

  // Pure Dart Socket Ping to test the MySQL Port (3306)
  Future<void> _testNetworkConnection() async {
    setState(() => _isTestingNetwork = true);
    
    final ip = _serverIpCtrl.text.trim();
    try {
      // Tries to knock on the MySQL port. Times out after 3 seconds.
      final socket = await Socket.connect(ip, 3306, timeout: const Duration(seconds: 3));
      socket.destroy(); // Connection successful, hang up immediately
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Successful! Found Database at $ip'), backgroundColor: Colors.green)
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Failed: Cannot reach $ip on port 3306'), backgroundColor: Colors.red)
      );
    } finally {
      setState(() => _isTestingNetwork = false);
    }
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.blue[400] : Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, bool isDark, {bool isNumber = false, String? prefixText, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefixText,
          prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final currentUser = context.watch<AppProvider>().currentUser;
    final isAdmin = currentUser?.role == 'Admin' || currentUser?.role == 'Super Admin';

    if (_isLoading) {
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? Colors.blue[800] : Colors.blue[600], borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.settings, size: 32, color: Colors.white),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('System Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                          const SizedBox(height: 4),
                          Text('Configure store details, network routing, and preferences.', style: TextStyle(fontSize: 15, color: subTextColor)),
                        ],
                      ),
                    ],
                  ),
                  if (isAdmin)
                    ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Configurations', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN (Restricted to Admins) ---
                  if (isAdmin)
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // 1. STORE DETAILS
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: _cardDecoration(isDark),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Store & Receipt Details', Icons.storefront, isDark),
                                const SizedBox(height: 16),
                                _buildTextField(_storeNameCtrl, 'Store Name', isDark),
                                _buildTextField(_storeAddressCtrl, 'Store Address (Prints on Receipts)', isDark, maxLines: 2),
                                _buildTextField(_storeContactCtrl, 'Contact Email / Phone', isDark),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 2. NETWORK & DATABASE
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: _cardDecoration(isDark),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('LAN Database Routing', Icons.router, isDark),
                                Text('Set this to the IP Address of the Main Server PC. If this PC is the server, use 127.0.0.1', style: TextStyle(color: subTextColor, fontSize: 12)),
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildTextField(_serverIpCtrl, 'MariaDB Target IP', isDark),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: SizedBox(
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: _isTestingNetwork ? null : _testNetworkConnection,
                                          icon: _isTestingNetwork 
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                                              : const Icon(Icons.wifi_tethering),
                                          label: const Text('Ping Server'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark ? Colors.blue[400] : Colors.blue[700],
                                            side: BorderSide(color: isDark ? Colors.blue[900]! : Colors.blue[200]!)
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (isAdmin) const SizedBox(width: 24),

                  // --- RIGHT COLUMN (Visible to Everyone) ---
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: _cardDecoration(isDark),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('System Preferences', Icons.display_settings, isDark),
                          const SizedBox(height: 16),
                          
                          // Theme Toggle (Available to all)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Global Application Theme', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            subtitle: Text('Switch between Light and Dark mode interfaces.', style: TextStyle(color: subTextColor, fontSize: 12)),
                            trailing: Switch(
                              value: isDark,
                              activeThumbColor: Colors.blue[400],
                              onChanged: (val) {
                                context.read<AppProvider>().toggleTheme();
                              },
                            ),
                          ),
                          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 32),

                          // Layout Preferences (Admins Only)
                          if (isAdmin) ...[
                            Text('Default Start Screen', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _defaultTab,
                              dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)),
                                isDense: true
                              ),
                              items: _tabOptions.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
                              onChanged: (v) => setState(() => _defaultTab = v!),
                            ),
                            const SizedBox(height: 24),

                            Text('Security: Auto-Logout Timeout', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            Text('Lock the terminal after inactivity (Minutes)', style: TextStyle(color: subTextColor, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _sessionTimeout.toDouble(),
                                    min: 5,
                                    max: 60,
                                    divisions: 11,
                                    label: '$_sessionTimeout mins',
                                    activeColor: isDark ? Colors.blue[400] : Colors.blue[600],
                                    onChanged: (val) => setState(() => _sessionTimeout = val.toInt()),
                                  ),
                                ),
                                Container(
                                  width: 60,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                  child: Text('$_sessionTimeout', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                )
                              ],
                            ),
                          ],
                          
                          if (!isAdmin)
                             Padding(
                               padding: const EdgeInsets.only(top: 24),
                               child: Text('Note: Advanced store and network configurations are restricted to Administrators.', style: TextStyle(color: Colors.orange[700], fontStyle: FontStyle.italic, fontSize: 13)),
                             )
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}