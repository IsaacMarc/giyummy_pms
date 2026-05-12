import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final alerts = provider.getAlerts();
    final unread = alerts.where((a) => !a.read).length;

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
                  Text(
                    'Alerts',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$unread unread',
                          style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  if (unread > 0)
                    OutlinedButton.icon(
                      onPressed: provider.markAllAlertsRead,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark All Read'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: alerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_outlined,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No alerts',
                                style: TextStyle(color: Colors.grey[400])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _AlertCard(
                          alert: alerts[i],
                          onMarkRead: () =>
                              provider.markAlertRead(alerts[i].id),
                          onDelete: () =>
                              provider.deleteAlert(alerts[i].id),
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

class _AlertCard extends StatelessWidget {
  final Alert alert;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _AlertCard({
    required this.alert,
    required this.onMarkRead,
    required this.onDelete,
  });

  IconData get _icon {
    switch (alert.type) {
      case 'low-stock':
        return Icons.inventory_2_outlined;
      case 'expiring':
        return Icons.warning_amber_outlined;
      case 'restock':
        return Icons.add_shopping_cart_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color get _severityColor {
    switch (alert.severity) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, y HH:mm');
    DateTime? parsedTime;
    try {
      parsedTime = DateTime.parse(alert.timestamp);
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: alert.read ? Colors.white : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alert.read ? Colors.grey[200]! : Colors.blue[200]!,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _severityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, color: _severityColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.message,
                    style: TextStyle(
                        fontWeight:
                            alert.read ? FontWeight.normal : FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      parsedTime != null ? fmt.format(parsedTime) : alert.timestamp,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.severity,
                        style: TextStyle(
                            color: _severityColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!alert.read)
            IconButton(
              icon: Icon(Icons.check_circle_outline,
                  color: Colors.green[600], size: 20),
              onPressed: onMarkRead,
              tooltip: 'Mark as read',
            )
          else
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
        ],
      ),
    );
  }
}
