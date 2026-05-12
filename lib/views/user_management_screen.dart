import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:product_management/providers/app_provider.dart';
import 'package:product_management/models/models.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final users = provider.getUsers();
    final currentUser = provider.currentUser;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('User Management',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  Text('${users.length} users',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(Colors.grey[50]),
                      columns: const [
                        DataColumn(label: Text('Username')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Department')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: users.map((u) {
                        final isSelf = u.id == currentUser?.id;
                        return DataRow(cells: [
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  u.username[0].toUpperCase(),
                                  style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(u.username,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          )),
                          DataCell(Text(u.email)),
                          DataCell(_roleBadge(u.role)),
                          DataCell(Text(u.department)),
                          DataCell(_statusBadge(u.isActive)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isSelf) ...[
                                IconButton(
                                  icon: Icon(
                                    u.isActive
                                        ? Icons.toggle_on_outlined
                                        : Icons.toggle_off_outlined,
                                    color: u.isActive
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 22,
                                  ),
                                  onPressed: () =>
                                      provider.toggleUserStatus(u.id),
                                  tooltip: u.isActive
                                      ? 'Deactivate'
                                      : 'Activate',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 18),
                                  onPressed: () =>
                                      _confirmDelete(context, u, provider),
                                  tooltip: 'Delete',
                                ),
                              ] else
                                Text('(You)',
                                    style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12)),
                            ],
                          )),
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
    );
  }

  void _confirmDelete(
      BuildContext context, User user, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete "${user.username}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              provider.deleteUser(user.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    final colors = {
      'Admin': Colors.purple,
      'Manager': Colors.blue,
      'Employee': Colors.grey,
    };
    final color = colors[role] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(role,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
            color: isActive ? Colors.green[700] : Colors.red[700],
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
