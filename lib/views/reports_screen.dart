import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/excel_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0; // 0 = Sales, 1 = Inventory
  String _dateRange = 'Today';
  
  // NEW: Static map keeps goals saved persistently across tab switches!
  static final Map<String, double> _revenueTargets = {
    'Today': 5000.0,
    'Last 7 Days': 35000.0,
    'Last 30 Days': 150000.0,
    'Year to Date': 1800000.0,
  };

  // --- DATA FILTERING ---
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

// --- PURCHASE ORDER PDF EXPORT ---
  Future<void> _exportPOToPDF(List<Product> itemsToOrder) async {
    if (itemsToOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory is healthy. No PO needed!'), backgroundColor: Colors.green)
      );
      return;
    }

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
        build: (pw.Context context) {
          return [
            // PO Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PURCHASE ORDER', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1976D2))),
                    pw.SizedBox(height: 4),
                    pw.Text('PO Number: PO-${DateFormat('yyyyMMdd-HHmm').format(now)}'),
                    pw.Text('Date: ${DateFormat.yMMMd().format(now)}'),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('STORE SYSTEM', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Store Address Line 1'),
                    pw.Text('Store Contact Info'),
                  ]
                ),
              ]
            ),
            pw.SizedBox(height: 32),
            
            pw.Text('TO SUPPLIER:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('General Supplier / Distributor'),
            pw.SizedBox(height: 24),
            
            pw.TableHelper.fromTextArray(
              headers: ['Barcode', 'Item Description', 'Qty Ordered', 'Est. Unit Cost', 'Line Total'],
              data: tableData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1F36)),
              cellStyle: const pw.TextStyle(fontSize: 10),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              }
            ),
            pw.SizedBox(height: 24),
            
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('Estimated PO Total: ', style: const pw.TextStyle(fontSize: 14)),
                  pw.Text(fmt.format(grandTotal), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ]
              )
            ),
            pw.SizedBox(height: 40),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Authorized Signature'),
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

  Future<void> _exportToPDF(List<Sale> sales, List<Product> products) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: 'PHP ');

    if (_selectedTab == 0) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Sales Report ($_dateRange)')),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Date/Time', 'TXN ID', 'Cashier', 'Products', 'Total'],
                data: sales.map((s) {
                  final time = DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(s.timestamp));
                  final productList = s.items.map((i) => '${i.quantity}x ${i.productName}').join(', ');
                  return [time, s.id.substring(0, 8).toUpperCase(), s.cashierName, productList, fmt.format(s.finalTotal)];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1F36)),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(3.0), 
                  4: const pw.FlexColumnWidth(1.0),
                }
              ),
            ];
          },
        ),
      );
    } else {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.all(20), 
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Complete Inventory Status')),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Barcode', 'Item Name', 'Category', 'Price', 'Stock', 'Reorder', 'Status', 'Expiration'],
                data: products.map((p) {
                  final exp = p.expirationDate != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(p.expirationDate!)) : 'N/A';
                  return [p.barcode.isEmpty ? 'N/A' : p.barcode, p.name, p.category, fmt.format(p.price), p.stock.toString(), p.reorderLevel.toString(), p.status, exp];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1F36)),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellStyle: const pw.TextStyle(fontSize: 8), 
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.2), 
                  1: const pw.FlexColumnWidth(0.2), 
                  2: const pw.FlexColumnWidth(0.2), 
                  3: const pw.FlexColumnWidth(0.2), 
                  4: const pw.FlexColumnWidth(0.2), 
                  5: const pw.FlexColumnWidth(0.2), 
                  6: const pw.FlexColumnWidth(0.2), 
                  7: const pw.FlexColumnWidth(0.2), 
                },
                cellAlignments: {
                  3: pw.Alignment.center, 
                  4: pw.Alignment.center,     
                  5: pw.Alignment.center,     
                  6: pw.Alignment.center,     
                }
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Report_${_selectedTab == 0 ? "Sales" : "Inventory"}.pdf');
  }

  // --- NEW: Edit Target Goal Dialog ---
  void _editTargetGoal(BuildContext context, String range, Color textColor, Color borderColor) {
    final ctrl = TextEditingController(text: _revenueTargets[range]?.toStringAsFixed(0));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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

              // --- CONTENT RENDERER ---
              _selectedTab == 0 
                  ? _buildSalesView(filteredSales, isDark, textColor, subTextColor) 
                  : _buildInventoryView(allProducts, filteredSales, allSales, isDark, textColor, subTextColor),
            ],
          ),
        ),
      ),
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

  // ==========================================
  // SALES VIEW
  // ==========================================
  Widget _buildSalesView(List<Sale> sales, bool isDark, Color textColor, Color subTextColor) {
    final fmt = NumberFormat.currency(symbol: '₱');
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    
    final totalRevenue = sales.fold(0.0, (sum, s) => sum + s.finalTotal);
    final totalDiscounts = sales.fold(0.0, (sum, s) => sum + s.discount);
    final totalCOGS = sales.fold(0.0, (sum, s) => sum + (s.finalTotal * 0.70)); 
    final trueProfit = totalRevenue - totalCOGS;

    // --- NEW: Grab the specific target for the selected date range ---
    final targetGoal = _revenueTargets[_dateRange] ?? 5000.0;
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
        // Date Filters
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

        // --- ENHANCED KPIs ---
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

        // --- ROW 1: REVENUE TREND & CASHIER LEADERBOARD ---
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

        // --- ROW 2: PEAK HOURS & PAYMENT MIX ---
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
                    Text(_dateRange, style: TextStyle(color: subTextColor, fontSize: 12)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildPaymentMixChart(paymentMix, isDark)),
                    const SizedBox(height: 16),
                    
                    // --- NEW: Detailed Payment Breakdown ---
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

        // --- ROW 3: SALES GOAL ---
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
                      Text(_dateRange, style: TextStyle(color: subTextColor, fontSize: 13)),
                    ],
                  ),
                  // --- NEW: Editable Goal Button ---
                  OutlinedButton.icon(
                    onPressed: () => _editTargetGoal(context, _dateRange, textColor, borderColor),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Goal'),
                    style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.blue[400] : Colors.blue[700], side: BorderSide(color: isDark ? Colors.blue[900]! : Colors.blue[200]!)),
                  )
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  // --- NEW: Enlarged Goal Ring ---
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

  // ==========================================
  // INVENTORY VIEW
  // ==========================================
  Widget _buildInventoryView(List<Product> products, List<Sale> filteredSales, List<Sale> allSales, bool isDark, Color textColor, Color subTextColor) {
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
                    Text('By units sold ($_dateRange)', style: TextStyle(color: subTextColor, fontSize: 12)),
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
                          onPressed: () => _exportPOToPDF(itemsToOrder), 
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

    // Prevent crashing on empty or zero lines
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
            title: '', // Keep donut clean
            radius: 20,
          );
        }).toList()
      )
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
                if (value == 0 || value % 1 != 0) return const SizedBox.shrink(); // Only whole numbers
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
}