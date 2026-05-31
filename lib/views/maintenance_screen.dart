import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart'; 
import '../providers/app_provider.dart';
import '../models/models.dart';
import 'dart:math';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  static const int _itemsPerPage = 10; // Increased to fill the larger card
  int _currentPage = 0;

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[200]!),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final logs = provider.getAuditLogs();
    final backups = provider.getBackups();
    final dtFmt = DateFormat('MMM d, y HH:mm:ss');
    
    final allLogs = context.watch<AppProvider>().getAuditLogs();
    final totalPages = (allLogs.length / _itemsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1; 
    }

    final paginatedLogs = allLogs.isNotEmpty 
        ? allLogs.skip(_currentPage * _itemsPerPage).take(_itemsPerPage).toList()
        : <AuditLog>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Modern clean background
      body: SafeArea(
        child: SingleChildScrollView(
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
                    child: const Icon(Icons.settings_system_daydream, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('System Maintenance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
                      const SizedBox(height: 4),
                      Text('Manage data backups and monitor system audit logs.', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- SYSTEM STATISTICS ROW ---
              Row(
                children: [
                  _buildStatCard('Total Users', provider.getUsers().length.toString(), Icons.people_outline, Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatCard('Total Inventory', provider.getProducts().length.toString(), Icons.inventory_2_outlined, Colors.orange),
                  const SizedBox(width: 16),
                  _buildStatCard('Total Sales', provider.getSales().length.toString(), Icons.point_of_sale, Colors.green),
                  const SizedBox(width: 16),
                  _buildStatCard('Audit Logs', logs.length.toString(), Icons.history, Colors.purple),
                ],
              ),
              const SizedBox(height: 24),

              // --- BACKUP & RESTORE SECTION ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.backup_outlined, color: Colors.blue[700], size: 24),
                            const SizedBox(width: 12),
                            const Text('Backup & Restore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickAndRestoreFile(context, provider),
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Restore Backup'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange[800],
                                side: BorderSide(color: Colors.orange[200]!),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _createBackup(context, provider),
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Create Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (backups.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text('Recent Backups', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      ...backups.reversed.take(5).map((b) {
                        DateTime? t;
                        try { t = DateTime.parse(b.timestamp); } catch (_) {}
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!)
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.folder_zip_outlined, size: 20, color: Colors.blue[700]),
                            ),
                            title: Text(b.filename, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text(t != null ? dtFmt.format(t) : b.timestamp, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${(b.size / 1024).toStringAsFixed(1)} KB', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.restore, color: Colors.orange),
                                  tooltip: 'Restore this backup',
                                  onPressed: () => _confirmInternalRestore(context, provider, b),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- AUDIT LOG SECTION ---
              Container(
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history_outlined, color: Colors.blue[700], size: 24),
                              const SizedBox(width: 12),
                              const Text('System Audit Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                          Text('Last ${logs.length} entries', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // Force the DataTable to stretch to fill the card
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                              dataRowMinHeight: 50,
                              dataRowMaxHeight: 50,
                              horizontalMargin: 24,
                              columns: [
                                DataColumn(label: Text('TIMESTAMP', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('USER', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('ACTION', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('MODULE', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('DETAILS', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                              rows: paginatedLogs.map((log) {
                                DateTime? t;
                                try { t = DateTime.parse(log.timestamp); } catch (_) {}
                                return DataRow(cells: [
                                  DataCell(Text(t != null ? dtFmt.format(t) : log.timestamp, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                  DataCell(Text(log.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                  DataCell(_actionBadge(log.action)),
                                  DataCell(Text(log.module, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                  DataCell(
                                    SizedBox(
                                      width: 350, // Gives the details column plenty of room
                                      child: Text(
                                        log.details,
                                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                        overflow: TextOverflow.ellipsis
                                      ),
                                    )
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        );
                      }
                    ),
                    
                    if (logs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No audit logs recorded yet.', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      
                    const Divider(height: 1),
                    
                    // Pagination
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${allLogs.isEmpty ? 0 : (_currentPage * _itemsPerPage) + 1} - ${min((_currentPage + 1) * _itemsPerPage, allLogs.length)} of ${allLogs.length} logs', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                child: const Text('Previous'),
                              ),
                              const SizedBox(width: 16),
                              Text('Page ${_currentPage + 1} of ${totalPages > 0 ? totalPages : 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16),
                              OutlinedButton(
                                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                child: const Text('Next'),
                              ),
                            ],
                          ),
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
    );
  }

  // --- NATIVE FILE EXPLORER LOGIC ---
  void _pickAndRestoreFile(BuildContext context, AppProvider provider) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select Database Backup File',
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      final filePath = result.files.single.path!;
      final filename = result.files.single.name;
      _confirmExternalRestore(context, provider, filename, filePath);
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restoring system data...')));
      final error = await provider.restoreBackupFromPath(filePath, filename);

      if (!context.mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System restored successfully!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

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
      final error = await provider.restoreBackup(backup.filename); 
      
      if (!context.mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System restored successfully!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  void _createBackup(BuildContext context, AppProvider provider) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Creating backup...')));
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(action, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(count, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}