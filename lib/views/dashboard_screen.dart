import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final products = provider.getProducts();
    final sales = provider.getSales();
    final alerts = provider.getAlerts();

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todaySales = sales
        .where((s) => s.timestamp.startsWith(today) && s.status == 'completed')
        .toList();
    final todayRevenue =
        todaySales.fold(0.0, (sum, s) => sum + s.finalTotal);
    final totalRevenue =
        sales.where((s) => s.status == 'completed').fold(0.0, (sum, s) => sum + s.finalTotal);
    final lowStock =
        products.where((p) => p.stock > 0 && p.stock <= p.reorderLevel).toList();
    final outOfStock = products.where((p) => p.stock == 0).toList();

    final fmt = NumberFormat.currency(symbol: '\$');
    // This accurately catches Low Stock, Out of Stock, AND Expired items!
    final activeAlertCount = products.where((p) => p.status != 'In Stock').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              StatCard(
                title: 'Total Products',
                value: '${products.length}',
                icon: Icons.inventory_2_outlined,
                color: Colors.blue,
                background_icon_color: const Color.fromARGB(255, 166, 227, 255),
              ),
              StatCard(
                title: "Today's Sales",
                value: '${todaySales.length}',
                icon: Icons.receipt_long_outlined,
                color: const Color.fromARGB(255, 38, 121, 41),
                background_icon_color: const Color.fromARGB(255, 145, 255, 149),
              ),
              StatCard(
                title: "Today's Revenue",
                value: fmt.format(todayRevenue),
                icon: Icons.attach_money,
                color: const Color.fromARGB(255, 209, 125, 0),
                background_icon_color: const Color.fromARGB(255, 255, 211, 146)
              ),
              StatCard(
                title: 'Active Alerts',
                value: '$activeAlertCount',
                icon: Icons.notifications_active_outlined,
                color: Colors.red,
                background_icon_color: const Color.fromARGB(255, 255, 185, 180),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Low Stock
              Expanded(
                child: Card(
                  elevation: 2,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.only(top:20,right:20,left:20,bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_rounded,
                                color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            const Text('Low Stock Alert',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(
                                height: 8,      // The total space occupied by the divider
                                thickness: 2,    // The actual thickness of the line  // Empty space to the right
                                color: Colors.grey,
                              ),
                        const SizedBox(height: 16),
                        if (lowStock.isEmpty && outOfStock.isEmpty)
                          Text('All products are well stocked!',
                              style: TextStyle(color: Colors.grey[500]))
                        else ...[
                          ...outOfStock.take(3).map((p) => _stockRow(
                              p, Colors.red[700]!, 'Out of Stock')),
                          ...lowStock.take(5 - outOfStock.length.clamp(0, 3)).map(
                              (p) => _stockRow(
                                  p, Colors.orange[700]!, 'Low Stock')),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Recent Sales
              Expanded(
                child: Card(
                  elevation: 2,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_outlined,
                                color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            const Text('Recent Sales',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (sales.isEmpty)
                          Text('No sales yet.',
                              style: TextStyle(color: Colors.grey[500]))
                        else
                          ...sales.reversed.take(5).map((s) => _saleRow(s, fmt)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Summary row
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  'Total Revenue',
                  fmt.format(totalRevenue),
                  Icons.stacked_line_chart,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _summaryCard(
                  'Low Stock Items',
                  '${lowStock.length}',
                  Icons.inventory_outlined,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _summaryCard(
                  'Out of Stock',
                  '${outOfStock.length}',
                  Icons.remove_shopping_cart_outlined,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stockRow(Product p, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(p.name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text('${p.stock}',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _saleRow(Sale s, NumberFormat fmt) {
    final time = s.timestamp.length >= 16 ? s.timestamp.substring(11, 16) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.receipt, color: Colors.grey[400], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.cashierName, style: const TextStyle(fontSize: 13)),
                Text('${s.items.length} items · $time',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          Text(fmt.format(s.finalTotal),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _summaryCard(
      String title, String value, IconData icon, MaterialColor color) {
    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color[700], size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
