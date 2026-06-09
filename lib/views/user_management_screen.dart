import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED for input formatters
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

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  String _generateEmpId(String role, AppProvider provider) {
      String prefix;
      // 1. CHANGE PREFIXES HERE
      if (role == 'Admin' || role == 'Super Admin') {
        prefix = 'ADMN';
      } else if (role == 'Manager') {
        prefix = 'MNG';
      } else {
        prefix = 'EMP';
      }

      final now = DateTime.now();
      // 2. CHANGE DATE FORMAT HERE (Currently YYYYMM)
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}'; 

      final users = provider.getUsers();
      int maxIter = 0;
      
      // 3. CHANGE THE REGEX IF YOU REMOVE THE DATE
      final regex = RegExp('^$prefix-$dateStr-(\\d{3})\$');
      
      for (var u in users) {
        final match = regex.firstMatch(u.employeeId);
        if (match != null) {
          final iter = int.tryParse(match.group(1)!) ?? 0;
          if (iter > maxIter) maxIter = iter;
        }
      }

      // 4. CHANGE THE NUMBER LENGTH HERE (padLeft 3 means 001, padLeft 4 means 0001)
      final nextIter = (maxIter + 1).toString().padLeft(3, '0');
      
      // 5. CHANGE THE FINAL COMBINATION HERE
      return '$prefix-$dateStr-$nextIter'; 
    }
  void _showUserDialog(BuildContext context, [User? user]) {
    final isEditing = user != null;
    final provider = context.read<AppProvider>();
    final currentUserId = provider.currentUser?.id;
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

    // Generate initial ID if this is a brand new user
    if (!isEditing && empIdCtrl.text.isEmpty) {
      empIdCtrl.text = _generateEmpId(selectedRole, provider);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;
        final borderColor = isDark ? Colors.grey[700]! : Colors.grey[400]!;

        return StatefulBuilder(
          builder: (_, setDialogState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Row(
              children: [
                Icon(isEditing ? Icons.manage_accounts : Icons.person_add, color: isDark ? Colors.blue[400] : Colors.blue[700]),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit User: ${user.username}' : 'Add New User', style: TextStyle(color: textColor)),
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
                        decoration: BoxDecoration(color: isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.red[800]! : Colors.red[200]!)),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: isDark ? Colors.red[300] : Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: TextStyle(color: isDark ? Colors.red[200] : Colors.red[700]))),
                          ],
                        ),
                      ),
                    
                    Text('Personal Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(flex: 3, child: _field(fNameCtrl, 'First Name', isDark, maxLength: 60)),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: _field(miCtrl, 'M.I.', isDark, maxLength: 2)),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: _field(lNameCtrl, 'Last Name', isDark, maxLength: 60)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Make the Auto-Generated ID ReadOnly so it isn't accidentally modified
                    _field(empIdCtrl, 'Employee ID (Auto-Generated)', isDark),
                    
                    Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[200])),
                    
                    Text('System Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameCtrl,
                      maxLength: 50,
                      enabled: !isEditing,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                        isDense: true,
                        filled: isEditing,
                        fillColor: isEditing ? (isDark ? Colors.grey[900] : Colors.grey[100]) : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      maxLength: 50,
                      obscureText: true,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: isEditing ? 'New Password (Leave blank to keep current)' : 'Initial Password',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _field(emailCtrl, 'Email Address', isDark, maxLength: 100)),
                        const SizedBox(width: 12),
                        // Phone set to strictly accept numbers with type safety formatting
                        Expanded(child: _field(phoneCtrl, 'Phone Number', isDark, isNumber: true, maxLength: 15)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(child: _field(deptCtrl, 'Department', isDark, maxLength: 60)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedRole,
                            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'System Role', 
                              labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                              border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)), 
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                              isDense: true
                            ),
                            items: ['Admin', 'Manager', 'Employee'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: isCurrentUser ? null : (v) => setDialogState(() { 
                              selectedRole = v!;
                              // Re-generate ID if role swaps before saving a new user
                              if (!isEditing) {
                                empIdCtrl.text = _generateEmpId(selectedRole, provider);
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                    if (isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text('You cannot change your own role.', style: TextStyle(color: isDark ? Colors.orange[400] : Colors.orange[700], fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                    const SizedBox(height: 16),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[50], 
                        borderRadius: BorderRadius.circular(8), 
                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)
                      ),
                      child: SwitchListTile(
                        title: Text('Account Active', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        subtitle: Text(isActive ? 'User can log in to the system' : 'Account is currently disabled', style: TextStyle(color: isActive ? (isDark ? Colors.green[400] : Colors.green[700]) : (isDark ? Colors.red[400] : Colors.red[700]), fontSize: 12)),
                        value: isActive,
                        activeThumbColor: isDark ? Colors.blue[400] : Colors.blue[600],
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
                        child: Text('You cannot deactivate your own account.', style: TextStyle(color: isDark ? Colors.orange[400] : Colors.orange[700], fontSize: 12, fontStyle: FontStyle.italic)),
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
                style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700], foregroundColor: Colors.white),
                child: Text(isEditing ? 'Save Changes' : 'Create User'),
              ),
            ],
          )
        );
      }
    );
  }

  // --- UPGRADED HELPER WIDGET ---
  Widget _field(TextEditingController ctrl, String label, bool isDark, {int maxLines = 1, bool isNumber = false, bool readOnly = false, int? maxLength}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: !readOnly,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumber ? [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), 
      ] : null,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        border: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)), 
        filled: readOnly,
        fillColor: readOnly ? (isDark ? Colors.grey[800] : Colors.grey[100]) : null,
        isDense: true
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, MaterialColor color, bool isDark) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color[isDark ? 900 : 50]!.withOpacity(isDark ? 0.3 : 1.0), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: isDark ? color[400] : color[700], size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

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

    return Scaffold(
      backgroundColor: bgColor,
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
                    decoration: BoxDecoration(color: isDark ? Colors.blue[800] : Colors.blue[600], borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.manage_accounts, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                      const SizedBox(height: 4),
                      Text('Manage employee roles, access permissions, and account statuses.', style: TextStyle(fontSize: 15, color: subTextColor)),
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
                    _buildStatCard('Active Users', '$active', Icons.check_circle, Colors.green, isDark),
                    const SizedBox(width: 16),
                    _buildStatCard('Deactivated', '$inactive', Icons.cancel, Colors.red, isDark),
                    const SizedBox(width: 16),
                    _buildStatCard('System Admins', '$admins', Icons.admin_panel_settings, Colors.purple, isDark),
                    const SizedBox(width: 16),
                    _buildStatCard('Managers', '$managers', Icons.manage_accounts, Colors.blue, isDark),
                    const SizedBox(width: 16),
                    _buildStatCard('Employees', '$employees', Icons.badge, Colors.orange, isDark),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // --- MAIN DATA TABLE AREA ---
              Expanded(
                child: Container(
                  decoration: _cardDecoration(isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Text('Employee Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () => _showUserDialog(context, null),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add New User', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(isDark ? Colors.grey[900] : Colors.grey[50]),
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 60,
                                  horizontalMargin: 24,
                                  columns: [
                                    DataColumn(label: Text('EMP ID', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('FULL NAME', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('USERNAME', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('ROLE', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('DEPARTMENT', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('STATUS', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                    DataColumn(label: Text('ACTIONS', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                  rows: users.map((u) {
                                    // Identify if this row belongs to the currently logged-in user
                                    final isCurrentUser = u.id == currentUserId;
                                    
                                    final fullName = [u.firstName, u.middleInitial, u.lastName]
                                        .where((s) => s.isNotEmpty)
                                        .join(' ');

                                    return DataRow(cells: [
                                      DataCell(Text(u.employeeId.isEmpty ? 'N/A' : u.employeeId, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey))),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(fullName.isEmpty ? 'Not Set' : fullName, style: TextStyle(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal, color: textColor)),
                                            if (isCurrentUser) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: isDark ? Colors.blue[900]!.withOpacity(0.4) : Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                                                child: Text('You', style: TextStyle(color: isDark ? Colors.blue[200] : Colors.blue[800], fontSize: 10, fontWeight: FontWeight.bold)),
                                              )
                                            ]
                                          ],
                                        )
                                      ),
                                      DataCell(Text('@${u.username}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))),
                                      DataCell(Text(u.role, style: TextStyle(fontWeight: FontWeight.w600, color: textColor))), 
                                      DataCell(Text(u.department.isEmpty ? 'None' : u.department, style: TextStyle(color: textColor))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: u.isActive ? (isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50]) : (isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50]),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.circle, size: 8, color: u.isActive ? (isDark ? Colors.green[400] : Colors.green[500]) : (isDark ? Colors.red[400] : Colors.red[500])),
                                              const SizedBox(width: 6),
                                              Text(
                                                u.isActive ? 'Active' : 'Deactivated',
                                                style: TextStyle(color: u.isActive ? (isDark ? Colors.green[400] : Colors.green[700]) : (isDark ? Colors.red[400] : Colors.red[700]), fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: isDark ? Colors.blue[400] : Colors.blue, size: 20),
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