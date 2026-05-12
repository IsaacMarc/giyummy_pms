import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _topics = [
    _HelpTopic(
      icon: Icons.rocket_launch_outlined,
      title: 'Getting Started',
      color: Colors.blue,
      body:
          'Log in with your credentials. Admins can manage all users and data. Managers handle inventory and reports. Employees can process sales.',
    ),
    _HelpTopic(
      icon: Icons.dashboard_outlined,
      title: 'Dashboard',
      color: Colors.teal,
      body:
          'View real-time KPIs: total products, today\'s sales, revenue, and active alerts. See low-stock warnings and recent transactions at a glance.',
    ),
    _HelpTopic(
      icon: Icons.point_of_sale_outlined,
      title: 'Sales',
      color: Colors.green,
      body:
          'Process sales by selecting products or scanning barcodes. Add items to cart, apply discounts, choose payment method, and complete the transaction.',
    ),
    _HelpTopic(
      icon: Icons.inventory_2_outlined,
      title: 'Inventory',
      color: Colors.orange,
      body:
          'Add, edit, and delete products. Search by name or filter by category. Stock statuses are color-coded: green (OK), orange (low), red (out of stock).',
    ),
    _HelpTopic(
      icon: Icons.bar_chart_outlined,
      title: 'Reports',
      color: Colors.purple,
      body:
          'Analyze sales performance with revenue totals, transaction counts, average sale value, 7-day trend chart, and top-selling products ranking.',
    ),
    _HelpTopic(
      icon: Icons.notifications_outlined,
      title: 'Alerts',
      color: Colors.red,
      body:
          'Receive automatic low-stock and out-of-stock alerts. Alerts have severity levels (info, warning, critical). Mark read individually or all at once.',
    ),
    _HelpTopic(
      icon: Icons.person_outline,
      title: 'Profile',
      color: Colors.indigo,
      body:
          'Update your email, phone, and department. Change your password securely. Your username and role are set by an administrator.',
    ),
    _HelpTopic(
      icon: Icons.manage_accounts_outlined,
      title: 'User Management',
      color: Colors.brown,
      body:
          'Admin-only: view all users, toggle active/inactive status, and delete accounts. You cannot modify your own account status here.',
    ),
    _HelpTopic(
      icon: Icons.build_outlined,
      title: 'Maintenance',
      color: Colors.blueGrey,
      body:
          'Create data backups exported as JSON files. View the last 50 audit log entries showing all user actions with timestamps.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Help & Documentation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 4),
          Text('Everything you need to know about the system.',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.0,
            children: _topics
                .map((t) => _HelpCard(topic: t))
                .toList(),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.support_agent, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Need more help?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Contact: support@company.com',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('v1.0.0',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTopic {
  final IconData icon;
  final String title;
  final Color color;
  final String body;
  const _HelpTopic(
      {required this.icon,
      required this.title,
      required this.color,
      required this.body});
}

class _HelpCard extends StatelessWidget {
  final _HelpTopic topic;
  const _HelpCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(topic.icon, color: topic.color, size: 22),
                const SizedBox(width: 8),
                Text(topic.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                topic.body,
                style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4),
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
