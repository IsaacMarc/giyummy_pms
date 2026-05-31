import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String? _error;

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[200]!),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  void _showUserDialog(BuildContext context, [User? user]) {
    final isEditing = user != null;
    final currentUserId = context.read<AppProvider>().currentUser?.id;
    final isCurrentUser = isEditing && user.id == currentUserId;
    
    final empIdCtrl = TextEditingController(text: user?.employeeId ?? '');
    final fNameCtrl = TextEditingController(text: user?.firstName ?? '');
    final miCtrl = TextEditingController(text: user?.middleInitial ?? '');
    final lNameCtrl = TextEditingController(text: user?.lastName ?? '');
    
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final deptCtrl = TextEditingController(text: user?.department ?? '');
    final passCtrl = TextEditingController(); 
    
    String selectedRole = user?.role ?? 'Employee';
    bool isActive = user?.isActive ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(isEditing ? Icons.manage_accounts : Icons.person_add, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(isEditing ? 'Edit User: ${user.username}' : 'Add New User'),
            ],
          ),
          content: SizedBox(
            width: 500, 
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700]))),
                        ],
                      ),
                    ),
                  
                  const Text('Personal Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(flex: 3, child: _field(fNameCtrl, 'First Name')),
                      const SizedBox(width: 8),
                      Expanded(flex: 1, child: _field(miCtrl, 'M.I.')),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: _field(lNameCtrl, 'Last Name')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(empIdCtrl, 'Employee ID'),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                  
                  const Text('System Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameCtrl,
                    enabled: !isEditing,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: isEditing,
                      fillColor: isEditing ? Colors.grey[100] : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isEditing ? 'New Password (Leave blank to keep current)' : 'Initial Password',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(emailCtrl, 'Email Address')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(phoneCtrl, 'Phone Number')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(child: _field(deptCtrl, 'Department')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(labelText: 'System Role', border: OutlineInputBorder(), isDense: true),
                          items: ['Admin', 'Manager', 'Employee'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: isCurrentUser ? null : (v) => setDialogState(() => selectedRole = v!), // Prevent changing own role
                        ),
                      ),
                    ],
                  ),
                  if (isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Text('You cannot change your own role.', style: TextStyle(color: Colors.orange[700], fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
                    child: SwitchListTile(
                      title: const Text('Account Active', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isActive ? 'User can log in to the system' : 'Account is currently disabled', style: TextStyle(color: isActive ? Colors.green[700] : Colors.red[700], fontSize: 12)),
                      value: isActive,
                      onChanged: isCurrentUser ? null : (val) { // Prevent disabling own account
                        setDialogState(() {
                          isActive = val;
                          _error = null;
                        });
                      },
                    ),
                  ),
                  if (isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Text('You cannot deactivate your own account.', style: TextStyle(color: Colors.orange[700], fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _error = null);
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final username = usernameCtrl.text.trim();
                if (username.isEmpty || (!isEditing && passCtrl.text.isEmpty)) {
                  setDialogState(() => _error = 'Username and Password are required.');
                  return;
                }

                final provider = context.read<AppProvider>();

                if (isEditing) {
                  final updatedUser = User(
                    id: user.id,
                    username: user.username,
                    passwordHash: user.passwordHash,
                    role: selectedRole,
                    email: emailCtrl.text.trim(),
                    createdAt: user.createdAt,
                    lastLogin: user.lastLogin,
                    isActive: isActive,
                    department: deptCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    employeeId: empIdCtrl.text.trim(),
                    firstName: fNameCtrl.text.trim(),
                    middleInitial: miCtrl.text.trim(),
                    lastName: lNameCtrl.text.trim(),
                  );
                  await provider.updateUser(updatedUser, newPassword: passCtrl.text.trim());
                } else {
                  final err = await provider.adminAddUser(
                    username, 
                    emailCtrl.text.trim(), 
                    passCtrl.text, 
                    selectedRole, 
                    deptCtrl.text.trim(), 
                    phoneCtrl.text.trim(),
                    empIdCtrl.text.trim(),
                    fNameCtrl.text.trim(),
                    miCtrl.text.trim(),
                    lNameCtrl.text.trim(),
                  );
                  if (err != null) {
                    setDialogState(() => _error = err);
                    return;
                  }
                }
                
                setState(() => _error = null);
                if (context.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
              child: Text(isEditing ? 'Save Changes' : 'Create User'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final users = provider.getUsers();
    final currentUserId = provider.currentUser?.id; // Now actively used to highlight the logged-in user

    // KPI Math
    final total = users.length;
    final active = users.where((u) => u.isActive).length;
    final inactive = total - active;
    final admins = users.where((u) => u.role == 'Admin').length;
    final managers = users.where((u) => u.role == 'Manager').length;
    final employees = users.where((u) => u.role == 'Employee').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.manage_accounts, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
                      const SizedBox(height: 4),
                      Text('Manage employee roles, access permissions, and account statuses.', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- HORIZONTAL KPI CARDS ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatCard('Active Users', '$active', Icons.check_circle, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard('Deactivated', '$inactive', Icons.cancel, Colors.red),
                    const SizedBox(width: 16),
                    _buildStatCard('System Admins', '$admins', Icons.admin_panel_settings, Colors.purple),
                    const SizedBox(width: 16),
                    _buildStatCard('Managers', '$managers', Icons.manage_accounts, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard('Employees', '$employees', Icons.badge, Colors.orange),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // --- MAIN DATA TABLE AREA ---
              Expanded(
                child: Container(
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const Text('Employee Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () => _showUserDialog(context, null),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add New User', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 60,
                                  horizontalMargin: 24,
                                  columns: [
                                    DataColumn(label: Text('EMP ID', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('FULL NAME', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('USERNAME', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('ROLE', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('DEPARTMENT', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('STATUS', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('ACTIONS', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                  rows: users.map((u) {
                                    // Identify if this row belongs to the currently logged-in user
                                    final isCurrentUser = u.id == currentUserId;
                                    
                                    final fullName = [u.firstName, u.middleInitial, u.lastName]
                                        .where((s) => s.isNotEmpty)
                                        .join(' ');

                                    return DataRow(cells: [
                                      DataCell(Text(u.employeeId.isEmpty ? 'N/A' : u.employeeId, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey))),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(fullName.isEmpty ? 'Not Set' : fullName, style: TextStyle(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal)),
                                            if (isCurrentUser) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                                                child: Text('You', style: TextStyle(color: Colors.blue[800], fontSize: 10, fontWeight: FontWeight.bold)),
                                              )
                                            ]
                                          ],
                                        )
                                      ),
                                      DataCell(Text('@${u.username}', style: TextStyle(color: Colors.grey[600]))),
                                      DataCell(Text(u.role, style: const TextStyle(fontWeight: FontWeight.w600))), 
                                      DataCell(Text(u.department.isEmpty ? 'None' : u.department)),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: u.isActive ? Colors.green[50] : Colors.red[50],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.circle, size: 8, color: u.isActive ? Colors.green[500] : Colors.red[500]),
                                              const SizedBox(width: 6),
                                              Text(
                                                u.isActive ? 'Active' : 'Deactivated',
                                                style: TextStyle(color: u.isActive ? Colors.green[700] : Colors.red[700], fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                          onPressed: () => _showUserDialog(context, u),
                                          tooltip: 'Edit User',
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}