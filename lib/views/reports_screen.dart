import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/stat_card.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sales = context
        .watch<AppProvider>()
        .getSales()
        .where((s) => s.status == 'completed')
        .toList();

    final fmt = NumberFormat.currency(symbol: '\$');
    final totalRevenue = sales.fold(0.0, (sum, s) => sum + s.finalTotal);
    final avgSale = sales.isEmpty ? 0.0 : totalRevenue / sales.length;
    final totalItems =
        sales.fold(0, (sum, s) => sum + s.items.fold(0, (a, i) => a + i.quantity));

    // Last 7 days trend
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateFormat('yyyy-MM-dd').format(d);
    });
    final dailyRevenue = {for (final d in days) d: 0.0};
    for (final s in sales) {
      final day = s.timestamp.substring(0, 10);
      if (dailyRevenue.containsKey(day)) {
        dailyRevenue[day] = (dailyRevenue[day] ?? 0) + s.finalTotal;
      }
    }

    // Top products
    final productRevenue = <String, Map<String, dynamic>>{};
    for (final s in sales) {
      for (final item in s.items) {
        productRevenue.putIfAbsent(item.productId, () => {
              'name': item.productName,
              'qty': 0,
              'revenue': 0.0,
            });
        productRevenue[item.productId]!['qty'] =
            (productRevenue[item.productId]!['qty'] as int) + item.quantity;
        productRevenue[item.productId]!['revenue'] =
            (productRevenue[item.productId]!['revenue'] as double) +
                item.subtotal;
      }
    }
    final topProducts = productRevenue.values.toList()
      ..sort((a, b) =>
          (b['revenue'] as double).compareTo(a['revenue'] as double));

    final maxRevenue =
        dailyRevenue.values.fold(0.0, (m, v) => v > m ? v : m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              StatCard(
                title: 'Total Revenue',
                value: fmt.format(totalRevenue),
                icon: Icons.monetization_on_outlined,
                color: Colors.green,
                background_icon_color: Colors.lightBlueAccent,
              ),
              StatCard(
                title: 'Total Transactions',
                value: '${sales.length}',
                icon: Icons.receipt_long_outlined,
                color: Colors.blue,
                background_icon_color: Colors.lightBlueAccent,
              ),
              StatCard(
                title: 'Average Sale',
                value: fmt.format(avgSale),
                icon: Icons.show_chart,
                color: Colors.purple,
                background_icon_color: Colors.lightBlueAccent,
              ),
              StatCard(
                title: 'Products Sold',
                value: '$totalItems',
                icon: Icons.shopping_bag_outlined,
                color: Colors.orange,
                background_icon_color: Colors.lightBlueAccent,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sales trend chart
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sales Trend – Last 7 Days',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 220,
                          child: sales.isEmpty
                              ? Center(
                                  child: Text('No sales data',
                                      style:
                                          TextStyle(color: Colors.grey[400])))
                              : BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: maxRevenue * 1.2 + 1,
                                    barGroups: List.generate(days.length, (i) {
                                      final rev = dailyRevenue[days[i]] ?? 0;
                                      return BarChartGroupData(
                                        x: i,
                                        barRods: [
                                          BarChartRodData(
                                            toY: rev,
                                            color: Colors.blue[600],
                                            width: 28,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(4)),
                                          ),
                                        ],
                                      );
                                    }),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 60,
                                          getTitlesWidget: (v, _) => Text(
                                              fmt.format(v),
                                              style: const TextStyle(
                                                  fontSize: 10)),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (v, _) {
                                            final idx = v.toInt();
                                            if (idx < 0 || idx >= days.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final label = days[idx]
                                                .substring(5)
                                                .replaceAll('-', '/');
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4),
                                              child: Text(label,
                                                  style: const TextStyle(
                                                      fontSize: 10)),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (v) =>
                                          FlLine(color: Colors.grey[200]!),
                                    ),
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Top products
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Top Selling Products',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        if (topProducts.isEmpty)
                          Text('No sales data',
                              style: TextStyle(color: Colors.grey[400]))
                        else
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(3),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(2),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                    color: Colors.grey[50]),
                                children: [
                                  _tableHeader('Product'),
                                  _tableHeader('Qty'),
                                  _tableHeader('Revenue'),
                                ],
                              ),
                              ...topProducts.take(5).map(
                                    (p) => TableRow(
                                      children: [
                                        _tableCell(
                                            p['name'] as String, bold: true),
                                        _tableCell(
                                            '${p['qty']}'),
                                        _tableCell(fmt.format(
                                            p['revenue'] as double),
                                            color: Colors.green[700]),
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12)),
      );

  Widget _tableCell(String text, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color,
                fontSize: 13)),
      );
}
