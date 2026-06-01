import 'dart:async';
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
  // Customizable Goals
  double _dailyRevenueTarget = 5000.0;
  double _dailyProfitTarget = 1500.0; 

  // Real-time Clock
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- GOAL EDITING DIALOG ---
  void _showEditGoalsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final revCtrl = TextEditingController(text: _dailyRevenueTarget.toStringAsFixed(0));
    final profCtrl = TextEditingController(text: _dailyProfitTarget.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text('Set Daily Targets', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: revCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Daily Revenue Goal',
                prefixIcon: const Icon(Icons.attach_money),
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: profCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Daily Profit Goal',
                prefixIcon: const Icon(Icons.trending_up),
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _dailyRevenueTarget = double.tryParse(revCtrl.text) ?? 5000.0;
                _dailyProfitTarget = double.tryParse(profCtrl.text) ?? 1500.0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save Targets'),
          )
        ],
      )
    );
  }

  // --- DYNAMIC THEME COLORS ---
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get bgColor => isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FC);
  Color get cardColor => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textColor => isDark ? Colors.white : const Color(0xFF1A1F36);
  Color get subTextColor => isDark ? Colors.grey[400]! : Colors.grey[600]!;
  Color get borderColor => isDark ? Colors.grey[800]! : Colors.grey[200]!;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allSales = provider.getSales();
    final allProducts = provider.getProducts();

    // --- 1. DATA CRUNCHING ---
    final todaySales = allSales.where((s) {
      final d = DateTime.parse(s.timestamp);
      return d.year == _currentTime.year && d.month == _currentTime.month && d.day == _currentTime.day;
    }).toList();

    final todayRevenue = todaySales.fold(0.0, (sum, s) => sum + s.finalTotal);
    final todayProfitEst = todayRevenue * 0.30; 
    final totalItemsSold = todaySales.fold(0, (sum, s) => sum + s.items.fold(0, (iSum, i) => iSum + i.quantity));

    final revProgress = (todayRevenue / _dailyRevenueTarget).clamp(0.0, 1.0);
    final profitProgress = (todayProfitEst / _dailyProfitTarget).clamp(0.0, 1.0);
    final criticalAlerts = allProducts.where((p) => p.stock <= 0).toList();

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
      backgroundColor: bgColor, 
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
                      Text('System Command Center', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: subTextColor),
                          const SizedBox(width: 8),
                          Text(DateFormat('EEEE, MMMM d, yyyy').format(_currentTime), style: TextStyle(fontSize: 16, color: subTextColor, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, size: 16, color: Colors.blue[600]),
                          const SizedBox(width: 6),
                          Text(DateFormat('hh:mm:ss a').format(_currentTime), style: TextStyle(fontSize: 16, color: Colors.blue[600], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // GLOBAL DARK MODE TOGGLE
                      IconButton(
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? Colors.amber : Colors.grey[700]),
                        onPressed: () => context.read<AppProvider>().toggleTheme(),
                        tooltip: 'Toggle Global Theme',
                      ),
                      const SizedBox(width: 16),
                      _buildSystemStatusBadge(),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 32),

              // --- TOP ROW: KPI CARDS ---
              Row(
                children: [
                  Expanded(child: _buildProgressKPI('Daily Revenue', todayRevenue, _dailyRevenueTarget, revProgress, Colors.blue, Icons.point_of_sale, onEdit: _showEditGoalsDialog)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildProgressKPI('Target Profit (Est)', todayProfitEst, _dailyProfitTarget, profitProgress, Colors.green, Icons.trending_up, onEdit: _showEditGoalsDialog)),
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
                        _interactableCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 16),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildActionBtn('New Sale', Icons.shopping_cart_checkout, Colors.blue[600]!, 
                                      () => context.read<AppProvider>().navigateTo('sales')), 
                                      
                                    _buildActionBtn('View Inventory', Icons.add_box, Colors.indigo[600]!, 
                                      () => context.read<AppProvider>().navigateTo('inventory')), 
                                      
                                    _buildActionBtn('View Report', Icons.analytics, Colors.purple[600]!, 
                                      () => context.read<AppProvider>().navigateTo('reports')), 
                                      
                                    _buildActionBtn('Export Data', Icons.cloud_download, Colors.teal[600]!, 
                                      () => context.read<AppProvider>().navigateTo('maintenance')), 
                                  ],
                                )
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // 2. Transaction Log
                        _interactableCard(
                          height: 320, 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('Live Transaction Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                  const Spacer(),
                                  Text('${todaySales.length} today', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Divider(height: 24, color: borderColor),
                              Expanded(
                                child: todaySales.isEmpty
                                    ? Center(child: Text('No transactions yet today.', style: TextStyle(color: subTextColor)))
                                    : ListView.builder(
                                        itemCount: todaySales.length > 10 ? 10 : todaySales.length, 
                                        itemBuilder: (ctx, i) {
                                          final sale = todaySales.reversed.toList()[i];
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100], child: const Icon(Icons.check_circle, color: Colors.green, size: 20)),
                                            title: Text(sale.id.substring(0, 8).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor)),
                                            subtitle: Text('${DateFormat('hh:mm a').format(DateTime.parse(sale.timestamp))} • ${sale.cashierName}', style: TextStyle(color: subTextColor)),
                                            trailing: Text('₱${sale.finalTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 3. Top Items Leaderboard
                        _interactableCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Text("Today's Top Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                ],
                              ),
                              Divider(height: 32, color: borderColor),
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
                        _interactableCard(
                          customColor: criticalAlerts.isNotEmpty ? (isDark ? Colors.red[900]!.withOpacity(0.2) : const Color(0xFFFFF4F4)) : cardColor,
                          customBorder: criticalAlerts.isNotEmpty ? Colors.red[300]! : borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(criticalAlerts.isNotEmpty ? Icons.warning_rounded : Icons.check_circle, color: criticalAlerts.isNotEmpty ? Colors.red : Colors.green),
                                  const SizedBox(width: 8),
                                  Text('Decision Support Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: criticalAlerts.isNotEmpty ? Colors.red[400] : textColor)),
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
                                      Expanded(child: Text('${p.name} is out of stock.', style: TextStyle(color: isDark ? Colors.red[200] : Colors.red[800], fontWeight: FontWeight.w500))),
                                    ],
                                  ),
                                )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 2. Payment Method Donut Chart
                        _interactableCard(
                          height: 260, 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payment Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 24),
                              Expanded(child: _buildPaymentDonut(paymentMethods)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 3. ENHANCED Revenue Trend Line Chart
                        _interactableCard(
                          height: 280, 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('7-Day Revenue Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 24),
                              Expanded(child: _buildDetailedTrendChart(allSales)),
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
  
  Widget _interactableCard({required Widget child, double? height, Color? customColor, Color? customBorder}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {}, 
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: customColor ?? cardColor, 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: customBorder ?? borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildProgressKPI(String title, double current, double target, double progress, MaterialColor color, IconData icon, {VoidCallback? onEdit}) {
    return _interactableCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(title, style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600)),
                  if (onEdit != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onEdit,
                      child: Icon(Icons.edit, size: 14, color: Colors.blue[400]),
                    )
                  ]
                ],
              ),
              Icon(icon, color: color[400], size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text('₱${current.toStringAsFixed(2)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress, backgroundColor: isDark ? Colors.grey[800] : color[50], color: color[600], minHeight: 6, borderRadius: BorderRadius.circular(10)),
          const SizedBox(height: 8),
          Text('${(progress * 100).toStringAsFixed(0)}% of ₱${target.toStringAsFixed(0)} goal', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStandardKPI(String title, String value, String subtitle, MaterialColor color, IconData icon) {
    return _interactableCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600)),
              Icon(icon, color: color[400], size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 22), 
          Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50], borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? Colors.green[700]! : Colors.green[200]!)),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('System Running', style: TextStyle(color: isDark ? Colors.green[400] : Colors.green[700], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTopItemsList(List<MapEntry<String, int>> topItems) {
    if (topItems.isEmpty) return Center(child: Text('No items sold today.', style: TextStyle(color: subTextColor)));
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
                  Text(item.key, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                  Text('${item.value} units', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
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

  Widget _buildPaymentDonut(Map<String, double> paymentMethods) {
    if (paymentMethods.isEmpty) return Center(child: Text('No payments yet.', style: TextStyle(color: subTextColor)));

    final colors = [Colors.blue[600]!, Colors.purple[500]!, Colors.teal[400]!, Colors.orange[400]!];
    
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: paymentMethods.entries.map((e) {
                final idx = paymentMethods.keys.toList().indexOf(e.key);
                return PieChartSectionData(color: colors[idx % colors.length], value: e.value, title: '', radius: 20);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
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
                    Expanded(child: Text(e.key, style: TextStyle(color: subTextColor, fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    Text('₱${e.value.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedTrendChart(List<Sale> allSales) {
    List<FlSpot> spots = [];
    double maxTotal = 0;

    for (int i = 6; i >= 0; i--) {
      final date = _currentTime.subtract(Duration(days: i));
      final daySales = allSales.where((s) {
        final d = DateTime.parse(s.timestamp);
        return d.year == date.year && d.month == date.month && d.day == date.day;
      }).toList();
      final total = daySales.fold(0.0, (sum, s) => sum + s.finalTotal);
      if (total > maxTotal) maxTotal = total;
      spots.add(FlSpot((6 - i).toDouble(), total));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: borderColor, strokeWidth: 1)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0), style: TextStyle(color: subTextColor, fontSize: 10), textAlign: TextAlign.right),
                );
              }
            )
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final date = _currentTime.subtract(Duration(days: 6 - value.toInt()));
                final dayName = DateFormat('EEE').format(date); // Mon, Tue, Wed...
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(dayName, style: TextStyle(color: subTextColor, fontSize: 11)),
                );
              }
            )
          )
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => isDark ? Colors.white : Colors.blueGrey[800]!,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) => LineTooltipItem('₱${spot.y.toStringAsFixed(2)}', TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold))).toList();
            }
          )
        ),
        maxY: maxTotal == 0 ? 1000 : maxTotal * 1.2, 
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue[600],
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true), 
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}