import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final double _dailyRevenueTarget = 5000.0;
  final double _dailyProfitTarget = 1500.0; 

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allSales = provider.getSales();
    final allProducts = provider.getProducts();

    // --- 1. DATA CRUNCHING ---
    final now = DateTime.now();
    final todaySales = allSales.where((s) {
      final d = DateTime.parse(s.timestamp);
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();

    final todayRevenue = todaySales.fold(0.0, (sum, s) => sum + s.finalTotal);
    final todayProfitEst = todayRevenue * 0.30; 
    final totalItemsSold = todaySales.fold(0, (sum, s) => sum + s.items.fold(0, (iSum, i) => iSum + i.quantity));

    final revProgress = (todayRevenue / _dailyRevenueTarget).clamp(0.0, 1.0);
    final profitProgress = (todayProfitEst / _dailyProfitTarget).clamp(0.0, 1.0);
    final criticalAlerts = allProducts.where((p) => p.stock <= 0).toList();

    // --- NEW: Payment Methods & Top Items Logic ---
    final paymentMethods = <String, double>{};
    final topItemsMap = <String, int>{};

    for (var s in todaySales) {
      paymentMethods[s.paymentMethod] = (paymentMethods[s.paymentMethod] ?? 0) + s.finalTotal;
      for (var item in s.items) {
        topItemsMap[item.productName] = (topItemsMap[item.productName] ?? 0) + item.quantity;
      }
    }

    final sortedTopItems = topItemsMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topItemsToday = sortedTopItems.take(4).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), 
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SYSTEM HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('System Command Center', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
                      const SizedBox(height: 4),
                      Text(DateFormat('EEEE, MMMM d, yyyy').format(now), style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ],
                  ),
                  _buildSystemStatusBadge(),
                ],
              ),
              const SizedBox(height: 32),

              // --- TOP ROW: KPI CARDS ---
              Row(
                children: [
                  Expanded(child: _buildProgressKPI('Daily Revenue', todayRevenue, _dailyRevenueTarget, revProgress, Colors.blue, Icons.point_of_sale)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildProgressKPI('Target Profit (Est)', todayProfitEst, _dailyProfitTarget, profitProgress, Colors.green, Icons.trending_up)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStandardKPI('Transactions', '${todaySales.length}', 'Orders Processed', Colors.purple, Icons.receipt_long)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStandardKPI('Items Sold', '$totalItemsSold', 'Units Moved', Colors.orange, Icons.inventory_2)),
                ],
              ),
              const SizedBox(height: 24),

              // --- MAIN DASHBOARD GRID ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN (Flex 5) ---
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        // 1. Quick Actions
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildActionBtn('New Sale', Icons.shopping_cart_checkout, Colors.blue[600]!, () {}),
                                  _buildActionBtn('Add Product', Icons.add_box, Colors.indigo[600]!, () {}),
                                  _buildActionBtn('Run Report', Icons.analytics, Colors.purple[600]!, () {}),
                                  _buildActionBtn('Export Data', Icons.cloud_download, Colors.teal[600]!, () {}),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // 2. Transaction Log
                        Container(
                          height: 320, 
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  const Text('Live Transaction Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text('${todaySales.length} today', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(height: 24),
                              Expanded(
                                child: todaySales.isEmpty
                                    ? Center(child: Text('No transactions yet today.', style: TextStyle(color: Colors.grey[500])))
                                    : ListView.builder(
                                        itemCount: todaySales.length > 10 ? 10 : todaySales.length, 
                                        itemBuilder: (ctx, i) {
                                          final sale = todaySales.reversed.toList()[i];
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(backgroundColor: Colors.grey[100], child: const Icon(Icons.check_circle, color: Colors.green, size: 20)),
                                            title: Text(sale.id.substring(0, 8).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                            subtitle: Text('${DateFormat('hh:mm a').format(DateTime.parse(sale.timestamp))} • ${sale.cashierName}'),
                                            trailing: Text('\$${sale.finalTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- NEW 3. Top Items Leaderboard ---
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.emoji_events, color: Colors.amber),
                                  SizedBox(width: 8),
                                  Text("Today's Top Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(height: 32),
                              _buildTopItemsList(topItemsToday),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // --- RIGHT COLUMN (Flex 3) ---
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // 1. Smart Alerts
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: criticalAlerts.isNotEmpty ? const Color(0xFFFFF4F4) : Colors.white,
                            borderRadius: BorderRadius.circular(16), 
                            border: Border.all(color: criticalAlerts.isNotEmpty ? Colors.red[200]! : Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(criticalAlerts.isNotEmpty ? Icons.warning_rounded : Icons.check_circle, color: criticalAlerts.isNotEmpty ? Colors.red : Colors.green),
                                  const SizedBox(width: 8),
                                  Text('Decision Support Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: criticalAlerts.isNotEmpty ? Colors.red[900] : Colors.black87)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (criticalAlerts.isEmpty)
                                const Text('All systems nominal. Inventory levels are stable.', style: TextStyle(color: Colors.green))
                              else
                                ...criticalAlerts.take(3).map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle, size: 8, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('${p.name} is out of stock.', style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.w500))),
                                    ],
                                  ),
                                )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- NEW 2. Payment Method Donut Chart ---
                        Container(
                          height: 260, 
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              Expanded(child: _buildPaymentDonut(paymentMethods)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 3. Revenue Sparkline
                        Container(
                          height: 260, 
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('7-Day Revenue Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              Expanded(child: _buildSparkline(allSales)),
                            ],
                          ),
                        )
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- UI HELPER WIDGETS ---
  
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.circular(16), 
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  // --- Top Items List Generator ---
  Widget _buildTopItemsList(List<MapEntry<String, int>> topItems) {
    if (topItems.isEmpty) return Center(child: Text('No items sold today.', style: TextStyle(color: Colors.grey[500])));

    final maxQty = topItems.first.value;

    return Column(
      children: topItems.map((item) {
        final progress = item.value / maxQty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${item.value} units', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: Colors.orange[400],
                minHeight: 8,
                borderRadius: BorderRadius.circular(10),
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- Payment Donut Generator ---
  Widget _buildPaymentDonut(Map<String, double> paymentMethods) {
    if (paymentMethods.isEmpty) return Center(child: Text('No payments yet.', style: TextStyle(color: Colors.grey[500])));

    final colors = [Colors.blue[600]!, Colors.purple[500]!, Colors.teal[400]!, Colors.orange[400]!];
    
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40, // Creates the Donut hole
              sections: paymentMethods.entries.map((e) {
                final idx = paymentMethods.keys.toList().indexOf(e.key);
                return PieChartSectionData(
                  color: colors[idx % colors.length],
                  value: e.value,
                  title: '', // Keep clean, rely on legend
                  radius: 20, // Donut thickness
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // The Legend
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: paymentMethods.entries.map((e) {
              final idx = paymentMethods.keys.toList().indexOf(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[idx % colors.length], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    Text('\$${e.value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.green[200]!)),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('System Running', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressKPI(String title, double current, double target, double progress, MaterialColor color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
              Icon(icon, color: color[400], size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text('\$${current.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress, backgroundColor: color[50], color: color[600], minHeight: 6, borderRadius: BorderRadius.circular(10)),
          const SizedBox(height: 8),
          Text('${(progress * 100).toStringAsFixed(0)}% of \$${target.toStringAsFixed(0)} goal', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStandardKPI(String title, String value, String subtitle, MaterialColor color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
              Icon(icon, color: color[400], size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 22), 
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSparkline(List<Sale> allSales) {
    final now = DateTime.now();
    List<FlSpot> spots = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final daySales = allSales.where((s) {
        final d = DateTime.parse(s.timestamp);
        return d.year == date.year && d.month == date.month && d.day == date.day;
      }).toList();
      final total = daySales.fold(0.0, (sum, s) => sum + s.finalTotal);
      spots.add(FlSpot((6 - i).toDouble(), total));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue[600],
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}