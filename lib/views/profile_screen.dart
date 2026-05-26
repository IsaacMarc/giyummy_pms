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

    // Populate controllers if they are empty
    if (_fNameCtrl.text.isEmpty && user.firstName.isNotEmpty) _fNameCtrl.text = user.firstName;
    if (_miCtrl.text.isEmpty && user.middleInitial.isNotEmpty) _miCtrl.text = user.middleInitial;
    if (_lNameCtrl.text.isEmpty && user.lastName.isNotEmpty) _lNameCtrl.text = user.lastName;
    if (_emailCtrl.text.isEmpty && user.email.isNotEmpty) _emailCtrl.text = user.email;
    if (_phoneCtrl.text.isEmpty && user.phone.isNotEmpty) _phoneCtrl.text = user.phone;
    if (_deptCtrl.text.isEmpty && user.department.isNotEmpty) _deptCtrl.text = user.department;

    final joinDate = DateFormat('MMMM dd, yyyy').format(DateTime.parse(user.createdAt));
    final lastLoginStr = user.lastLogin != null 
        ? DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.parse(user.lastLogin!))
        : 'First Login';

    // Safely construct the full name for the header
    final fullName = [user.firstName, user.middleInitial, user.lastName]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final displayName = fullName.isNotEmpty ? fullName : user.username;

    return DefaultTabController(
      length: 2, 
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '@${user.username}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user.role == 'Admin' ? Colors.purple[50] : Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: user.role == 'Admin' ? Colors.purple[200]! : Colors.blue[200]!),
                                ),
                                child: Text(
                                  user.role,
                                  style: TextStyle(
                                    color: user.role == 'Admin' ? Colors.purple[700] : Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (user.employeeId.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.badge, size: 14, color: Colors.grey[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ID: ${user.employeeId}',
                                        style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Icon(Icons.business, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(user.department.isNotEmpty ? user.department : 'No Department', style: TextStyle(color: Colors.grey[700])),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Card(
                elevation: 2,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: const TabBar(
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue,
                        tabs: [
                          Tab(icon: Icon(Icons.person_outline), text: 'Overview'),
                          Tab(icon: Icon(Icons.info_outline), text: 'Account Status'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // 1. OVERVIEW TAB
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Update your name, contact details, and internal department assignments.', style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(height: 24),
                                
                                if (_overviewMsg != null) _statusBanner(_overviewMsg!, true),
                                if (_overviewErr != null) _statusBanner(_overviewErr!, false),
                                
                                // --- NEW: Name Editing Row ---
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _fNameCtrl,
                                        decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: _miCtrl,
                                        decoration: const InputDecoration(labelText: 'M.I.', border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _lNameCtrl,
                                        decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _emailCtrl,
                                        decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneCtrl,
                                        decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width / 2.3,
                                  child: TextField(
                                    controller: _deptCtrl,
                                    decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business_outlined)),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _updateProfile,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save Changes'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                  ),
                                )
                              ],
                            ),
                          ),

                          // 2. ACCOUNT STATUS TAB
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('System Access & Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Overview of your system privileges and activity history.', style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(height: 24),

                                _infoRow(Icons.verified_user_outlined, 'Account Status', user.isActive ? 'Active & Healthy' : 'Deactivated', user.isActive ? Colors.green : Colors.red),
                                const Divider(height: 32),
                                _infoRow(Icons.calendar_today_outlined, 'Date Joined', joinDate, Colors.black87),
                                const Divider(height: 32),
                                _infoRow(Icons.login_outlined, 'Last Login', lastLoginStr, Colors.black87),
                                const Divider(height: 32),
                                _infoRow(Icons.badge_outlined, 'Employee ID', user.employeeId.isNotEmpty ? user.employeeId : 'Not Assigned', Colors.black87),
                                const Divider(height: 32),
                                _infoRow(Icons.admin_panel_settings_outlined, 'System Role', user.role, Colors.black87),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(String message, bool isSuccess) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSuccess ? Colors.green[200]! : Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline, color: isSuccess ? Colors.green[700] : Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: isSuccess ? Colors.green[700] : Colors.red[700]))),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value, Color valueColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
          child: Icon(icon, color: Colors.blue[700]),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
          ],
        )
      ],
    );
  }
}