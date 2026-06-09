import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';

class SalesReportView extends StatelessWidget {
  final List<Sale> sales;
  final String dateRange;
  final Map<String, double> revenueTargets;
  final Function(String) onEditTargetGoal;

  const SalesReportView({
    super.key,
    required this.sales,
    required this.dateRange,
    required this.revenueTargets,
    required this.onEditTargetGoal,
  });

  BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
    color: isDark ? const Color(0xFF1E1E1E) : Colors.white, 
    borderRadius: BorderRadius.circular(12), 
    border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)
  );

  Widget _buildKPI(String title, String value, MaterialColor color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? color[400] : color[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesLineChart(List<Sale> sales, bool isDark) {
    if (sales.isEmpty) return Center(child: Text('No data for selected range.', style: TextStyle(color: isDark ? Colors.white : Colors.black)));
    
    final grouped = <int, double>{};
    for (var s in sales) {
      final day = DateTime.parse(s.timestamp).day;
      grouped[day] = (grouped[day] ?? 0) + s.finalTotal;
    }
    
    final sortedKeys = grouped.keys.toList()..sort();
    List<FlSpot> spots = sortedKeys.map((day) => FlSpot(day.toDouble(), grouped[day]!)).toList();

    final rawMax = spots.isEmpty ? 10000.0 : spots.map((s) => s.y).reduce(max) * 1.2;
    final maxY = rawMax <= 0 ? 10000.0 : rawMax;
    final interval = (maxY / 4) <= 0 ? 2500.0 : (maxY / 4).ceilToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: false, 
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                String text = value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(text, style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 11), textAlign: TextAlign.right),
                );
              }
            )
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(value.toInt().toString(), style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 11)),
                );
              }
            )
          )
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (group) => isDark ? Colors.blueGrey[800]! : Colors.blueGrey[700]!,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) => LineTooltipItem(
                'Day ${spot.x.toInt()}\n₱${spot.y.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
              )).toList();
            }
          )
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots, 
            isCurved: true, 
            color: isDark ? Colors.blue[400] : Colors.blue[600], 
            barWidth: 3, 
            belowBarData: BarAreaData(show: true, color: (isDark ? Colors.blue[400]! : Colors.blue[600]!).withOpacity(0.1))
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMixChart(Map<String, double> paymentMix, bool isDark) {
    if (paymentMix.isEmpty) return Center(child: Text('No payments recorded.', style: TextStyle(color: isDark ? Colors.white : Colors.black)));
    
    final colors = isDark 
      ? [Colors.green[400]!, Colors.orange[400]!, Colors.blue[400]!, Colors.purple[400]!]
      : [Colors.green, Colors.orange, Colors.blue, Colors.purple];
    final sections = paymentMix.entries.toList();

    return PieChart(
      PieChartData(
        sectionsSpace: 2, centerSpaceRadius: 40,
        sections: sections.asMap().entries.map((e) {
          return PieChartSectionData(
            color: colors[e.key % colors.length],
            value: e.value.value,
            title: '',
            radius: 20,
          );
        }).toList()
      )
    );
  }

  Widget _buildCashierLeaderboard(List<Sale> sales, bool isDark, Color textColor) {
    if (sales.isEmpty) return Center(child: Text('No sales data.', style: TextStyle(color: textColor)));
    final fmt = NumberFormat.currency(symbol: '₱');
    
    final cashierStats = <String, Map<String, dynamic>>{};
    for (var s in sales) {
      if (!cashierStats.containsKey(s.cashierName)) {
        cashierStats[s.cashierName] = {'revenue': 0.0, 'txns': 0};
      }
      cashierStats[s.cashierName]!['revenue'] += s.finalTotal;
      cashierStats[s.cashierName]!['txns'] += 1;
    }

    final sortedCashiers = cashierStats.entries.toList()..sort((a, b) => b.value['revenue'].compareTo(a.value['revenue']));

    return ListView.separated(
      itemCount: sortedCashiers.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
      itemBuilder: (context, index) {
        final entry = sortedCashiers[index];
        final isTop = index == 0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isTop ? (isDark ? Colors.amber[900]!.withOpacity(0.3) : Colors.amber[100]) : (isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50]),
            child: Text('${index + 1}', style: TextStyle(color: isTop ? (isDark ? Colors.amber[400] : Colors.amber[900]) : (isDark ? Colors.blue[300] : Colors.blue[900]), fontWeight: FontWeight.bold)),
          ),
          title: Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Text('${entry.value['txns']} transactions', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 12)),
          trailing: Text(fmt.format(entry.value['revenue']), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green[400] : Colors.green)),
        );
      },
    );
  }

  Widget _buildPeakHoursChart(List<Sale> sales, bool isDark) {
    if (sales.isEmpty) return Center(child: Text('No sales data.', style: TextStyle(color: isDark ? Colors.white : Colors.black)));

    final hourlyCounts = List.filled(24, 0);
    for (var s in sales) {
      final hour = DateTime.parse(s.timestamp).hour;
      hourlyCounts[hour] += 1;
    }

    final maxCount = hourlyCounts.reduce((curr, next) => curr > next ? curr : next).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount == 0 ? 10 : maxCount + 2,
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: false, 
          horizontalInterval: (maxCount / 4) == 0 ? 1.0 : (maxCount / 4).ceilToDouble(),
          getDrawingHorizontalLine: (value) => FlLine(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => isDark ? Colors.blueGrey[800]! : Colors.blueGrey[700]!,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} Sales',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
              );
            }
          )
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value % 1 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(value.toInt().toString(), style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 10), textAlign: TextAlign.right),
                );
              }
            )
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                if (hour % 3 == 0) {
                  final ampm = hour >= 12 ? 'PM' : 'AM';
                  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('$displayHour$ampm', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  );
                }
                return const Text('');
              }
            )
          )
        ),
        barGroups: List.generate(24, (index) {
          final count = hourlyCounts[index];
          Color barColor = isDark ? Colors.blue[900]!.withOpacity(0.5) : Colors.blue[100]!;
          if (count > maxCount * 0.75) {
            barColor = isDark ? Colors.red[400]! : Colors.red[400]!; 
          } else if (count > maxCount * 0.4) {
            barColor = isDark ? Colors.orange[400]! : Colors.orange[400]!; 
          } else if (count > 0) {
            barColor = isDark ? Colors.blue[400]! : Colors.blue[400]!; 
          }

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: barColor,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
              )
            ],
          );
        }),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final fmt = NumberFormat.currency(symbol: '₱');
    
    final totalRevenue = sales.fold(0.0, (sum, s) => sum + s.finalTotal);
    final totalDiscounts = sales.fold(0.0, (sum, s) => sum + s.discount);
    final totalCOGS = sales.fold(0.0, (sum, s) => sum + (s.finalTotal * 0.70)); 
    final trueProfit = totalRevenue - totalCOGS;

    final targetGoal = revenueTargets[dateRange] ?? 5000.0;
    final targetHit = totalRevenue >= targetGoal;
    final progress = (totalRevenue / targetGoal).clamp(0.0, 1.0);
    final remaining = targetGoal - totalRevenue;

    final paymentMix = <String, double>{};
    for (var s in sales) {
      paymentMix[s.paymentMethod] = (paymentMix[s.paymentMethod] ?? 0) + s.finalTotal;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildKPI('Total Revenue', fmt.format(totalRevenue), Colors.green, isDark),
            const SizedBox(width: 16),
            _buildKPI('True Profit (Net)', fmt.format(trueProfit), Colors.purple, isDark),
            const SizedBox(width: 16),
            _buildKPI('Discount Leakage', '-${fmt.format(totalDiscounts)}', Colors.red, isDark),
            const SizedBox(width: 16),
            _buildKPI('Target Status', targetHit ? 'Goal Hit! 🎉' : 'Behind Pace', targetHit ? Colors.green : Colors.orange, isDark),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Revenue Over Time', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 20),
                    Expanded(child: _buildSalesLineChart(sales, isDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 3,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text('Cashier Leaderboard', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildCashierLeaderboard(sales, isDark, textColor)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Peak Hours Traffic', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    Text('Transactions by hour of day', style: TextStyle(color: subTextColor, fontSize: 12)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildPeakHoursChart(sales, isDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 3,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment mix', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    Text(dateRange, style: TextStyle(color: subTextColor, fontSize: 12)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildPaymentMixChart(paymentMix, isDark)),
                    const SizedBox(height: 16),
                    Text('Payment Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                    const SizedBox(height: 8),
                    ...paymentMix.entries.map((e) {
                      final pct = totalRevenue > 0 ? (e.value / totalRevenue * 100) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${e.key} (${pct.toStringAsFixed(1)}%)', style: TextStyle(color: subTextColor, fontSize: 13)),
                            Text(fmt.format(e.value), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ]
                        )
                      );
                    }),
                    const SizedBox(height: 8),
                    Divider(color: borderColor),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total received', style: TextStyle(color: subTextColor)),
                        Text(fmt.format(totalRevenue), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sales Goal Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                      Text(dateRange, style: TextStyle(color: subTextColor, fontSize: 13)),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onEditTargetGoal(dateRange),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Goal'),
                    style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.blue[400] : Colors.blue[700], side: BorderSide(color: isDark ? Colors.blue[900]! : Colors.blue[200]!)),
                  )
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  SizedBox(
                    height: 140, width: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(value: progress, strokeWidth: 14, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100], color: isDark ? Colors.blue[400] : Colors.blue[600]),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: textColor)),
                            Text('of goal', style: TextStyle(color: subTextColor, fontSize: 11)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACHIEVED', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(fmt.format(totalRevenue), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TARGET', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(fmt.format(targetGoal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: isDark ? Colors.grey[500] : Colors.grey)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('REMAINING', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(remaining > 0 ? fmt.format(remaining) : '₱0.00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: remaining > 0 ? (isDark ? Colors.orange[400] : Colors.orange[700]) : (isDark ? Colors.green[400] : Colors.green))),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}