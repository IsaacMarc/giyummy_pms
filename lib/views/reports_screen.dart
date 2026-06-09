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