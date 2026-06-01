import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _fNameCtrl;
  late TextEditingController _miCtrl;
  late TextEditingController _lNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _deptCtrl;

  String? _overviewMsg;
  String? _overviewErr;

  @override
  void initState() {
    super.initState();
    _fNameCtrl = TextEditingController();
    _miCtrl = TextEditingController();
    _lNameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _deptCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _fNameCtrl.dispose();
    _miCtrl.dispose();
    _lNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  void _updateProfile() async {
    final provider = context.read<AppProvider>();
    final err = await provider.updateProfile(
      firstName: _fNameCtrl.text.trim(),
      middleInitial: _miCtrl.text.trim(),
      lastName: _lNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      department: _deptCtrl.text.trim(),
    );

    setState(() {
      if (err != null) {
        _overviewErr = err;
        _overviewMsg = null;
      } else {
        _overviewMsg = 'Profile updated successfully!';
        _overviewErr = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view profile.'));
    }

    // --- DYNAMIC THEME VARIABLES ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    BoxDecoration cardDecoration() {
      return BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      );
    }

    if (_fNameCtrl.text.isEmpty && user.firstName.isNotEmpty) _fNameCtrl.text = user.firstName;
    if (_miCtrl.text.isEmpty && user.middleInitial.isNotEmpty) _miCtrl.text = user.middleInitial;
    if (_lNameCtrl.text.isEmpty && user.lastName.isNotEmpty) _lNameCtrl.text = user.lastName;
    if (_emailCtrl.text.isEmpty && user.email.isNotEmpty) _emailCtrl.text = user.email;
    if (_phoneCtrl.text.isEmpty && user.phone.isNotEmpty) _phoneCtrl.text = user.phone;
    if (_deptCtrl.text.isEmpty && user.department.isNotEmpty) _deptCtrl.text = user.department;

    final joinDate = DateFormat('MMMM dd, yyyy').format(DateTime.parse(user.createdAt));
    final lastLoginStr = user.lastLogin != null ? DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.parse(user.lastLogin!)) : 'First Login';
    final fullName = [user.firstName, user.middleInitial, user.lastName].where((s) => s.isNotEmpty).join(' ');
    final displayName = fullName.isNotEmpty ? fullName : user.username;

    Widget infoRow(IconData icon, String title, String value, Color valueColor) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50], borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: isDark ? Colors.blue[300] : Colors.blue[700]),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
            ],
          )
        ],
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: DefaultTabController(
        length: 2, 
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP PROFILE HEADER ---
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue[600],
                      child: Text(displayName.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                          const SizedBox(height: 4),
                          Text('@${user.username}', style: TextStyle(fontSize: 15, color: subTextColor, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: user.role == 'Admin' ? (isDark ? Colors.purple[900]!.withOpacity(0.3) : Colors.purple[50]) : (isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50]),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: user.role == 'Admin' ? (isDark ? Colors.purple[700]! : Colors.purple[200]!) : (isDark ? Colors.blue[700]! : Colors.blue[200]!)),
                                ),
                                child: Text(user.role, style: TextStyle(color: user.role == 'Admin' ? (isDark ? Colors.purple[300] : Colors.purple[700]) : (isDark ? Colors.blue[300] : Colors.blue[700]), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              if (user.employeeId.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
                                  child: Row(
                                    children: [
                                      Icon(Icons.badge, size: 14, color: subTextColor),
                                      const SizedBox(width: 6),
                                      Text('ID: ${user.employeeId}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Icon(Icons.business, size: 16, color: subTextColor),
                              const SizedBox(width: 6),
                              Text(user.department.isNotEmpty ? user.department : 'No Department', style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- CUSTOM PILL TAB BAR ---
                Container(
                  height: 50,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                    labelColor: isDark ? Colors.white : Colors.blue[800],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    unselectedLabelColor: subTextColor,
                    tabs: const [
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_outline, size: 18), SizedBox(width: 8), Text('Overview & Edit')])),
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_outlined, size: 18), SizedBox(width: 8), Text('Account Status')])),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- TAB VIEWS ---
                Expanded(
                  child: TabBarView(
                    children: [
                      // 1. OVERVIEW TAB
                      SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          decoration: cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 8),
                              Text('Update your name, contact details, and internal department assignments.', style: TextStyle(color: subTextColor)),
                              const SizedBox(height: 32),
                              
                              if (_overviewMsg != null) Container(
                                padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(color: isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.green[700]! : Colors.green[200]!)),
                                child: Row(children: [Icon(Icons.check_circle_outline, color: isDark ? Colors.green[300] : Colors.green[700]), const SizedBox(width: 12), Expanded(child: Text(_overviewMsg!, style: TextStyle(color: isDark ? Colors.green[300] : Colors.green[700], fontWeight: FontWeight.w600)))])
                              ),
                              if (_overviewErr != null) Container(
                                padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(color: isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.red[700]! : Colors.red[200]!)),
                                child: Row(children: [Icon(Icons.error_outline, color: isDark ? Colors.red[300] : Colors.red[700]), const SizedBox(width: 12), Expanded(child: Text(_overviewErr!, style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontWeight: FontWeight.w600)))])
                              ),
                              
                              Row(
                                children: [
                                  Expanded(flex: 3, child: TextField(controller: _fNameCtrl, decoration: InputDecoration(labelText: 'First Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.person_outline), isDense: true))),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 1, child: TextField(controller: _miCtrl, decoration: InputDecoration(labelText: 'M.I.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true))),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 3, child: TextField(controller: _lNameCtrl, decoration: InputDecoration(labelText: 'Last Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true))),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              Row(
                                children: [
                                  Expanded(child: TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.email_outlined), isDense: true))),
                                  const SizedBox(width: 16),
                                  Expanded(child: TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.phone_outlined), isDense: true))),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 2.3,
                                child: TextField(controller: _deptCtrl, decoration: InputDecoration(labelText: 'Department', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.business_outlined), isDense: true)),
                              ),
                              const SizedBox(height: 32),
                              
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: _updateProfile,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), backgroundColor: Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),

                      // 2. ACCOUNT STATUS TAB
                      SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          decoration: cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('System Access & Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 8),
                              Text('Overview of your system privileges and activity history.', style: TextStyle(color: subTextColor)),
                              const SizedBox(height: 32),

                              infoRow(Icons.verified_user_outlined, 'Account Status', user.isActive ? 'Active & Healthy' : 'Deactivated', user.isActive ? Colors.green[500]! : Colors.red[500]!),
                              Divider(height: 40, color: borderColor),
                              infoRow(Icons.calendar_today_outlined, 'Date Joined', joinDate, textColor),
                              Divider(height: 40, color: borderColor),
                              infoRow(Icons.login_outlined, 'Last Login', lastLoginStr, textColor),
                              Divider(height: 40, color: borderColor),
                              infoRow(Icons.badge_outlined, 'Employee ID', user.employeeId.isNotEmpty ? user.employeeId : 'Not Assigned', textColor),
                              Divider(height: 40, color: borderColor),
                              infoRow(Icons.admin_panel_settings_outlined, 'System Role', user.role, textColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}