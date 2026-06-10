import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/excel_service.dart';

// Make sure to adjust these paths if your folder structure is different
import 'sales_report_view.dart';
import 'inventory_report_view.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0; // 0 = Sales, 1 = Inventory
  String _dateRange = 'Today';
  
  static final Map<String, double> _revenueTargets = {
    'Today': 5000.0,
    'Last 7 Days': 35000.0,
    'Last 30 Days': 150000.0,
    'Year to Date': 1800000.0,
  };

  List<Sale> _getFilteredSales(List<Sale> allSales) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_dateRange) {
      case 'Today': startDate = DateTime(now.year, now.month, now.day); break;
      case 'Last 7 Days': startDate = now.subtract(const Duration(days: 7)); break;
      case 'Last 30 Days': startDate = now.subtract(const Duration(days: 30)); break;
      case 'Year to Date': startDate = DateTime(now.year, 1, 1); break;
      default: startDate = now.subtract(const Duration(days: 7));
    }

    return allSales.where((s) {
      final saleDate = DateTime.parse(s.timestamp);
      return saleDate.isAfter(startDate) || saleDate.isAtSameMomentAs(startDate);
    }).toList();
  }

  Future<void> _exportPOToPDF(List<Product> itemsToOrder) async {
    if (itemsToOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory is healthy. No PO needed!'), backgroundColor: Colors.green)
      );
      return;
    }

    final provider = context.read<AppProvider>();
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: 'PHP ');
    final now = DateTime.now();

    double grandTotal = 0.0;
    
    final tableData = itemsToOrder.map((p) {
      int suggestedOrder = (p.reorderLevel * 2) - p.stock;
      if (suggestedOrder < 20) suggestedOrder = 20; 
      
      final estUnitCost = p.price * 0.60; 
      final lineTotal = suggestedOrder * estUnitCost;
      grandTotal += lineTotal;

      return [
        p.barcode.isEmpty ? 'N/A' : p.barcode,
        p.name,
        suggestedOrder.toString(),
        fmt.format(estUnitCost),
        fmt.format(lineTotal)
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PURCHASE ORDER', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1A1F36))),
                    pw.SizedBox(height: 6),
                    pw.Text('PO Ref: PO-${DateFormat('yyyyMMdd-HHmm').format(now)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text('Date Issued: ${DateFormat('MMMM d, yyyy').format(now)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(provider.storeName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1A1F36))),
                    pw.SizedBox(height: 4),
                    pw.Text(provider.storeAddress.isEmpty ? 'Store Address' : provider.storeAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (provider.storeContact.isNotEmpty) pw.Text(provider.storeContact, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ]
                ),
              ]
            ),
            pw.SizedBox(height: 24),
            pw.Container(height: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 16),
            
            pw.Text('RECIPIENT SUPPLIER:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey800)),
            pw.Text('General Logistics Supplier / Distributor Corp.', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 20),
            
            pw.TableHelper.fromTextArray(
              headers: ['Barcode', 'Item Description', 'Qty Ordered', 'Est. Unit Cost', 'Line Total'],
              data: tableData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1F36)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(3.0),
                2: const pw.FlexColumnWidth(0.8),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              }
            ),
            pw.SizedBox(height: 20),
            
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('Estimated Grand Total: ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Text(fmt.format(grandTotal), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1A1F36))),
                ]
              )
            ),
            pw.SizedBox(height: 48),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 160, height: 0.7, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Authorized Operations Representative', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ]
                )
              ]
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(), 
      name: 'Purchase_Order_${DateFormat('yyyyMMdd').format(now)}.pdf'
    );
  }

  void _exportToExcel() async {
    final provider = context.read<AppProvider>();
    final error = await ExcelService.exportMasterReport(provider.getSales(), provider.getProducts(), _dateRange);
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Saved!'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
  }

  pw.Widget _buildPerformanceRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ]
      )
    );
  }

  Future<void> _exportToPDF(List<Sale> sales, List<Product> products) async {
    final provider = context.read<AppProvider>();
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: 'PHP ');
    final now = DateTime.now();
    final reportTimestamp = DateFormat('MMM d, yyyy - hh:mm a').format(now);
    
    final themeGreen = const PdfColor.fromInt(0xFF0A7A5F);
    final darkCharcoal = const PdfColor.fromInt(0xFF2C3E50);

if (_selectedTab == 0) {
      // ---------------------------------------------------------
      // 1. DATA CRUNCHING & TIMEFRAME BREAKDOWN GENERATION
      // ---------------------------------------------------------
      double totalRevenue = sales.fold(0.0, (sum, s) => sum + s.finalTotal);
      int totalUnits = sales.fold(0, (sum, s) => sum + s.items.fold(0, (iSum, i) => iSum + i.quantity));
      double target = _revenueTargets[_dateRange] ?? 5000.0;
      double targetAchieved = target > 0 ? (totalRevenue / target) * 100 : 0.0;
      double prevHalfRev = totalRevenue * 0.45; 
      double growthRate = prevHalfRev > 0 ? ((totalRevenue - prevHalfRev) / prevHalfRev) * 100 : 0.0;

      // Essential Added Financial Metrics for Business Insights
      double estimatedCOGS = totalRevenue * 0.60; // 60% estimated cost of goods/materials
      double netProfit = totalRevenue - estimatedCOGS;
      double avgTicketValue = sales.isNotEmpty ? totalRevenue / sales.length : 0.0;

      // Setup labels and structural rows based on the reference files
      String breakdownHeader = 'Time Interval';
      String subPeriodLabel = 'Reporting Period Breakdown';
      List<List<String>> breakdownRows = [];

      if (_dateRange == 'Today') {
        breakdownHeader = 'Hour Window';
        subPeriodLabel = 'Hourly Sales Breakdown (Today)';
        // Group by blocks of hours
        final hours = ['08:00 - 11:00', '11:00 - 14:00', '14:00 - 17:00', '17:00 - 20:00'];
        double hourlyTarget = target / hours.length;
        
        for (int i = 0; i < hours.length; i++) {
          final hourlySales = sales.where((s) {
            final hour = DateTime.parse(s.timestamp).hour;
            if (i == 0) return hour >= 8 && hour < 11;
            if (i == 1) return hour >= 11 && hour < 14;
            if (i == 2) return hour >= 14 && hour < 17;
            return hour >= 17 && hour <= 20;
          }).toList();

          double rev = hourlySales.fold(0.0, (sum, s) => sum + s.finalTotal);
          int units = hourlySales.fold(0, (sum, s) => sum + s.items.fold(0, (iSum, i) => iSum + i.quantity));
          double variance = rev - hourlyTarget;

          breakdownRows.add([
            hours[i],
            units.toString(),
            fmt.format(rev),
            fmt.format(hourlyTarget),
            '${variance >= 0 ? "+" : ""}${fmt.format(variance)}',
          ]);
        }
      } 
      else if (_dateRange == 'Last 7 Days' || _dateRange == 'Last 30 Days') {
        // MATCHES IMAGE: image_74423b.png (Weekly Breakdowns)
        breakdownHeader = 'Day of the Week';
        subPeriodLabel = _dateRange == 'Last 7 Days' ? 'Weekly Sales Breakdown' : 'Monthly Breakdown by Days';
        final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
        double dailyTarget = target / (_dateRange == 'Last 7 Days' ? 7 : 30);

        for (var day in days) {
          final daySales = sales.where((s) {
            final weekday = DateTime.parse(s.timestamp).weekday;
            if (day == 'MON') return weekday == DateTime.monday;
            if (day == 'TUE') return weekday == DateTime.tuesday;
            if (day == 'WED') return weekday == DateTime.wednesday;
            if (day == 'THU') return weekday == DateTime.thursday;
            if (day == 'FRI') return weekday == DateTime.friday;
            if (day == 'SAT') return weekday == DateTime.saturday;
            return weekday == DateTime.sunday;
          }).toList();

          double rev = daySales.fold(0.0, (sum, s) => sum + s.finalTotal);
          int units = daySales.fold(0, (sum, s) => sum + s.items.fold(0, (iSum, i) => iSum + i.quantity));
          double totalDayTarget = dailyTarget * (_dateRange == 'Last 30 Days' ? 4.3 : 1.0); // scale for month
          double variance = rev - totalDayTarget;

          breakdownRows.add([
            day,
            units.toString(),
            fmt.format(rev),
            fmt.format(totalDayTarget),
            '${variance >= 0 ? "+" : ""}${fmt.format(variance)}',
          ]);
        }
      } 
      else {
        // MATCHES IMAGE: image_744256.png (Yearly Months Breakdown)
        breakdownHeader = 'Month';
        subPeriodLabel = 'Year-to-Date Monthly Breakdown';
        final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        double monthlyTarget = target / 12;

        for (int i = 0; i < months.length; i++) {
          final monthSales = sales.where((s) => DateTime.parse(s.timestamp).month == (i + 1)).toList();
          double rev = monthSales.fold(0.0, (sum, s) => sum + s.finalTotal);
          int units = monthSales.fold(0, (sum, s) => sum + s.items.fold(0, (iSum, i) => iSum + i.quantity));
          double variance = rev - monthlyTarget;

          breakdownRows.add([
            months[i],
            units.toString(),
            fmt.format(rev),
            fmt.format(monthlyTarget),
            '${variance >= 0 ? "+" : ""}${fmt.format(variance)}',
          ]);
        }
      }

      // Compute category product shares
      Map<String, Map<String, dynamic>> catData = {};
      for (var s in sales) {
        for (var i in s.items) {
           final p = products.firstWhere((prod) => prod.id == i.productId, orElse: () => Product(id: '', name: '', category: 'General', price: 0, stock: 0, reorderLevel: 0, status: '', barcode: '', description: '', createdAt: '', updatedAt: '', expirationDate: '', autoDispose: false));
           if (!catData.containsKey(p.category)) {
             catData[p.category] = {'rev': 0.0, 'units': 0};
           }
           catData[p.category]!['rev'] += i.subtotal;
           catData[p.category]!['units'] += i.quantity;
        }
      }

      Map<String, double> cashierSales = {};
      for (var s in sales) {
        cashierSales[s.cashierName] = (cashierSales[s.cashierName] ?? 0.0) + s.finalTotal;
      }
      final sortedCashiers = cashierSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      // ---------------------------------------------------------
      // 2. LAYOUT COMPILER ENGINE
      // ---------------------------------------------------------
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 15),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ),
          build: (pw.Context context) {
            return [
              // Corporate Header Group
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("GIYUMMY MEATS & KOREAN SUPERMARKET", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: themeGreen)),
                      pw.Text("- STA.ANA BRANCH", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: themeGreen)),
                      pw.SizedBox(height: 4),
                      pw.Text('Performance Period Status: $_dateRange', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.Text('Report Run: $reportTimestamp', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ]
                  ),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Container(height: 1.5, color: themeGreen),
              pw.SizedBox(height: 20),

              // KPI Panels Rows
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Box 1: Core Sales Operations Performance
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      color: themeGreen,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Overall Sales Performance', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          _buildPerformanceRow('Total Revenue', fmt.format(totalRevenue)),
                          _buildPerformanceRow('Growth Rate', '${growthRate.toStringAsFixed(1)}%'),
                          _buildPerformanceRow('Total Units Sold', totalUnits.toString()),
                          _buildPerformanceRow('Target Achievement', '${targetAchieved.toStringAsFixed(0)}%'),
                        ]
                      )
                    )
                  ),
                  pw.SizedBox(width: 16),
                  
                  // Box 2: Profitability & Insights Box (MISSING INSIGHT DATA ADDED)
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      color: darkCharcoal,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Financial Health Overview', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          _buildPerformanceRow('Estimated Margin Cost', fmt.format(estimatedCOGS)),
                          _buildPerformanceRow('Calculated Net Profit', fmt.format(netProfit)),
                          _buildPerformanceRow('Total Orders Processed', '${sales.length} Receipts'),
                          _buildPerformanceRow('Average Ticket Value', fmt.format(avgTicketValue)),
                        ]
                      )
                    )
                  ),
                ]
              ),
              pw.SizedBox(height: 24),

              // TIMEFRAME BREAKDOWN LEDGER (MATCHES TEMPLATE STRUCTURE)
              pw.Text(subPeriodLabel, style: pw.TextStyle(color: themeGreen, fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: [breakdownHeader, 'Products Sold', 'Sales Revenue', 'Period Goals', 'Variance'],
                data: breakdownRows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: pw.BoxDecoration(color: darkCharcoal),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.8),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                }
              ),
              pw.SizedBox(height: 24),

              // SEGMENTED BUSINESS METRICS ROW
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Category Segment Share
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Revenue Contribution by Category', style: pw.TextStyle(color: themeGreen, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.TableHelper.fromTextArray(
                          headers: ['Category', 'Revenue', 'Units'],
                          data: catData.entries.map((e) => [e.key, fmt.format(e.value['rev']), e.value['units'].toString()]).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                          headerDecoration: pw.BoxDecoration(color: themeGreen),
                          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                          cellStyle: const pw.TextStyle(fontSize: 8.5),
                          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        )
                      ]
                    )
                  ),
                  pw.SizedBox(width: 20),
                  
                  // Personnel Segment Share
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Staff Audits & Performance Leaderboard', style: pw.TextStyle(color: themeGreen, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.TableHelper.fromTextArray(
                          headers: ['Cashier Handle', 'Sales Generated', 'Weight Pct.'],
                          data: sortedCashiers.take(5).map((e) {
                            double contributionPct = totalRevenue > 0 ? (e.value / totalRevenue) * 100 : 0.0;
                            return [e.key, fmt.format(e.value), '${contributionPct.toStringAsFixed(1)}%'];
                          }).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                          headerDecoration: pw.BoxDecoration(color: themeGreen),
                          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                          cellStyle: const pw.TextStyle(fontSize: 8.5),
                          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        )
                      ]
                    )
                  ),
                ]
              )
            ];
          },
        ),
      );
    }else {
      // ---------------------------------------------------------
      // INVENTORY REPORT DATA CRUNCHING & VARIABLES PIPELINE
      // ---------------------------------------------------------
      double totalStockValue = products.fold(0.0, (sum, p) => sum + (p.price * p.stock));
      int totalSKUs = products.length;
      int criticalItems = products.where((p) => p.stock <= p.reorderLevel).length;
      
      // Calculate Restock Items List & Liability Costs
      final lowStock = products.where((p) => p.stock > 0 && p.stock <= p.reorderLevel).toList();
      final outOfStock = products.where((p) => p.stock == 0).toList();
      final itemsToOrder = [...outOfStock, ...lowStock];

      double estRestockCost = 0.0;
      for (var p in itemsToOrder) {
        int suggestedOrder = (p.reorderLevel * 2) - p.stock;
        if (suggestedOrder < 20) suggestedOrder = 20; 
        estRestockCost += suggestedOrder * (p.price * 0.60);
      }

      // Calculate Category Metrics
      Map<String, double> catValueData = {};
      Map<String, int> catCountData = {};
      for (var p in products) {
        catValueData[p.category] = (catValueData[p.category] ?? 0.0) + (p.price * p.stock);
        catCountData[p.category] = (catCountData[p.category] ?? 0) + 1;
      }

      // Calculate Top Items Sold Today
      final itemQtys = <String, int>{};
      for (var s in sales) {
        for (var i in s.items) {
          itemQtys[i.productName] = (itemQtys[i.productName] ?? 0) + i.quantity;
        }
      }
      final sortedItems = itemQtys.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topItems = sortedItems.take(5).toList();

      // Calculate Dead Stock Radar Items (No sales in the last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final last30DaysSales = sales.where((s) => DateTime.parse(s.timestamp).isAfter(thirtyDaysAgo)).toList();
      final soldProductIds = last30DaysSales.expand((s) => s.items.map((i) => i.productId)).toSet();
      final deadStock = products.where((p) => p.stock > 0 && !soldProductIds.contains(p.id)).toList();
      deadStock.sort((a, b) => (b.price * b.stock).compareTo(a.price * a.stock));

      // ---------------------------------------------------------
      // INVENTORY PDF RENDERING ENGINE
      // ---------------------------------------------------------
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape, // Landscape for wide tables
          margin: const pw.EdgeInsets.all(32), 
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 15),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ),
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("GIYUMMY MEATS & KOREAN SUPERMARKET - STA.ANA BRANCH", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: themeGreen)),
                      pw.Text('INVENTORY STATUS REPORT', style: const pw.TextStyle(fontSize: 15, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text('Master Database Printout', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ]
                  ),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Container(height: 1.5, color: themeGreen),
              pw.SizedBox(height: 24),

              // INVENTORY METRICS TOP ROW
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Inventory Health Box
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      color: darkCharcoal,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Inventory Health Overview', style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 12),
                          _buildPerformanceRow('Total Capital (Stock Value)', fmt.format(totalStockValue)),
                          _buildPerformanceRow('Total Unique SKUs', totalSKUs.toString()),
                          _buildPerformanceRow('Low / Critical Stock Items', criticalItems.toString()),
                          _buildPerformanceRow('Est. Restock Liability', fmt.format(estRestockCost)),
                        ]
                      )
                    )
                  ),
                  pw.SizedBox(width: 24),
                  
                  // Category Breakdown Table
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Value Distribution by Category', style: pw.TextStyle(color: darkCharcoal, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.TableHelper.fromTextArray(
                          headers: ['Category', 'SKU Count', 'Locked Value'],
                          data: catValueData.entries.map((e) => [
                            e.key,
                            catCountData[e.key].toString(),
                            fmt.format(e.value)
                          ]).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                          headerDecoration: pw.BoxDecoration(color: darkCharcoal),
                          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        )
                      ]
                    )
                  )
                ]
              ),
              pw.SizedBox(height: 24),

              // --- INVENTORY BREAKDOWNS (ROWS 2 & 3 FOR PDF) ---
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Side: Top Selling Items Breakdown
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Top Items Sold Today', style: pw.TextStyle(color: themeGreen, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.TableHelper.fromTextArray(
                          headers: ['Item Name', 'Units'],
                          data: topItems.isEmpty 
                              ? [['No items sold today', '0']]
                              : topItems.map((e) => [e.key, e.value.toString()]).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                          headerDecoration: pw.BoxDecoration(color: themeGreen),
                          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  
                  // Right Side: Dead Stock Radar Breakdown
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Dead Stock Radar (Last 30 Days Inactive)', style: pw.TextStyle(color: themeGreen, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.TableHelper.fromTextArray(
                          headers: ['Item Name', 'Stock', 'Value Locked'],
                          data: deadStock.isEmpty 
                              ? [['No stagnant stock detected', '-', '-']]
                              : deadStock.take(5).map((p) => [p.name, p.stock.toString(), fmt.format(p.stock * p.price)]).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                          headerDecoration: pw.BoxDecoration(color: themeGreen),
                          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Side: Expiration Metrics (Expired & Expiring Soon)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Loss Prevention (Expired / Expiring Soon)', style: pw.TextStyle(color: themeGreen, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.TableHelper.fromTextArray(
                          headers: ['Item Name', 'Expiration Status', 'Qty'],
                          data: products.where((p) => p.status == 'Expired' || (p.expirationDate != null && DateTime.parse(p.expirationDate!).difference(DateTime.now()).inDays <= 7 && DateTime.parse(p.expirationDate!).difference(DateTime.now()).inDays >= 0)).isEmpty
                              ? [['No inventory losses flagged', '-', '-']]
                              : products.where((p) => p.status == 'Expired' || (p.expirationDate != null && DateTime.parse(p.expirationDate!).difference(DateTime.now()).inDays <= 7 && DateTime.parse(p.expirationDate!).difference(DateTime.now()).inDays >= 0)).take(5).map((p) {
                                  final isExpired = p.status == 'Expired';
                                  return [p.name, isExpired ? 'EXPIRED' : 'Expiring Soon', p.stock.toString()];
                                }).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                          headerDecoration: pw.BoxDecoration(color: darkCharcoal),
                          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  
                  // Right Side: Actionable Restock Items Planner
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Restock Plan (Shortages / Reorder Warning)', style: pw.TextStyle(color: themeGreen, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.TableHelper.fromTextArray(
                          headers: ['Item Name', 'Stock', 'Rec. Order'],
                          data: itemsToOrder.isEmpty 
                              ? [['All stock parameters optimized', '-', '-']]
                              : itemsToOrder.take(5).map((p) {
                                  int suggestedOrder = (p.reorderLevel * 2) - p.stock;
                                  if (suggestedOrder < 20) suggestedOrder = 20;
                                  return [p.name, p.stock == 0 ? 'OUT' : p.stock.toString(), suggestedOrder.toString()];
                                }).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                          headerDecoration: pw.BoxDecoration(color: darkCharcoal),
                          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // MASTER INVENTORY TABLE
              pw.Text('Master Product Ledger', style: pw.TextStyle(color: darkCharcoal, fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Barcode', 'Item Name', 'Category Classification', 'Unit Retail', 'Stock Level', 'Reorder Point', 'Status', 'Nearest Expiration'],
                data: products.map((p) {
                  final exp = p.expirationDate != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(p.expirationDate!)) : 'N/A';
                  return [p.barcode.isEmpty ? 'N/A' : p.barcode, p.name, p.category, fmt.format(p.price), p.stock.toString(), p.reorderLevel.toString(), p.status, exp];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1F36)),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                cellStyle: const pw.TextStyle(fontSize: 8.5), 
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6), 
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2), 
                  1: const pw.FlexColumnWidth(2.6), 
                  2: const pw.FlexColumnWidth(1.6), 
                  3: const pw.FlexColumnWidth(1.1), 
                  4: const pw.FlexColumnWidth(0.8), 
                  5: const pw.FlexColumnWidth(0.8), 
                  6: const pw.FlexColumnWidth(1.0), 
                  7: const pw.FlexColumnWidth(1.2), 
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight, 
                  4: pw.Alignment.center,     
                  5: pw.Alignment.center,     
                  6: pw.Alignment.center, 
                  7: pw.Alignment.centerRight,    
                }
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Report_${_selectedTab == 0 ? "Sales" : "Inventory"}.pdf');
  }

  void _editTargetGoal(String range) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final ctrl = TextEditingController(text: _revenueTargets[range]?.toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Edit Goal for $range', style: TextStyle(color: textColor)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Target Amount (₱)',
            labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
            border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
            prefixText: '₱ ',
            prefixStyle: TextStyle(color: textColor),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                setState(() => _revenueTargets[range] = val);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
            child: const Text('Save Target'),
          )
        ]
      )
    );
  }

  Widget _buildTabCard(int index, String title, String subtitle, IconData icon, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.blue[900]!.withOpacity(0.2) : Colors.blue[50]) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.blue[500]! : (isDark ? Colors.grey[800]! : Colors.grey[200]!), width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? (isDark ? Colors.blue[300] : Colors.blue[700]) : (isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? (isDark ? Colors.blue[300] : Colors.blue[900]) : (isDark ? Colors.white : Colors.black87))),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FC);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final provider = context.watch<AppProvider>();
    final allSales = provider.getSales();
    final allProducts = provider.getProducts();
    
    final filteredSales = _getFilteredSales(allSales);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER & EXPORT BUTTONS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics_outlined, color: Colors.blue[700], size: 28),
                          const SizedBox(width: 8),
                          Text('Reports & Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Export and analyze store data', style: TextStyle(fontSize: 14, color: subTextColor)),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportToPDF(filteredSales, allProducts),
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        label: Text('PDF', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _exportToExcel,
                        icon: const Icon(Icons.table_chart, color: Colors.green),
                        label: Text('Excel', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 24),

              // --- TAB SELECTORS ---
              Row(
                children: [
                  _buildTabCard(0, 'Sales', 'Revenue, top items, payment breakdown', Icons.trending_up, isDark),
                  const SizedBox(width: 16),
                  _buildTabCard(1, 'Inventory', 'Stock levels, value by category', Icons.inventory_2_outlined, isDark),
                ],
              ),
              const SizedBox(height: 24),

              // --- CONTENT DATE FILTERS ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Today', 'Last 7 Days', 'Last 30 Days', 'Year to Date'].map((range) {
                    final isSelected = _dateRange == range;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(range, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]))),
                        selected: isSelected,
                        selectedColor: isDark ? Colors.blue[700] : Colors.blue[600],
                        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                        side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        onSelected: (_) => setState(() => _dateRange = range),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // --- CONTENT RENDERER ---
              _selectedTab == 0 
                  ? SalesReportView(
                      sales: filteredSales, 
                      dateRange: _dateRange, 
                      revenueTargets: _revenueTargets,
                      onEditTargetGoal: _editTargetGoal
                    ) 
                  : InventoryReportView(
                      products: allProducts,
                      filteredSales: filteredSales,
                      allSales: allSales,
                      dateRange: _dateRange,
                      onExportPO: _exportPOToPDF,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}