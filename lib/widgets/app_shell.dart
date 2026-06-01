import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const _Sidebar(),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: const Color(0xFFF5F7FA),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;
    final currentPage = provider.currentPage;

    final navItems = [
      const _NavItem('dashboard', 'Dashboard', Icons.dashboard_outlined),
      const _NavItem('sales', 'Sales', Icons.point_of_sale_outlined),
      const _NavItem('inventory', 'Inventory', Icons.inventory_2_outlined),
      
      // 1. Hide Reports from Employees (Only Admin and Manager can see it)
      if (user?.role == 'Admin' || user?.role == 'Manager')
        const _NavItem('reports', 'Reports', Icons.bar_chart_outlined),
        
      const _NavItem('alerts', 'Alerts', Icons.notifications_outlined),
      // 2. Group Maintenance and Users together as Admin-only modules
      if (user?.role == 'Admin') ...[
        const _NavItem('maintenance', 'Maintenance', Icons.build_outlined),
        const _NavItem('users', 'Users', Icons.manage_accounts_outlined),
      ],

      const _NavItem('profile', 'Profile', Icons.person_outline),
      const _NavItem('help', 'Help', Icons.help_outline),
      const _NavItem('about', 'About', Icons.info_outline_rounded),
    ];

    return Container(
      width: 220,
      color: const Color(0xFF0B0B0B),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding:  EdgeInsets.symmetric(horizontal: 16),
            child:  Image(image: AssetImage("assets/images/giyummy.png"), width: 240, height: 180)
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: navItems.map((item) {
                final selected = currentPage == item.page;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: selected ? Colors.grey[850] : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => provider.navigateTo(item.page),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(item.icon,
                                color: selected
                                    ? Colors.white
                                    : Colors.grey[400],
                                size: 20),
                            const SizedBox(width: 10),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => provider.logout(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.grey[400], size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Logout',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String page;
  final String label;
  final IconData icon;
  const _NavItem(this.page, this.label, this.icon);
}
