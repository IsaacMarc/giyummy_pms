import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

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
          // Backup section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined,
                          color: Colors.blue[700], size: 22),
                      const SizedBox(width: 8),
                      const Text('Backup & Restore',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
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
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...backups.reversed.take(5).map((b) {
                      DateTime? t;
                      try {
                        t = DateTime.parse(b.timestamp);
                      } catch (_) {}
                      return ListTile(
                        dense: true,
                        leading:
                            const Icon(Icons.folder_zip_outlined, size: 20),
                        title: Text(b.filename,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            t != null ? dtFmt.format(t) : b.timestamp,
                            style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          '${(b.size / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Audit log section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_outlined,
                          color: Colors.blue[700], size: 22),
                      const SizedBox(width: 8),
                      const Text('Audit Logs',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      Text('Last ${logs.length} entries',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(Colors.grey[50]),
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12))),
                          DataCell(_actionBadge(log.action)),
                          DataCell(Text(log.module,
                              style: const TextStyle(fontSize: 12))),
                          DataCell(SizedBox(
                            width: 200,
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
                        child: Text('No audit logs yet.',
                            style: TextStyle(color: Colors.grey[400])),
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

  void _createBackup(BuildContext context, AppProvider provider) {
    final filename = provider.createBackup();
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
    };
    final color = colors[action] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(action,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
