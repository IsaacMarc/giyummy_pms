import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as ex; // NEW: Excel Package
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/stat_card.dart'; 
import '../services/excel_service.dart';
import '../providers/app_provider.dart';
import 'package:provider/provider.dart';
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _reportType = 'Top Products';
  String _timeFilter = 'Last 7 Days';
  
  final List<String> _reportTypes = ['Sales Trend', 'Top Products', 'Categories', 'Low Performers'];
  final List<String> _timeFilters = ['Today', 'Last 7 Days', 'Last 30 Days'];

  // --- Data Processing Logic ---

  List<Sale> _getFilteredSales(List<Sale> allSales) {
    final now = DateTime.now();
    DateTime startDate;

    if (_timeFilter == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (_timeFilter == 'Last 7 Days') {
      startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    } else {
      startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    }

    return allSales.where((s) {
      final saleDate = DateTime.parse(s.timestamp);
      return saleDate.isAfter(startDate) || saleDate.isAtSameMomentAs(startDate);
    }).toList();
  }

  List<Map<String, dynamic>> _generateReportData(List<Sale> sales, List<Product> products) {
    final data = <Map<String, dynamic>>[];

    if (_reportType == 'Sales Trend') {
      final grouped = <String, double>{};
      for (var s in sales) {
        final date = s.timestamp.substring(0, 10);
        grouped[date] = (grouped[date] ?? 0) + s.finalTotal;
      }
      var sortedKeys = grouped.keys.toList()..sort();
      for (var key in sortedKeys) {
        data.add({'Date': key, 'Revenue': grouped[key]});
      }

    } else if (_reportType == 'Top Products' || _reportType == 'Low Performers') {
      final qtyMap = <String, int>{};
      final revMap = <String, double>{};
      
      for (var p in products) {
        qtyMap[p.id] = 0;
        revMap[p.id] = 0.0;
      }

      for (var s in sales) {
        for (var i in s.items) {
          qtyMap[i.productId] = (qtyMap[i.productId] ?? 0) + i.quantity;
          revMap[i.productId] = (revMap[i.productId] ?? 0) + i.subtotal;
        }
      }

      for (var p in products) {
        data.add({
          'Product': p.name,
          'Quantity Sold': qtyMap[p.id],
          'Revenue': revMap[p.id],
        });
      }

      if (_reportType == 'Top Products') {
        data.sort((a, b) => (b['Quantity Sold'] as int).compareTo(a['Quantity Sold'] as int));
      } else {
        data.sort((a, b) => (a['Quantity Sold'] as int).compareTo(b['Quantity Sold'] as int));
      }
      if (data.length > 20) data.removeRange(20, data.length);

    } else if (_reportType == 'Categories') {
      final catRev = <String, double>{};
      final catQty = <String, int>{};

      for (var s in sales) {
        for (var i in s.items) {
          final prod = products.firstWhere((p) => p.id == i.productId, orElse: () => products.first);
          final cat = prod.category;
          catQty[cat] = (catQty[cat] ?? 0) + i.quantity;
          catRev[cat] = (catRev[cat] ?? 0) + i.subtotal;
        }
      }

      for (var cat in catRev.keys) {
        data.add({
          'Category': cat,
          'Quantity Sold': catQty[cat],
          'Revenue': catRev[cat],
        });
      }
      data.sort((a, b) => (b['Revenue'] as double).compareTo(a['Revenue'] as double));
    }
    return data;
  }

  // --- EXCEL EXPORT LOGIC ---

  // Helper to dynamically convert Dart types to Excel Cell Values
  ex.CellValue _getCellValue(dynamic value) {
    if (value is String) return ex.TextCellValue(value);
    if (value is int) return ex.IntCellValue(value);
    if (value is double) return ex.DoubleCellValue(value);
    return ex.TextCellValue(value.toString());
  }

  Future<void> _exportCurrentToExcel(List<Map<String, dynamic>> reportData) async {
    if (reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    var excel = ex.Excel.createExcel();
    String sheetName = _reportType.replaceAll(' ', '');
    var sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // 1. Add Headers
    List<ex.CellValue> headers = reportData.first.keys.map((k) => ex.TextCellValue(k)).toList();
    sheet.appendRow(headers);

    // 2. Bold the Headers for organization
    for (int col = 0; col < headers.length; col++) {
      var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = ex.CellStyle(bold: true);
    }

    // 3. Add Data
    for (var row in reportData) {
      sheet.appendRow(row.values.map((v) => _getCellValue(v)).toList());
    }

    // 4. Save Excel File
    var fileBytes = excel.save();
    if (fileBytes == null) return;

    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Report as Excel',
      fileName: '${_reportType.replaceAll(' ', '_')}_${_timeFilter.replaceAll(' ', '_')}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputFile != null) {
      try {
        final file = File(outputFile);
        await file.writeAsBytes(fileBytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report exported to $outputFile'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAllRawDataToExcel(List<Sale> filteredSales, List<Product> products) async {
    if (filteredSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    var excel = ex.Excel.createExcel();
    var sheet = excel['Raw Sales Data'];
    excel.setDefaultSheet('Raw Sales Data');

    // 1. Add Detailed Headers
    List<String> headerNames = ['Date', 'Cashier', 'Payment Method', 'Product Category', 'Product Name', 'Quantity', 'Unit Price', 'Subtotal', 'Transaction Discount', 'Transaction Total'];
    sheet.appendRow(headerNames.map((h) => ex.TextCellValue(h)).toList());

    // 2. Bold the Headers
    for (int col = 0; col < headerNames.length; col++) {
      var cell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = ex.CellStyle(bold: true);
    }

    // 3. Flatten and Inject all Data
    for (var sale in filteredSales) {
      for (var item in sale.items) {
        final prod = products.firstWhere((p) => p.id == item.productId, orElse: () => products.first);
        sheet.appendRow([
          ex.TextCellValue(sale.timestamp),
          ex.TextCellValue(sale.cashierName),
          ex.TextCellValue(sale.paymentMethod),
          ex.TextCellValue(prod.category),
          ex.TextCellValue(item.productName),
          ex.IntCellValue(item.quantity),
          ex.DoubleCellValue(item.price),
          ex.DoubleCellValue(item.subtotal),
          ex.DoubleCellValue(sale.discount),
          ex.DoubleCellValue(sale.finalTotal)
        ]);
      }
    }

    // 4. Save Excel File
    var fileBytes = excel.save();
    if (fileBytes == null) return;

    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save All Data as Excel',
      fileName: 'All_Sales_Data_${_timeFilter.replaceAll(' ', '_')}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputFile != null) {
      try {
        final file = File(outputFile);
        await file.writeAsBytes(fileBytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All data exported to $outputFile'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Dynamic Chart Generator ---
  Widget _buildChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty || (data.every((e) => e['Revenue'] == 0 && e['Quantity Sold'] == 0))) {
      return Center(child: Text('Not enough data to display chart', style: TextStyle(color: Colors.grey[400])));
    }

    if (_reportType == 'Sales Trend') {
      return LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.blueGrey[800]!,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = data[spot.x.toInt()]['Date'];
                  return LineTooltipItem(
                    '$date\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: '\$${spot.y.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['Revenue'] as double)).toList(),
              isCurved: true,
              color: Colors.blue[700],
              barWidth: 4,
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
            ),
          ],
        ),
      );
    }

    if (_reportType == 'Categories') {
      return PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 60,
          sections: data.asMap().entries.map((e) {
            final color = Colors.primaries[e.key % Colors.primaries.length];
            return PieChartSectionData(
              color: color,
              value: e.value['Revenue'] as double,
              title: '${e.value['Category']}\n\$${(e.value['Revenue'] as double).toStringAsFixed(0)}',
              radius: 80,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      );
    }

    // Top Products & Low Performers (Bar Chart)
    final top10Data = data.take(10).toList(); 
    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey[800]!,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final productName = top10Data[group.x.toInt()]['Product'];
              return BarTooltipItem(
                '$productName\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: '${rod.toY.toInt()} sold',
                    style: const TextStyle(color: Colors.yellowAccent, fontSize: 13),
                  ),
                ],
              );
            },
          ),
        ),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
          ),
        borderData: FlBorderData(show: false),
        barGroups: top10Data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: (e.value['Quantity Sold'] as int).toDouble(),
                color: _reportType == 'Top Products' ? Colors.green[600] : Colors.orange[600],
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              )
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allSales = provider.getSales();
    final allProducts = provider.getProducts();

    final filteredSales = _getFilteredSales(allSales);
    final reportData = _generateReportData(filteredSales, allProducts);
    final fmt = NumberFormat.currency(symbol: '\$');

    double totalRevenue = 0.0;
    int totalItemsSold = 0;
    for (var s in filteredSales) {
      totalRevenue += s.finalTotal;
      for (var i in s.items) {
        totalItemsSold += i.quantity;
      }
    }
    int totalTransactions = filteredSales.length;
    double avgOrderValue = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Controls
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Row 1: Title and Actions
                  Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.blue[700], size: 28),
                      const SizedBox(width: 8),
                      const Text('System Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      const Spacer(),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _timeFilter,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            items: _timeFilters.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _timeFilter = v!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Export to Excel'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                        onPressed: () async {
                          // 1. Ask the user for the Timeframe using a dialog
                          final String? selectedTimeframe = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Select Export Timeframe'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.today, color: Colors.blue),
                                    title: const Text('Today'),
                                    onTap: () => Navigator.pop(ctx, 'Today'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.date_range, color: Colors.orange),
                                    title: const Text('7 Days'),
                                    onTap: () => Navigator.pop(ctx, '7 Days'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.calendar_month, color: Colors.purple),
                                    title: const Text('30 Days'),
                                    onTap: () => Navigator.pop(ctx, '30 Days'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.all_inclusive, color: Colors.green),
                                    title: const Text('All Time'),
                                    onTap: () => Navigator.pop(ctx, 'All Time'),
                                  ),
                                ],
                              ),
                            ),
                          );

                          // If they clicked outside the dialog to cancel, stop here
                          if (selectedTimeframe == null) return;

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Generating $selectedTimeframe Report...')),
                          );

                          // 2. Pass the selected timeframe into your new Excel Service
                          final provider = context.read<AppProvider>();
                          final error = await ExcelService.exportMasterReport(
                            provider.getSales(), 
                            provider.getProducts(), 
                            selectedTimeframe // <--- Pass the choice here!
                          );

                          if (!context.mounted) return;
                          
                          if (error == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report Saved Successfully!'), backgroundColor: Colors.green),
                            );
                          } else if (error != 'Cancelled by user') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error), backgroundColor: Colors.red),
                            );
                          }
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Row 2: Statistics Cards 
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Total Revenue',
                          value: fmt.format(totalRevenue),
                          icon: Icons.attach_money,
                          color: Colors.green,
                          background_icon_color: const Color.fromARGB(255, 145, 255, 149),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatCard(
                          title: 'Transactions',
                          value: '$totalTransactions',
                          icon: Icons.receipt_long,
                          color: Colors.blue,
                          background_icon_color: const Color.fromARGB(255, 166, 227, 255),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatCard(
                          title: 'Items Sold',
                          value: '$totalItemsSold',
                          icon: Icons.inventory_2_outlined,
                          color: Colors.orange,
                          background_icon_color: const Color.fromARGB(255, 255, 211, 146),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatCard(
                          title: 'Avg Order Value',
                          value: fmt.format(avgOrderValue),
                          icon: Icons.analytics_outlined,
                          color: Colors.purple,
                          background_icon_color: const Color.fromARGB(255, 230, 180, 255),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Row 3: Chart View Selection Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _reportTypes.map((type) {
                        final isSelected = _reportType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _reportType = type);
                            },
                            selectedColor: Colors.blue[100],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.blue[900] : Colors.grey[700],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // --- The Data Presentation Area ---
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual Chart Area (Left Side)
                Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('$_reportType Chart', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          Expanded(child: _buildChart(reportData)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Raw Data Table Area (Right Side)
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Raw Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Divider(),
                          Expanded(
                            child: reportData.isEmpty
                              ? Center(child: Text('No data.', style: TextStyle(color: Colors.grey[400])))
                              : SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                                      dataRowMinHeight: 35,
                                      dataRowMaxHeight: 35,
                                      columnSpacing: 20,
                                      columns: reportData.first.keys.map((key) => DataColumn(
                                            label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold))
                                          )).toList(),
                                      rows: reportData.map((row) {
                                        return DataRow(
                                          cells: row.entries.map((entry) {
                                            final val = entry.key == 'Revenue' 
                                                ? fmt.format(entry.value) 
                                                : entry.value.toString();
                                            return DataCell(
                                              SizedBox(
                                                width: 100, 
                                                child: Text(val, overflow: TextOverflow.ellipsis)
                                              )
                                            );
                                          }).toList(),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
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