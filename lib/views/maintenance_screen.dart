import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart'; // NEW: Imported the file picker
import '../providers/app_provider.dart';
import '../models/models.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final logs = provider.getAuditLogs();
    final backups = provider.getBackups();
    final dtFmt = DateFormat('MMM d, y HH:mm:ss');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Statistics Row
          Row(
            children: [
              _buildStatCard('Total Users', provider.getUsers().length.toString(), Icons.people_outline, Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard('Total Inventory', provider.getProducts().length.toString(), Icons.inventory_2_outlined, Colors.orange),
              const SizedBox(width: 16),
              _buildStatCard('Total Sales', provider.getSales().length.toString(), Icons.point_of_sale, Colors.green),
              const SizedBox(width: 16),
              _buildStatCard('Recent Logs', logs.length.toString(), Icons.history, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Backup & Restore Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined, color: Colors.blue[700], size: 22),
                      const SizedBox(width: 8),
                      const Text('Backup & Restore',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      
                      // 1. UPDATED BUTTON: Now triggers the file explorer picker
                      OutlinedButton.icon(
                        onPressed: () => _pickAndRestoreFile(context, provider),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Restore Backup'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
                      ),
                      const SizedBox(width: 12),
                      
                      ElevatedButton.icon(
                        onPressed: () => _createBackup(context, provider),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Create Backup'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                  if (backups.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Recent Backups',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...backups.reversed.take(5).map((b) {
                      DateTime? t;
                      try {
                        t = DateTime.parse(b.timestamp);
                      } catch (_) {}
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.folder_zip_outlined, size: 20),
                        title: Text(b.filename, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            t != null ? dtFmt.format(t) : b.timestamp,
                            style: const TextStyle(fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(b.size / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            // Quick restore from the internal list
                            IconButton(
                              icon: const Icon(Icons.restore, color: Colors.orange),
                              tooltip: 'Restore this backup',
                              onPressed: () => _confirmInternalRestore(context, provider, b),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Audit Log Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_outlined, color: Colors.blue[700], size: 22),
                      const SizedBox(width: 8),
                      const Text('Audit Logs',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      Text('Last ${logs.length} entries',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 44,
                      columns: const [
                        DataColumn(label: Text('Timestamp')),
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('Module')),
                        DataColumn(label: Text('Details')),
                      ],
                      rows: logs.map((log) {
                        DateTime? t;
                        try {
                          t = DateTime.parse(log.timestamp);
                        } catch (_) {}
                        return DataRow(cells: [
                          DataCell(Text(
                              t != null ? dtFmt.format(t) : log.timestamp,
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(log.username,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          DataCell(_actionBadge(log.action)),
                          DataCell(Text(log.module, style: const TextStyle(fontSize: 12))),
                          DataCell(SizedBox(
                            width: 250,
                            child: Text(log.details,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                  if (logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text('No audit logs yet.', style: TextStyle(color: Colors.grey[400])),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. NEW: Native File Explorer Logic ---
  void _pickAndRestoreFile(BuildContext context, AppProvider provider) async {
    // Opens the native Windows/macOS file picker
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'], // Only allow them to click .json files
      dialogTitle: 'Select Database Backup File',
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      final filePath = result.files.single.path!;
      final filename = result.files.single.name;
      
      // If they selected a file, show the critical warning
      _confirmExternalRestore(context, provider, filename, filePath);
    }
  }

  // Warning dialog for external file selection
  void _confirmExternalRestore(BuildContext context, AppProvider provider, String filename, String filePath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('CRITICAL WARNING', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(
          'Are you sure you want to restore from "$filename"?\n\n'
          'This will permanently overwrite ALL current users, inventory, and sales data in the system with the data inside this file. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('OVERWRITE DATA'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restoring system data...')),
          );

          // FIX: Use restoreBackupFromPath and pass BOTH the full path and the name
          final error = await provider.restoreBackupFromPath(filePath, filename);

          if (!context.mounted) return;

          if (error == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('System restored successfully!'), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        }
  }

  // Existing internal list backup logic
  void _confirmInternalRestore(BuildContext context, AppProvider provider, Backup backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('CRITICAL WARNING', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(
          'Are you sure you want to restore "${backup.filename}"?\n\n'
          'This will permanently overwrite ALL current data in the system. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('OVERWRITE DATA'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restoring system data...')));
          
          // FIX: Use restoreBackup for the internal SQLite list
          final error = await provider.restoreBackupFromPath(backup.filename); 
          
          if (!context.mounted) return;

          if (error == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('System restored successfully!'), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
          }
        }
  }

  void _createBackup(BuildContext context, AppProvider provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating backup...')),
    );
    final filename = await provider.createBackup();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Backup created: $filename'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _actionBadge(String action) {
    final colors = <String, Color>{
      'LOGIN': Colors.blue,
      'LOGOUT': Colors.grey,
      'CREATE': Colors.green,
      'UPDATE': Colors.orange,
      'DELETE': Colors.red,
      'SALE': Colors.purple,
      'BACKUP': Colors.teal,
      'RESTORE': Colors.deepOrange,
    };
    final color = colors[action] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(action,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}