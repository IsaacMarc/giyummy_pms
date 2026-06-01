import 'package:flutter/material.dart';
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
  String _dateRange = 'Last 7 Days';
  
  final double _dailyRevenueTarget = 5000.0;
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

// --- NEW: PURCHASE ORDER PDF EXPORT ---
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
    
    // Map our low-stock items into rows for the PDF table
    final tableData = itemsToOrder.map((p) {
      int suggestedOrder = (p.reorderLevel * 2) - p.stock;
      if (suggestedOrder < 20) suggestedOrder = 20; 
      
      final estUnitCost = p.price * 0.60; // Estimated 60% wholesale cost
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
            
            // To: Supplier (Placeholder for now)
            pw.Text('TO SUPPLIER:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('General Supplier / Distributor'),
            pw.SizedBox(height: 24),
            
            // The Items Table
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
            
            // Grand Total
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
            
            // Signatures
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

    // This opens the device's native print/save dialog!
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(), 
      name: 'Purchase_Order_${DateFormat('yyyyMMdd').format(now)}.pdf'
    );
  }

  // --- EXCEL EXPORT (Keeps your existing setup) ---
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

// --- PDF EXPORT LOGIC ---
  Future<void> _exportToPDF(List<Sale> sales, List<Product> products) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: 'PHP ');

    if (_selectedTab == 0) {
      // SALES PDF
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
      // INVENTORY PDF
      pdf.addPage(
        pw.MultiPage(
          // 1. FORCE LANDSCAPE
          pageFormat: PdfPageFormat.a4.landscape, 
          // 2. REDUCE PAGE MARGINS
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
                
                // 3. DROP FONT SIZE
                cellStyle: const pw.TextStyle(fontSize: 8), 
                
                // 4. REDUCE CELL PADDING (Removes dead space between words)
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                
                // 5. TIGHTEN COLUMN RATIOS
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.2), // Barcode
                  1: const pw.FlexColumnWidth(0.2), // Name
                  2: const pw.FlexColumnWidth(0.2), // Category
                  3: const pw.FlexColumnWidth(0.2), // Price
                  4: const pw.FlexColumnWidth(0.2), // Stock
                  5: const pw.FlexColumnWidth(0.2), // Reorder
                  6: const pw.FlexColumnWidth(0.2), // Status
                  7: const pw.FlexColumnWidth(0.2), // Expiration
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allSales = provider.getSales();
    final allProducts = provider.getProducts();
    
    final filteredSales = _getFilteredSales(allSales);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
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
                          const Text('Reports & Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Export and analyze store data', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportToPDF(filteredSales, allProducts),
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        label: const Text('PDF', style: TextStyle(color: Colors.black87)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _exportToExcel,
                        icon: const Icon(Icons.table_chart, color: Colors.green),
                        label: const Text('Excel', style: TextStyle(color: Colors.black87)),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 24),

              // --- TAB SELECTORS ---
              Row(
                children: [
                  _buildTabCard(0, 'Sales', 'Revenue, top items, payment breakdown', Icons.trending_up),
                  const SizedBox(width: 16),
                  _buildTabCard(1, 'Inventory', 'Stock levels, value by category', Icons.inventory_2_outlined),
                ],
              ),
              const SizedBox(height: 24),

 // --- CONTENT RENDERER ---
              _selectedTab == 0 
                  ? _buildSalesView(filteredSales) 
                  // --- NEW: Passing allSales here for accurate Dead Stock calculation ---
                  : _buildInventoryView(allProducts, filteredSales, allSales),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB UI COMPONENT ---
  Widget _buildTabCard(int index, String title, String subtitle, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.blue[300]! : Colors.grey[200]!, width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? Colors.blue[700] : Colors.grey[600]),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? Colors.blue[900] : Colors.black87)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

// ==========================================
  // SALES VIEW (SUPERCHARGED)
  // ==========================================
  Widget _buildSalesView(List<Sale> sales) {
    final fmt = NumberFormat.currency(symbol: '₱');
    
    // --- ADVANCED METRICS ---
    final totalRevenue = sales.fold(0.0, (sum, s) => sum + s.finalTotal);
    
    // 1. Discount Leakage
    final totalDiscounts = sales.fold(0.0, (sum, s) => sum + s.discount);
    
    // 2. True Profit (Assuming 70% COGS for this simulation, replace with exact batch cost later)
    final totalCOGS = sales.fold(0.0, (sum, s) => sum + (s.finalTotal * 0.70)); 
    final trueProfit = totalRevenue - totalCOGS;

    // Target Calculation
    int days = 7;
    if (_dateRange == 'Today') days = 1;
    if (_dateRange == 'Last 30 Days') days = 30;
    final targetGoal = _dailyRevenueTarget * days;
    final targetHit = totalRevenue >= targetGoal;
    final progress = (totalRevenue / targetGoal).clamp(0.0, 1.0);
    final remaining = targetGoal - totalRevenue;

    // Payment Mix Calculation
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
                  label: Text(range, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[800])),
                  selected: isSelected,
                  selectedColor: Colors.blue[600],
                  backgroundColor: Colors.white,
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
            _buildKPI('Total Revenue', fmt.format(totalRevenue), Colors.green),
            const SizedBox(width: 16),
            _buildKPI('True Profit (Net)', fmt.format(trueProfit), Colors.purple),
            const SizedBox(width: 16),
            _buildKPI('Discount Leakage', '-${fmt.format(totalDiscounts)}', Colors.red),
            const SizedBox(width: 16),
            _buildKPI('Target Status', targetHit ? 'Goal Hit! 🎉' : 'Behind Pace', targetHit ? Colors.green : Colors.orange),
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
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenue Over Time', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Expanded(child: _buildSalesLineChart(sales)),
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
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Cashier Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildCashierLeaderboard(sales)),
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
                height: 320,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Peak Hours Traffic', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Transactions by hour of day', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildPeakHoursChart(sales)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 3,
              child: Container(
                height: 320,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment mix', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_dateRange, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildPaymentMixChart(paymentMix)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total received', style: TextStyle(color: Colors.grey[600])),
                        Text(fmt.format(totalRevenue), style: const TextStyle(fontWeight: FontWeight.bold)),
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
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales Goal Progress', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_dateRange, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    height: 100, width: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(value: progress, strokeWidth: 10, backgroundColor: Colors.grey[100], color: Colors.blue[600]),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            Text('of goal', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACHIEVED', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(fmt.format(totalRevenue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TARGET', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(fmt.format(targetGoal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.grey)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('REMAINING', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(remaining > 0 ? fmt.format(remaining) : '₱0.00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: remaining > 0 ? Colors.orange[700] : Colors.green)),
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
  // INVENTORY VIEW (SUPERCHARGED & FIXED)
  // ==========================================
  Widget _buildInventoryView(List<Product> products, List<Sale> filteredSales, List<Sale> allSales) {
    final fmt = NumberFormat.currency(symbol: '₱');
    
    // --- ADVANCED METRICS ---
    final totalValue = products.fold(0.0, (sum, p) => sum + (p.price * p.stock));
    
    // 1. Spoilage Loss
    final expiredProducts = products.where((p) => p.status == 'Expired').toList();
    final spoilageValue = expiredProducts.fold(0.0, (sum, p) => sum + (p.price * p.stock));

    // 2. FIXED Dead Stock Radar (Strictly checks for 0 sales in the last 30 days)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final last30DaysSales = allSales.where((s) => DateTime.parse(s.timestamp).isAfter(thirtyDaysAgo)).toList();
    // Using productId instead of name for perfect accuracy
    final soldProductIds = last30DaysSales.expand((s) => s.items.map((i) => i.productId)).toSet();
    
    final deadStock = products.where((p) => p.stock > 0 && !soldProductIds.contains(p.id)).toList();
    deadStock.sort((a, b) => (b.price * b.stock).compareTo(a.price * a.stock)); // Sort by most expensive dead stock

    // 3. Restock Plan (PO Generator)
    final lowStock = products.where((p) => p.stock > 0 && p.stock <= p.reorderLevel).toList();
    final outOfStock = products.where((p) => p.stock == 0).toList();
    final itemsToOrder = [...outOfStock, ...lowStock];
    
    double totalRestockCost = 0.0;
    for (var p in itemsToOrder) {
      int suggestedOrder = (p.reorderLevel * 2) - p.stock;
      if (suggestedOrder < 20) suggestedOrder = 20; 
      totalRestockCost += suggestedOrder * (p.price * 0.60);
    }

    // 4. RESTORED Top Items Calculation (Respects the selected Date Range filter)
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
        // Date Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Today', 'Last 7 Days', 'Last 30 Days', 'Year to Date'].map((range) {
              final isSelected = _dateRange == range;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(range, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[800])),
                  selected: isSelected,
                  selectedColor: Colors.blue[600],
                  backgroundColor: Colors.white,
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
            _buildKPI('Total Stock Value', fmt.format(totalValue), Colors.green),
            const SizedBox(width: 16),
            _buildKPI('Spoilage Loss (Expired)', fmt.format(spoilageValue), Colors.red),
            const SizedBox(width: 16),
            _buildKPI('Dead Stock Items', '${deadStock.length} items', Colors.purple),
            const SizedBox(width: 16),
            _buildKPI('Est. Restock Cost', fmt.format(totalRestockCost), Colors.orange),
          ],
        ),
        const SizedBox(height: 24),

        // --- ROW 1: TOP ITEMS | STOCK PIE | DEAD STOCK ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. RESTORED Top Items
            Expanded(
              flex: 4,
              child: Container(
                height: 360,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('By units sold ($_dateRange)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 16),
                    const Divider(),
                    if (topItems.isEmpty) const Padding(padding: EdgeInsets.all(16.0), child: Text('No items sold in this range.')),
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
                                    Text('${index + 1}', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: progress, minHeight: 6,
                                        backgroundColor: Colors.grey[100], color: Colors.blue[600],
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    ),
                                    const SizedBox(width: 12),
                                    Text(fmt.format(rev), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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

            // 2. Stock Distribution
            Expanded(
              flex: 4,
              child: Container(
                height: 360,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stock Status Distribution', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildDetailedInventoryPieChart(products)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),

            // 3. Dead Stock Radar
            Expanded(
              flex: 4,
              child: Container(
                height: 360,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.radar, color: Colors.purple[600]),
                        const SizedBox(width: 8),
                        const Text('Dead Stock Radar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text('0 sales in the last 30 days', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 16),
                    Expanded(child: _buildDeadStockRadar(deadStock)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // --- ROW 2: CATEGORY BAR & RESTOCK PO ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Value by Category
            Expanded(
              flex: 1,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Value Locked by Category', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Expanded(child: _buildDetailedCategoryBarChart(products)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),

            // 2. Restock Plan
            Expanded(
              flex: 1,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.request_quote, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            const Text('Restock Plan (PO)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => _exportPOToPDF(itemsToOrder), 
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Export PO'),
                        )
                      ],
                    ),
                    Text('${itemsToOrder.length} items require reordering', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 16),
                    Expanded(child: _buildRestockPlan(itemsToOrder)),
                  ],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  // --- UI HELPERS & CHARTS ---

  BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!));

  Widget _buildKPI(String title, String value, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesLineChart(List<Sale> sales) {
    if (sales.isEmpty) return const Center(child: Text('No data for selected range.'));
    
    // Group sales by day
    final grouped = <int, double>{};
    for (var s in sales) {
      final day = DateTime.parse(s.timestamp).day;
      grouped[day] = (grouped[day] ?? 0) + s.finalTotal;
    }
    
    final sortedKeys = grouped.keys.toList()..sort();
    List<FlSpot> spots = sortedKeys.map((day) => FlSpot(day.toDouble(), grouped[day]!)).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5000),
        titlesData: const FlTitlesData(topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(spots: spots, isCurved: true, color: Colors.blue[600], barWidth: 3, belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1))),
        ],
      ),
    );
  }

//   Widget _buildInventoryPieChart(List<Product> products) {
//     if (products.isEmpty) return const SizedBox();
//     final outOfStock = products.where((p) => p.stock == 0).length;
//     final lowStock = products.where((p) => p.stock > 0 && p.stock <= p.reorderLevel).length;
//     final normal = products.length - outOfStock - lowStock;

//     return PieChart(
//       PieChartData(
//         sectionsSpace: 2, centerSpaceRadius: 40,
//         sections: [
//           PieChartSectionData(color: Colors.green, value: normal.toDouble(), title: 'Normal', radius: 25, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
//           PieChartSectionData(color: Colors.orange, value: lowStock.toDouble(), title: 'Low', radius: 25, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
//           PieChartSectionData(color: Colors.red, value: outOfStock.toDouble(), title: 'Out', radius: 25, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
//         ]
//       )
//     );
//   }

//   Widget _buildCategoryBarChart(List<Product> products) {
//     if (products.isEmpty) return const SizedBox();
    
//     final catValue = <String, double>{};
//     for (var p in products) {
//       catValue[p.category] = (catValue[p.category] ?? 0) + (p.stock * p.price);
//     }
    
//     final sortedCats = catValue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
//     final topCats = sortedCats.take(5).toList();

//     return BarChart(
//       BarChartData(
//         gridData: const FlGridData(show: false),
//         titlesData: FlTitlesData(
//           topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           bottomTitles: AxisTitles(
//             sideTitles: SideTitles(
//               showTitles: true,
//               getTitlesWidget: (value, meta) {
//                 if (value.toInt() >= 0 && value.toInt() < topCats.length) {
//                   return Padding(
//                     padding: const EdgeInsets.only(top: 8.0),
//                     child: Text(topCats[value.toInt()].key, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
//                   );
//                 }
//                 return const Text('');
//               }
//             )
//           )
//         ),
//         borderData: FlBorderData(show: false),
//         barGroups: topCats.asMap().entries.map((e) {
//           return BarChartGroupData(
//             x: e.key,
//             barRods: [BarChartRodData(toY: e.value.value, color: Colors.blue[600], width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
//           );
//         }).toList(),
//       )
//     );
//   }
// }

// --- ADD THIS HELPER ---
  Widget _buildPaymentMixChart(Map<String, double> paymentMix) {
    if (paymentMix.isEmpty) return const Center(child: Text('No payments recorded.'));
    
    final colors = [Colors.green, Colors.orange, Colors.blue, Colors.purple];
    final sections = paymentMix.entries.toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2, centerSpaceRadius: 35,
              sections: sections.asMap().entries.map((e) {
                return PieChartSectionData(
                  color: colors[e.key % colors.length],
                  value: e.value.value,
                  title: '', // Keep donut clean
                  radius: 20,
                );
              }).toList()
            )
          )
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections.asMap().entries.map((e) {
            return Row(
              children: [
                Icon(Icons.circle, size: 10, color: colors[e.key % colors.length]),
                const SizedBox(width: 8),
                Text(e.value.key, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ],
            );
          }).toList(),
        )
      ],
    );
  }

  // --- REPLACE THIS HELPER ---
  Widget _buildDetailedInventoryPieChart(List<Product> products) {
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
                PieChartSectionData(color: Colors.green[400], value: normal.toDouble(), title: '${((normal/total)*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(color: Colors.orange[400], value: lowStock.toDouble(), title: '${((lowStock/total)*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                if (outOfStock > 0)
                  PieChartSectionData(color: Colors.red[400], value: outOfStock.toDouble(), title: '${((outOfStock/total)*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              ]
            )
          )
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.circle, size: 10, color: Colors.green[400]), const SizedBox(width: 8), Text('Normal ($normal)', style: const TextStyle(fontSize: 12))]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.circle, size: 10, color: Colors.orange[400]), const SizedBox(width: 8), Text('Low Stock ($lowStock)', style: const TextStyle(fontSize: 12))]),
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.circle, size: 10, color: Colors.red[400]), const SizedBox(width: 8), Text('Critical ($outOfStock)', style: const TextStyle(fontSize: 12))]),
          ],
        )
      ],
    );
  }

  // --- REPLACE THIS HELPER ---
  Widget _buildDetailedCategoryBarChart(List<Product> products) {
    if (products.isEmpty) return const SizedBox();
    
    final catValue = <String, double>{};
    for (var p in products) {
      catValue[p.category] = (catValue[p.category] ?? 0) + (p.stock * p.price);
    }
    
    final sortedCats = catValue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCats = sortedCats.take(6).toList(); 
    
    // FIX 1: Increased from 1.2 to 1.3 (30% headroom) so the tooltips never hit the ceiling
    final maxY = topCats.isEmpty ? 100.0 : topCats.first.value * 1.3; 

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).ceilToDouble()),
        
        // FIX 2: Stylized the Tooltip to be cleaner
        barTouchData: BarTouchData(
          enabled: false, // False because we force them to always show via showingTooltipIndicators
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey[700]!, // Background color of the tooltip
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toStringAsFixed(0), // Clean whole numbers
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              );
            },
          ),
        ),
        
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          
          // FIX 3: Explicitly sizing and formatting the Left Y-Axis
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50, // Added much more breathing room so text doesn't overlap
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                
                // Formats numbers cleanly (e.g., 12500 -> "12.5k")
                String text = value >= 1000 
                    ? '${(value / 1000).toStringAsFixed(1)}k' 
                    : value.toStringAsFixed(0);
                    
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 11), textAlign: TextAlign.right),
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
                    child: Text(topCats[value.toInt()].key, style: TextStyle(fontSize: 11, color: Colors.grey[700]), overflow: TextOverflow.ellipsis),
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
                color: Colors.blue[500], 
                width: 32, 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6))
              )
            ],
            showingTooltipIndicators: [0], // Forces value label to always show on top
          );
        }).toList(),
      )
    );
  }

  // --- NEW: Cashier Leaderboard ---
  Widget _buildCashierLeaderboard(List<Sale> sales) {
    if (sales.isEmpty) return const Center(child: Text('No sales data.'));
    final fmt = NumberFormat.currency(symbol: '₱');
    
    // Aggregate sales by cashier
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
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final entry = sortedCashiers[index];
        final isTop = index == 0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isTop ? Colors.amber[100] : Colors.blue[50],
            child: Text('${index + 1}', style: TextStyle(color: isTop ? Colors.amber[900] : Colors.blue[900], fontWeight: FontWeight.bold)),
          ),
          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${entry.value['txns']} transactions', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          trailing: Text(fmt.format(entry.value['revenue']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        );
      },
    );
  }

  // --- NEW: Peak Hours Heatmap / Bar Chart ---
  Widget _buildPeakHoursChart(List<Sale> sales) {
    if (sales.isEmpty) return const Center(child: Text('No sales data.'));

    // Count transactions per hour (0 to 23)
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
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxCount / 4) == 0 ? 1 : maxCount / 4),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                // Only show labels every 3 hours to avoid crowding
                if (hour % 3 == 0) {
                  final ampm = hour >= 12 ? 'PM' : 'AM';
                  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('$displayHour$ampm', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  );
                }
                return const Text('');
              }
            )
          )
        ),
        barGroups: List.generate(24, (index) {
          final count = hourlyCounts[index];
          // Color changes based on volume (heatmap logic)
          Color barColor = Colors.blue[100]!;
          if (count > maxCount * 0.75) barColor = Colors.red[400]!; // Very Busy
          else if (count > maxCount * 0.4) barColor = Colors.orange[400]!; // Busy
          else if (count > 0) barColor = Colors.blue[400]!; // Normal

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

  // --- NEW: Dead Stock Radar ---
  Widget _buildDeadStockRadar(List<Product> deadStock) {
    if (deadStock.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green[300], size: 48),
            const SizedBox(height: 12),
            Text('No Dead Stock!', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            Text('All inventory is moving perfectly.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }

    final fmt = NumberFormat.currency(symbol: '₱');
    
    return ListView.separated(
      itemCount: deadStock.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final p = deadStock[index];
        final lockedValue = p.stock * p.price;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
          subtitle: Text('In Stock: ${p.stock}  •  Category: ${p.category}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Value Locked', style: TextStyle(fontSize: 10, color: Colors.red)),
              Text(fmt.format(lockedValue), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700])),
            ],
          ),
        );
      },
    );
  }

  // --- NEW: Restock Plan (PO Generator) ---
  Widget _buildRestockPlan(List<Product> itemsToOrder) {
    if (itemsToOrder.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, color: Colors.green[300], size: 48),
            const SizedBox(height: 12),
            Text('Inventory is Healthy', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            Text('No items need to be ordered.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }

    final fmt = NumberFormat.currency(symbol: '₱');
    
    return ListView.separated(
      itemCount: itemsToOrder.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final p = itemsToOrder[index];
        int suggestedOrder = (p.reorderLevel * 2) - p.stock;
        if (suggestedOrder < 20) suggestedOrder = 20; 
        final estCost = suggestedOrder * (p.price * 0.60); // 60% wholesale est

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
          subtitle: Row(
            children: [
              Text('Have: ${p.stock}', style: TextStyle(color: p.stock == 0 ? Colors.red : Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
              Text('  •  Need: $suggestedOrder', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Est. Cost', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text(fmt.format(estCost), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
            ],
          ),
        );
      },
    );
  }
}