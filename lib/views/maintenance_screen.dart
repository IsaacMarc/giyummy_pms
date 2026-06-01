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

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final provider = context.watch<AppProvider>();
    final logs = provider.getAuditLogs();
    final backups = provider.getBackups();
    final dtFmt = DateFormat('MMM d, yyyy HH:mm:ss');
    
    final allLogs = context.watch<AppProvider>().getAuditLogs();
    final totalPages = (allLogs.length / _itemsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1; 
    }

    final paginatedLogs = allLogs.isNotEmpty 
        ? allLogs.skip(_currentPage * _itemsPerPage).take(_itemsPerPage).toList()
        : <AuditLog>[];

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
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: isDark ? Colors.blue[800] : Colors.blue[600], borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.settings_system_daydream, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Maintenance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                      const SizedBox(height: 4),
                      Text('Manage data backups and monitor system audit logs.', style: TextStyle(fontSize: 15, color: subTextColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- SYSTEM STATISTICS ROW ---
              Row(
                children: [
                  _buildStatCard('Total Users', provider.getUsers().length.toString(), Icons.people_outline, Colors.blue, isDark),
                  const SizedBox(width: 16),
                  _buildStatCard('Total Inventory', provider.getProducts().length.toString(), Icons.inventory_2_outlined, Colors.orange, isDark),
                  const SizedBox(width: 16),
                  _buildStatCard('Total Sales', provider.getSales().length.toString(), Icons.point_of_sale, Colors.green, isDark),
                  const SizedBox(width: 16),
                  _buildStatCard('Audit Logs', logs.length.toString(), Icons.history, Colors.purple, isDark),
                ],
              ),
              const SizedBox(height: 24),

              // --- BACKUP & RESTORE SECTION ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.backup_outlined, color: isDark ? Colors.blue[400] : Colors.blue[700], size: 24),
                            const SizedBox(width: 12),
                            Text('Backup & Restore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                          ],
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickAndRestoreFile(context, provider),
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Restore Backup'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.orange[400] : Colors.orange[800],
                                side: BorderSide(color: isDark ? Colors.orange[700]! : Colors.orange[200]!),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _createBackup(context, provider),
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Create Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.blue[800] : Colors.blue[700],
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
                      Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                      const SizedBox(height: 16),
                      Text('Recent Backups', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                      const SizedBox(height: 12),
                      ...backups.reversed.take(5).map((b) {
                        DateTime? t;
                        try { t = DateTime.parse(b.timestamp); } catch (_) {}
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.folder_zip_outlined, size: 20, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                            ),
                            title: Text(b.filename, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                            subtitle: Text(t != null ? dtFmt.format(t) : b.timestamp, style: TextStyle(fontSize: 12, color: subTextColor)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${(b.size / 1024).toStringAsFixed(1)} KB', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: Icon(Icons.restore, color: isDark ? Colors.orange[400] : Colors.orange),
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
                decoration: _cardDecoration(isDark),
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
                              Icon(Icons.history_outlined, color: isDark ? Colors.blue[400] : Colors.blue[700], size: 24),
                              const SizedBox(width: 12),
                              Text('System Audit Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                            ],
                          ),
                          Text('Last ${logs.length} entries', style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    
                    // Force the DataTable to stretch to fill the card
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(isDark ? Colors.grey[900] : Colors.grey[50]),
                              dataRowMinHeight: 50,
                              dataRowMaxHeight: 50,
                              horizontalMargin: 24,
                              columns: [
                                DataColumn(label: Text('TIMESTAMP', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('USER', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('ACTION', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('MODULE', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('DETAILS', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                              rows: paginatedLogs.map((log) {
                                DateTime? t;
                                try { t = DateTime.parse(log.timestamp); } catch (_) {}
                                return DataRow(cells: [
                                  DataCell(Text(t != null ? dtFmt.format(t) : log.timestamp, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor))),
                                  DataCell(Text(log.username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor))),
                                  DataCell(_actionBadge(log.action, isDark)),
                                  DataCell(Text(log.module, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor))),
                                  DataCell(
                                    SizedBox(
                                      width: 350, // Gives the details column plenty of room
                                      child: Text(
                                        log.details,
                                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]),
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
                              Icon(Icons.history_toggle_off, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No audit logs recorded yet.', style: TextStyle(color: subTextColor, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    
                    // Pagination
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${allLogs.isEmpty ? 0 : (_currentPage * _itemsPerPage) + 1} - ${min((_currentPage + 1) * _itemsPerPage, allLogs.length)} of ${allLogs.length} logs', style: TextStyle(color: subTextColor, fontSize: 13)),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                child: const Text('Previous'),
                              ),
                              const SizedBox(width: 16),
                              Text('Page ${_currentPage + 1} of ${totalPages > 0 ? totalPages : 1}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
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
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('OVERWRITE DATA'),
            ),
          ],
        );
      }
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
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('OVERWRITE DATA'),
            ),
          ],
        );
      }
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

  Widget _actionBadge(String action, bool isDark) {
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
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(action, style: TextStyle(color: isDark ? color.withOpacity(0.9) : color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, MaterialColor color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(isDark),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color[isDark ? 900 : 50]!.withOpacity(isDark ? 0.3 : 1.0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDark ? color[400] : color[700], size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}