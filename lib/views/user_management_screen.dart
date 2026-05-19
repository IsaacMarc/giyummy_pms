import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/stat_card.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String? _error;

void _showUserDialog(BuildContext context, [User? user]) {
    final isEditing = user != null;
    
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
          title: Text(isEditing ? 'Edit User: ${user.username}' : 'Add New User'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  
                  TextField(
                    controller: usernameCtrl,
                    enabled: !isEditing,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: isEditing,
                      fillColor: isEditing ? Colors.grey[200] : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // FIX: Password field is now ALWAYS visible for Admins
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isEditing ? 'New Password (Leave blank to keep)' : 'Initial Password',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: deptCtrl,
                          decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder(), isDense: true),
                          items: ['Admin', 'Manager', 'Employee']
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedRole = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  SwitchListTile(
                    title: const Text('Account Active'),
                    subtitle: Text(isActive ? 'User can log in' : 'Account is disabled', style: TextStyle(color: isActive ? Colors.green : Colors.red)),
                    value: isActive,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (isEditing && user.id == context.read<AppProvider>().currentUser?.id) {
                        setDialogState(() => _error = "You cannot deactivate your own account.");
                        return;
                      }
                      setDialogState(() {
                        isActive = val;
                        _error = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
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
                  );
                  // FIX: Pass the new password to the provider if they typed one
                  await provider.updateUser(updatedUser, newPassword: passCtrl.text.trim());
                } else {
                  final err = await provider.adminAddUser(
                    username, 
                    emailCtrl.text.trim(), 
                    passCtrl.text, 
                    selectedRole, 
                    deptCtrl.text.trim(), 
                    phoneCtrl.text.trim()
                  );
                  if (err != null) {
                    setDialogState(() => _error = err);
                    return;
                  }
                }
                
                setState(() => _error = null);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save Changes' : 'Create User'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final users = provider.getUsers();
    final currentUserId = provider.currentUser?.id;

    // KPI Math
    final total = users.length;
    final active = users.where((u) => u.isActive).length;
    final inactive = total - active;
    final admins = users.where((u) => u.role == 'Admin').length;
    final managers = users.where((u) => u.role == 'Manager').length;
    final employees = users.where((u) => u.role == 'Employee').length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Horizontally Scrollable KPI Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 220, child: StatCard(title: 'Active Users', value: '$active', icon: Icons.check_circle, color: Colors.green, background_icon_color: Colors.green[100]!)),
                const SizedBox(width: 16),
                SizedBox(width: 220, child: StatCard(title: 'Deactivated', value: '$inactive', icon: Icons.cancel, color: Colors.red, background_icon_color: Colors.red[100]!)),
                const SizedBox(width: 16),
                SizedBox(width: 220, child: StatCard(title: 'System Admins', value: '$admins', icon: Icons.admin_panel_settings, color: Colors.purple, background_icon_color: Colors.purple[100]!)),
                const SizedBox(width: 16),
                SizedBox(width: 220, child: StatCard(title: 'Managers', value: '$managers', icon: Icons.manage_accounts, color: Colors.blue, background_icon_color: Colors.blue[100]!)),
                const SizedBox(width: 16),
                SizedBox(width: 220, child: StatCard(title: 'Employees', value: '$employees', icon: Icons.badge, color: Colors.orange, background_icon_color: Colors.orange[100]!)),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // 2. Main Data Table Area
          Expanded(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('User Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _showUserDialog(context, null),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                            columns: const [
                              DataColumn(label: Text('Username')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Department')),
                              DataColumn(label: Text('Contact')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Last Login')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: users.map((u) {
                              final isSelf = u.id == currentUserId;
                              final loginTime = u.lastLogin != null
                                  ? DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(u.lastLogin!))
                                  : 'Never';

                              return DataRow(cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(u.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      if (isSelf) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                                          child: const Text('You', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                                DataCell(Text(u.role, style: TextStyle(
                                    fontWeight: u.role == 'Admin' ? FontWeight.bold : FontWeight.normal,
                                    color: u.role == 'Admin' ? Colors.purple[700] : Colors.black87))),
                                DataCell(Text(u.department.isEmpty ? '-' : u.department)),
                                DataCell(Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (u.email.isNotEmpty) Text(u.email, style: const TextStyle(fontSize: 12)),
                                    if (u.phone.isNotEmpty) Text(u.phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    if (u.email.isEmpty && u.phone.isEmpty) const Text('-')
                                  ],
                                )),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: u.isActive ? Colors.green[50] : Colors.red[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: u.isActive ? Colors.green[200]! : Colors.red[200]!),
                                    ),
                                    child: Text(
                                      u.isActive ? 'Active' : 'Deactivated',
                                      style: TextStyle(color: u.isActive ? Colors.green[700] : Colors.red[700], fontSize: 12),
                                    ),
                                  ),
                                ),
                                DataCell(Text(loginTime, style: const TextStyle(fontSize: 13))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                        tooltip: 'Edit User',
                                        onPressed: () => _showUserDialog(context, u),
                                      ),
                                      if (!isSelf)
                                        IconButton(
                                          icon: Icon(
                                            u.isActive ? Icons.block : Icons.check_circle_outline,
                                            color: u.isActive ? Colors.red : Colors.green,
                                            size: 18,
                                          ),
                                          tooltip: u.isActive ? 'Deactivate' : 'Reactivate',
                                          onPressed: () => provider.toggleUserStatus(u.id),
                                        ),
                                    ],
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}