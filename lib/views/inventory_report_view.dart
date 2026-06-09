import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';

class InventoryReportView extends StatelessWidget {
  final List<Product> products;
  final List<Sale> filteredSales;
  final List<Sale> allSales;
  final String dateRange;
  final Function(List<Product>) onExportPO;

  const InventoryReportView({
    super.key,
    required this.products,
    required this.filteredSales,
    required this.allSales,
    required this.dateRange,
    required this.onExportPO,
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

  Widget _buildDetailedInventoryPieChart(List<Product> products, bool isDark) {
    if (products.isEmpty) return const SizedBox();
    final outOfStock = products.where((p) => p.stock == 0).length;
    final lowStock = products.where((p) => p.stock > 0 && p.stock <= p.reorderLevel).length;
    final normal = products.length - outOfStock - lowStock;
    final total = products.length;

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2, centerSpaceRadius: 50,
              sections: [
                PieChartSectionData(color: isDark ? Colors.green[400] : Colors.green[500], value: normal.toDouble(), title: '${((normal/total)*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(color: isDark ? Colors.orange[400] : Colors.orange[500], value: lowStock.toDouble(), title: '${((lowStock/total)*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                if (outOfStock > 0)
                  PieChartSectionData(color: isDark ? Colors.red[400] : Colors.red[500], value: outOfStock.toDouble(), title: '${((outOfStock/total)*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              ]
            )
          )
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.circle, size: 10, color: isDark ? Colors.green[400] : Colors.green[500]), const SizedBox(width: 8), Text('Normal ($normal)', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black))]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.circle, size: 10, color: isDark ? Colors.orange[400] : Colors.orange[500]), const SizedBox(width: 8), Text('Low Stock ($lowStock)', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black))]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.circle, size: 10, color: isDark ? Colors.red[400] : Colors.red[500]), const SizedBox(width: 8), Text('Critical ($outOfStock)', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black))]),
          ],
        )
      ],
    );
  }

  Widget _buildDetailedCategoryBarChart(List<Product> products, bool isDark) {
    if (products.isEmpty) return const SizedBox();
    
    final catValue = <String, double>{};
    for (var p in products) {
      catValue[p.category] = (catValue[p.category] ?? 0) + (p.stock * p.price);
    }
    
    final sortedCats = catValue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCats = sortedCats.take(6).toList(); 
    
    final rawMax = topCats.isEmpty ? 100.0 : topCats.first.value * 1.3; 
    final maxY = rawMax <= 0 ? 100.0 : rawMax;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: false, 
          horizontalInterval: (maxY / 4) <= 0 ? 25.0 : (maxY / 4).ceilToDouble(),
          getDrawingHorizontalLine: (value) => FlLine(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, strokeWidth: 1),
        ),
        barTouchData: BarTouchData(
          enabled: false, 
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => isDark ? Colors.blueGrey[800]! : Colors.blueGrey[700]!,
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toStringAsFixed(0),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50, 
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
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < topCats.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(topCats[value.toInt()].key, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700]), overflow: TextOverflow.ellipsis),
                  );
                }
                return const SizedBox.shrink();
              }
            )
          )
        ),
        borderData: FlBorderData(show: false),
        barGroups: topCats.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value, 
                color: isDark ? Colors.blue[400] : Colors.blue[500], 
                width: 32, 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6))
              )
            ],
            showingTooltipIndicators: [0], 
          );
        }).toList(),
      )
    );
  }

  Widget _buildDeadStockRadar(List<Product> deadStock, bool isDark, Color textColor) {
    if (deadStock.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: isDark ? Colors.green[400] : Colors.green[300], size: 48),
            const SizedBox(height: 12),
            Text('No Dead Stock!', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
            Text('All inventory is moving perfectly.', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }

    final fmt = NumberFormat.currency(symbol: '₱');
    
    return ListView.separated(
      itemCount: deadStock.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
      itemBuilder: (context, index) {
        final p = deadStock[index];
        final lockedValue = p.stock * p.price;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor), overflow: TextOverflow.ellipsis),
          subtitle: Text('In Stock: ${p.stock}  •  Category: ${p.category}', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 11)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Value Locked', style: TextStyle(fontSize: 10, color: isDark ? Colors.red[300] : Colors.red)),
              Text(fmt.format(lockedValue), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.red[400] : Colors.red[700])),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRestockPlan(List<Product> itemsToOrder, bool isDark, Color textColor) {
    if (itemsToOrder.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, color: isDark ? Colors.green[400] : Colors.green[300], size: 48),
            const SizedBox(height: 12),
            Text('Inventory is Healthy', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
            Text('No items need to be ordered.', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }

    final fmt = NumberFormat.currency(symbol: '₱');
    
    return ListView.separated(
      itemCount: itemsToOrder.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
      itemBuilder: (context, index) {
        final p = itemsToOrder[index];
        int suggestedOrder = (p.reorderLevel * 2) - p.stock;
        if (suggestedOrder < 20) suggestedOrder = 20; 
        final estCost = suggestedOrder * (p.price * 0.60); 

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor), overflow: TextOverflow.ellipsis),
          subtitle: Row(
            children: [
              Text('Have: ${p.stock}', style: TextStyle(color: p.stock == 0 ? (isDark ? Colors.red[400] : Colors.red) : (isDark ? Colors.orange[400] : Colors.orange), fontWeight: FontWeight.bold, fontSize: 11)),
              Text('  •  Need: $suggestedOrder', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Est. Cost', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[500] : Colors.grey)),
              Text(fmt.format(estCost), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.orange[400] : Colors.orange[800])),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final fmt = NumberFormat.currency(symbol: '₱');
    
    final totalValue = products.fold(0.0, (sum, p) => sum + (p.price * p.stock));
    final expiredProducts = products.where((p) => p.status == 'Expired').toList();
    final spoilageValue = expiredProducts.fold(0.0, (sum, p) => sum + (p.price * p.stock));

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final last30DaysSales = allSales.where((s) => DateTime.parse(s.timestamp).isAfter(thirtyDaysAgo)).toList();
    final soldProductIds = last30DaysSales.expand((s) => s.items.map((i) => i.productId)).toSet();
    
    final deadStock = products.where((p) => p.stock > 0 && !soldProductIds.contains(p.id)).toList();
    deadStock.sort((a, b) => (b.price * b.stock).compareTo(a.price * a.stock)); 

    final lowStock = products.where((p) => p.stock > 0 && p.stock <= p.reorderLevel).toList();
    final outOfStock = products.where((p) => p.stock == 0).toList();
    final itemsToOrder = [...outOfStock, ...lowStock];
    
    double totalRestockCost = 0.0;
    for (var p in itemsToOrder) {
      int suggestedOrder = (p.reorderLevel * 2) - p.stock;
      if (suggestedOrder < 20) suggestedOrder = 20; 
      totalRestockCost += suggestedOrder * (p.price * 0.60);
    }

    final itemQtys = <String, int>{};
    final itemRevs = <String, double>{};
    for (var s in filteredSales) {
      for (var i in s.items) {
        itemQtys[i.productName] = (itemQtys[i.productName] ?? 0) + i.quantity;
        itemRevs[i.productName] = (itemRevs[i.productName] ?? 0) + i.subtotal;
      }
    }
    final sortedItems = itemQtys.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildKPI('Total Stock Value', fmt.format(totalValue), Colors.green, isDark),
            const SizedBox(width: 16),
            _buildKPI('Spoilage Loss (Expired)', fmt.format(spoilageValue), Colors.red, isDark),
            const SizedBox(width: 16),
            _buildKPI('Dead Stock Items', '${deadStock.length} items', Colors.purple, isDark),
            const SizedBox(width: 16),
            _buildKPI('Est. Restock Cost', fmt.format(totalRestockCost), Colors.orange, isDark),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Container(
                height: 360,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Top items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    Text('By units sold ($dateRange)', style: TextStyle(color: subTextColor, fontSize: 12)),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    if (topItems.isEmpty) Padding(padding: const EdgeInsets.all(16.0), child: Text('No items sold in this range.', style: TextStyle(color: textColor))),
                    Expanded(
                      child: ListView.builder(
                        itemCount: topItems.length,
                        itemBuilder: (ctx, index) {
                          final name = topItems[index].key;
                          final qty = topItems[index].value;
                          final rev = itemRevs[name] ?? 0.0;
                          final maxQty = topItems.first.value;
                          final progress = qty / maxQty;
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text('${index + 1}', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: textColor), overflow: TextOverflow.ellipsis)),
                                    Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: progress, minHeight: 6,
                                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100], color: isDark ? Colors.blue[400] : Colors.blue[600],
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    ),
                                    const SizedBox(width: 12),
                                    Text(fmt.format(rev), style: TextStyle(color: subTextColor, fontSize: 11)),
                                  ],
                                )
                              ],
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Container(
                height: 360,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Status Distribution', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildDetailedInventoryPieChart(products, isDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Container(
                height: 360,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.radar, color: isDark ? Colors.purple[400] : Colors.purple[600]),
                        const SizedBox(width: 8),
                        Text('Dead Stock Radar', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                    Text('0 sales in the last 30 days', style: TextStyle(color: subTextColor, fontSize: 12)),
                    const SizedBox(height: 16),
                    Expanded(child: _buildDeadStockRadar(deadStock, isDark, textColor)),
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
              flex: 1,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Value Locked by Category', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildDetailedCategoryBarChart(products, isDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.request_quote, color: isDark ? Colors.orange[400] : Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text('Restock Plan (PO)', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => onExportPO(itemsToOrder), 
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Export PO'),
                        )
                      ],
                    ),
                    Text('${itemsToOrder.length} items require reordering', style: TextStyle(color: subTextColor, fontSize: 12)),
                    const SizedBox(height: 16),
                    Expanded(child: _buildRestockPlan(itemsToOrder, isDark, textColor)),
                  ],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}