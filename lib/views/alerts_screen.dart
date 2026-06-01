import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'All'; // 'All', 'Unread', 'Critical'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final provider = context.watch<AppProvider>();
    final allAlerts = provider.getAlerts();
    
    // Calculations for KPIs
    final unreadCount = allAlerts.where((a) => !a.read).length;
    final criticalCount = allAlerts.where((a) => a.severity == 'critical' && !a.read).length;

    // Filter logic
    var displayedAlerts = allAlerts;
    if (_filter == 'Unread') {
      displayedAlerts = allAlerts.where((a) => !a.read).toList();
    } else if (_filter == 'Critical') {
      displayedAlerts = allAlerts.where((a) => a.severity == 'critical').toList();
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. PREMIUM HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Alerts', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                      const SizedBox(height: 4),
                      Text(unreadCount > 0 ? 'You have $unreadCount unread notifications requiring attention.' : 'You are all caught up!', style: TextStyle(fontSize: 15, color: subTextColor)),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: allAlerts.isEmpty ? null : () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              title: Text('Clear All Alerts?', style: TextStyle(color: textColor)),
                              content: Text('Are you sure you want to delete all notifications? This cannot be undone.', style: TextStyle(color: subTextColor)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () {
                                    context.read<AppProvider>().clearAllAlerts();
                                    Navigator.pop(ctx);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                                  child: const Text('Clear All'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Clear All'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red[500]),
                      ),
                      const SizedBox(width: 8),
                      if (unreadCount > 0)
                        ElevatedButton.icon(
                          onPressed: provider.markAllAlertsRead,
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Mark All Read'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- 2. KPI STAT CARDS ---
              Row(
                children: [
                  _buildStatCard('Total Alerts', '${allAlerts.length}', Icons.notifications, Colors.blue, isDark),
                  const SizedBox(width: 16),
                  _buildStatCard('Unread', '$unreadCount', Icons.mark_email_unread, Colors.orange, isDark),
                  const SizedBox(width: 16),
                  _buildStatCard('Critical Issues', '$criticalCount', Icons.warning_rounded, Colors.red, isDark),
                ],
              ),
              const SizedBox(height: 32),

              // --- 3. FILTER CHIPS ---
              Row(
                children: ['All', 'Unread', 'Critical'].map((filterName) {
                  final isSelected = _filter == filterName;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ChoiceChip(
                      label: Text(filterName, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]), fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: isDark ? Colors.blue[700] : Colors.blue[600],
                      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      onSelected: (_) => setState(() => _filter = filterName),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // --- 4. NOTIFICATION LIST ---
              Expanded(
                child: displayedAlerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_active_outlined, size: 64, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(_filter == 'All' ? 'Your inbox is empty.' : 'No $_filter alerts found.', style: TextStyle(color: subTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('When the system flags an issue, it will appear here.', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: displayedAlerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _AlertCard(
                          alert: displayedAlerts[i],
                          isDark: isDark,
                          onMarkRead: () => provider.markAlertRead(displayedAlerts[i].id),
                          onDelete: () => provider.deleteAlert(displayedAlerts[i].id),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for KPI Cards
  Widget _buildStatCard(String title, String value, IconData icon, MaterialColor color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? color[900]!.withOpacity(0.3) : color[50],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isDark ? color[400] : color[700], size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  final bool isDark;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _AlertCard({
    required this.alert,
    required this.isDark,
    required this.onMarkRead,
    required this.onDelete,
  });

  IconData get _icon {
    switch (alert.type) {
      case 'low-stock': return Icons.inventory_2_outlined;
      case 'expired': return Icons.dangerous_outlined;
      case 'expiring-soon': return Icons.warning_amber_outlined;
      default: return Icons.info_outline;
    }
  }

  Color get _severityColor {
    switch (alert.severity) {
      case 'critical': return isDark ? Colors.red[400]! : Colors.red[600]!;
      case 'warning': return isDark ? Colors.orange[400]! : Colors.orange[600]!;
      default: return isDark ? Colors.blue[400]! : Colors.blue[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy • HH:mm a');
    DateTime? parsedTime;
    try {
      parsedTime = DateTime.parse(alert.timestamp);
    } catch (_) {}

    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark 
            ? (alert.read ? const Color(0xFF1E1E1E) : const Color(0xFF132238)) // Dark blueish tint for unread
            : (alert.read ? Colors.white : Colors.blue[50]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? (alert.read ? Colors.grey[800]! : Colors.blue[900]!)
              : (alert.read ? Colors.grey[200]! : Colors.blue[200]!),
        ),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left colored severity bar indicator
            Container(width: 6, color: _severityColor),
            
            // Card Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _severityColor.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_icon, color: _severityColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.message,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: alert.read ? FontWeight.normal : FontWeight.bold,
                              fontSize: 15
                            )
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                parsedTime != null ? fmt.format(parsedTime) : alert.timestamp,
                                style: TextStyle(color: subTextColor, fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _severityColor.withOpacity(isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  alert.severity.toUpperCase(),
                                  style: TextStyle(color: _severityColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Actions
                    if (!alert.read)
                      IconButton(
                        icon: Icon(Icons.check_circle, color: isDark ? Colors.blue[400] : Colors.blue[600], size: 28),
                        onPressed: onMarkRead,
                        tooltip: 'Mark as read',
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 24),
                        onPressed: onDelete,
                        tooltip: 'Delete notification',
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
}