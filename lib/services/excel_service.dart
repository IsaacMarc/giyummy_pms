import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
import 'package:syncfusion_officechart/officechart.dart';
import '../models/models.dart';

class ExcelService {
  static Future<String?> exportMasterReport(List<Sale> allSales, List<Product> products, String timeframe) async {
    // --- 1. TIMEFRAME FILTERING ---
    DateTime now = DateTime.now();
    DateTime startDate;
    
    if (timeframe == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (timeframe == '7 Days') {
      startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    } else if (timeframe == '30 Days') {
      startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    } else {
      startDate = DateTime(2000); // 'All Time'
    }

    final sales = allSales.where((s) {
      final saleDate = DateTime.parse(s.timestamp);
      return saleDate.isAfter(startDate) || saleDate.isAtSameMomentAs(startDate);
    }).toList();

    if (sales.isEmpty) return 'No sales data available for "$timeframe".';

    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Analytics Report ($timeframe)',
      fileName: 'POS_Report_${timeframe.replaceAll(' ', '')}_${DateFormat('MM_dd_yyyy').format(DateTime.now())}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputFile == null) return 'Cancelled by user';

    // --- 2. EXPANDED DATA AGGREGATION ---
    final Map<String, double> salesByDate = {};
    final Map<String, double> categorySales = {};
    final Map<String, double> productQty = {};
    final Map<String, int> paymentMethods = {}; // NEW
    final Map<String, double> cashierSales = {}; // NEW

    double totalRevenue = 0;
    int totalItemsSold = 0;

    for (var sale in sales) {
      totalRevenue += sale.finalTotal;
      
      String date = DateFormat('MM/dd/yyyy').format(DateTime.parse(sale.timestamp));
      salesByDate[date] = (salesByDate[date] ?? 0) + sale.finalTotal;
      
      // New Aggregations
      paymentMethods[sale.paymentMethod] = (paymentMethods[sale.paymentMethod] ?? 0) + 1;
      cashierSales[sale.cashierName] = (cashierSales[sale.cashierName] ?? 0) + sale.finalTotal;

      for (var item in sale.items) {
        totalItemsSold += item.quantity;
        productQty[item.productName] = (productQty[item.productName] ?? 0) + item.quantity.toDouble();

        final pIndex = products.indexWhere((p) => p.id == item.productId);
        final category = pIndex >= 0 ? products[pIndex].category : 'Uncategorized';
        categorySales[category] = (categorySales[category] ?? 0) + item.quantity.toDouble();
      }
    }

    // Sorting
    final sortedDates = salesByDate.entries.toList()..sort((a, b) => DateFormat('MM/dd/yyyy').parse(a.key).compareTo(DateFormat('MM/dd/yyyy').parse(b.key)));
    final sortedProducts = productQty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sortedCashiers = cashierSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedProducts.take(5).toList();
    final bottom5 = sortedProducts.reversed.take(5).toList();


    // --- 3. EXCEL WORKBOOK CREATION ---
    final excel.Workbook workbook = excel.Workbook();
    final excel.Worksheet summarySheet = workbook.worksheets[0];
    summarySheet.name = 'Analytics Dashboard';
    summarySheet.showGridlines = false;

    // STYLES
    final excel.Style headerStyle = workbook.styles.add('HeaderStyle');
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.backColor = '#1565C0';
    headerStyle.bold = true;
    headerStyle.hAlign = excel.HAlignType.center;
    headerStyle.vAlign = excel.VAlignType.center;

    final excel.Style tableHeader = workbook.styles.add('TableHeader');
    tableHeader.backColor = '#E0E0E0';
    tableHeader.bold = true;
    tableHeader.borders.all.lineStyle = excel.LineStyle.thin;
    tableHeader.wrapText = true; 

    final excel.Style dataStyle = workbook.styles.add('DataStyle');
    dataStyle.wrapText = true;
    dataStyle.vAlign = excel.VAlignType.center;

    // --- NEW: Default Excel Chart Color Palette ---
    final List<String> chartPalette = [
      '#4472C4', // 1. Blue
      '#ED7D31', // 2. Orange
      '#A5A5A5', // 3. Gray
      '#FFC000', // 4. Yellow
      '#5B9BD5', // 5. Light Blue
      '#70AD47', // 6. Green
      '#264478', // 7. Dark Blue
      '#9E480E', // 8. Dark Orange
      '#636363', // 9. Dark Gray
      '#997300', // 10. Dark Yellow
    ];

    // --- KPI HEADER ---
    summarySheet.getRangeByName('A1:P2').merge();
    summarySheet.getRangeByName('A1').setText('EXECUTIVE DASHBOARD: ${timeframe.toUpperCase()}');
    summarySheet.getRangeByName('A1').cellStyle = headerStyle;

    summarySheet.getRangeByName('A4').setText('Total Revenue:');
    summarySheet.getRangeByName('B4').setNumber(totalRevenue);
    summarySheet.getRangeByName('B4').numberFormat = '\$#,##0.00'; 
    summarySheet.getRangeByName('B4').cellStyle.bold = true;

    summarySheet.getRangeByName('D4').setText('Total Items Sold:');
    summarySheet.getRangeByName('E4').setNumber(totalItemsSold.toDouble());
    summarySheet.getRangeByName('E4').cellStyle.bold = true;

    summarySheet.getRangeByName('G4').setText('Total Transactions:');
    summarySheet.getRangeByName('H4').setNumber(sales.length.toDouble());
    summarySheet.getRangeByName('H4').cellStyle.bold = true;

    double avgOrder = sales.isNotEmpty ? totalRevenue / sales.length : 0;
    summarySheet.getRangeByName('J4').setText('Avg Order Value:');
    summarySheet.getRangeByName('K4').setNumber(avgOrder);
    summarySheet.getRangeByName('K4').numberFormat = '\$#,##0.00'; 
    summarySheet.getRangeByName('K4').cellStyle.bold = true;

    // -------------------------------------------------------------
    // RAW DATA TABLES (Placed neatly at the bottom starting row 38)
    // -------------------------------------------------------------
    int tableRow = 38;

// Helper function to draw tables
    int drawTable(String header1, String header2, int startCol, List<MapEntry<String, dynamic>> data, bool isCurrency, bool applyPalette) {
      summarySheet.getRangeByIndex(tableRow, startCol).setText(header1);
      summarySheet.getRangeByIndex(tableRow, startCol + 1).setText(header2);
      summarySheet.getRangeByIndex(tableRow, startCol, tableRow, startCol + 1).cellStyle = tableHeader;

      int r = tableRow + 1;
      for (int i = 0; i < data.length; i++) {
        var entry = data[i];
        
        summarySheet.getRangeByIndex(r, startCol).setText(entry.key);
        summarySheet.getRangeByIndex(r, startCol + 1).setNumber(entry.value.toDouble());
        if (isCurrency) summarySheet.getRangeByIndex(r, startCol + 1).numberFormat = '\$#,##0.00';
        
        summarySheet.getRangeByIndex(r, startCol, r, startCol + 1).cellStyle = dataStyle;
        summarySheet.getRangeByIndex(r, startCol, r, startCol + 1).cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
        
        // --- NEW: Apply Matching Colors to the Raw Data Cells ---
        if (applyPalette) {
          final excel.Style colorStyle = workbook.styles.add('ColorStyle_${startCol}_$i');
          colorStyle.backColor = chartPalette[i % chartPalette.length]; // Match the chart!
          colorStyle.fontColor = '#FFFFFF'; // White text for readability
          colorStyle.bold = true;
          colorStyle.wrapText = true;
          colorStyle.vAlign = excel.VAlignType.center;
          colorStyle.borders.all.lineStyle = excel.LineStyle.thin;
          
          // Apply this colored style only to the Name column (like a legend)
          summarySheet.getRangeByIndex(r, startCol).cellStyle = colorStyle;
        }
        
        r++;
      }
      
      summarySheet.setColumnWidthInPixels(startCol, 120);
      summarySheet.setColumnWidthInPixels(startCol + 1, 90);
      return r - 1; 
    }


    // -------------------------------------------------------------
    // INVISIBLE MULTI-SERIES MATRICES (The Trick for Multi-Colored Bars)
    // -------------------------------------------------------------
    // Top 5 Matrix
    summarySheet.getRangeByName('A100').setText('');
    summarySheet.getRangeByName('A101').setText('Units');
    for (int i = 0; i < top5.length; i++) {
      summarySheet.getRangeByIndex(100, i + 2).setText(top5[i].key);
      summarySheet.getRangeByIndex(101, i + 2).setNumber(top5[i].value.toDouble());
    }

    // Bottom 5 Matrix
    summarySheet.getRangeByName('A103').setText('');
    summarySheet.getRangeByName('A104').setText('Units');
    for (int i = 0; i < bottom5.length; i++) {
      summarySheet.getRangeByIndex(103, i + 2).setText(bottom5[i].key);
      summarySheet.getRangeByIndex(104, i + 2).setNumber(bottom5[i].value.toDouble());
    }

    // Cashier Matrix
    summarySheet.getRangeByName('A106').setText('');
    summarySheet.getRangeByName('A107').setText('Revenue');
    for (int i = 0; i < sortedCashiers.length; i++) {
      summarySheet.getRangeByIndex(106, i + 2).setText(sortedCashiers[i].key);
      summarySheet.getRangeByIndex(107, i + 2).setNumber(sortedCashiers[i].value.toDouble());
    }

    int trendEnd = drawTable('Date', 'Revenue', 1, sortedDates, true, false); 
    int catEnd = drawTable('Category', 'Qty Sold', 4, categorySales.entries.toList(), false, true); 
    int topEnd = drawTable('Top Product', 'Qty Sold', 7, top5, false, true); 
    int botEnd = drawTable('Low Product', 'Qty Sold', 10, bottom5, false, true); 
    int payEnd = drawTable('Payment Method', 'Count', 13, paymentMethods.entries.toList(), false, true); 
    int cashEnd = drawTable('Cashier', 'Revenue', 16, sortedCashiers, true, false);


    // -------------------------------------------------------------
    // VISUAL CHARTS (Using Auto-Naming Data Ranges to prevent crashes)
    // -------------------------------------------------------------
    final ChartCollection charts = ChartCollection(summarySheet);

    // 1. Trend Chart
    final Chart trendChart = charts.add();
    trendChart.chartType = ExcelChartType.line;
    // By including tableRow (Row 38) in the range, Excel names the series "Revenue" automatically!
    trendChart.dataRange = summarySheet.getRangeByIndex(tableRow, 1, trendEnd, 2);
    trendChart.isSeriesInRows = false;
    trendChart.chartTitle = 'Revenue Trend';
    trendChart.series[0].dataLabels.isValue = true; 
    trendChart.topRow = 6; trendChart.bottomRow = 20;
    trendChart.leftColumn = 1; trendChart.rightColumn = 6;

    // 2. Category Pie
    final Chart catChart = charts.add();
    catChart.chartType = ExcelChartType.pie;
    catChart.dataRange = summarySheet.getRangeByIndex(tableRow, 4, catEnd, 5);
    catChart.isSeriesInRows = false;
    catChart.chartTitle = 'Sales by Category';
    catChart.series[0].dataLabels.isCategoryName = true; 
    catChart.series[0].dataLabels.isValue = true;
    catChart.topRow = 6; catChart.bottomRow = 20;
    catChart.leftColumn = 7; catChart.rightColumn = 11;

    // 3. Payment Doughnut
    final Chart payChart = charts.add();
    payChart.chartType = ExcelChartType.doughnut;
    payChart.dataRange = summarySheet.getRangeByIndex(tableRow, 13, payEnd, 14);
    payChart.isSeriesInRows = false;
    payChart.chartTitle = 'Payment Methods';
    payChart.series[0].dataLabels.isCategoryName = true; 
    payChart.series[0].dataLabels.isValue = true;
    payChart.topRow = 6; payChart.bottomRow = 20;
    payChart.leftColumn = 12; payChart.rightColumn = 16;

    // 4. Top 5 Products (Multi-Colored)
    if (top5.isNotEmpty) {
      final Chart topChart = charts.add();
      topChart.chartType = ExcelChartType.column;
      // Row 100 contains the explicit product names, so Excel names the legend perfectly
      topChart.dataRange = summarySheet.getRangeByIndex(100, 1, 101, top5.length + 1); 
      topChart.isSeriesInRows = false;
      topChart.chartTitle = 'Top 5 Best Sellers';
      
      // Because we used dataRange, the series are initialized safely!
      for (int i = 0; i < top5.length; i++) {
        topChart.series[i].dataLabels.isValue = true;
      }
      
      topChart.topRow = 22; topChart.bottomRow = 36;
      topChart.leftColumn = 1; topChart.rightColumn = 6;
    }

    // 5. Bottom 5 Products (Multi-Colored)
    if (bottom5.isNotEmpty) {
      final Chart lowChart = charts.add();
      lowChart.chartType = ExcelChartType.bar;
      lowChart.dataRange = summarySheet.getRangeByIndex(103, 1, 104, bottom5.length + 1); 
      lowChart.isSeriesInRows = false;
      lowChart.chartTitle = 'Bottom 5 Performers';
      
      for (int i = 0; i < bottom5.length; i++) {
        lowChart.series[i].dataLabels.isValue = true;
      }
      
      lowChart.topRow = 22; lowChart.bottomRow = 36;
      lowChart.leftColumn = 7; lowChart.rightColumn = 11;
    }

    // 6. Cashier Performance (Multi-Colored)
    if (sortedCashiers.isNotEmpty) {
      final Chart cashChart = charts.add();
      cashChart.chartType = ExcelChartType.column;
      cashChart.dataRange = summarySheet.getRangeByIndex(106, 1, 107, sortedCashiers.length + 1); 
      cashChart.isSeriesInRows = false;
      cashChart.chartTitle = 'Cashier Revenue Performance';
      
      for (int i = 0; i < sortedCashiers.length; i++) {
        cashChart.series[i].dataLabels.isValue = true;
      }
      
      cashChart.topRow = 22; cashChart.bottomRow = 36;
      cashChart.leftColumn = 12; cashChart.rightColumn = 16;
    }

    summarySheet.charts = charts;
    // =========================================================================
    // SHEET 2: ALL TRANSACTIONS (Master Log)
    // =========================================================================
    final excel.Worksheet dataSheet = workbook.worksheets.addWithName('Transaction Log');
    
    final headers = ['Transaction ID', 'Date', 'Cashier', 'Items Sold', 'Payment Method', 'Total'];
    for (int i = 0; i < headers.length; i++) {
      final cell = dataSheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = tableHeader;
      dataSheet.autoFitColumn(i + 1);
    }

    int dataRow = 2;
    for (var sale in sales) {
      dataSheet.getRangeByIndex(dataRow, 1).setText(sale.id.substring(0, 8)); 
      dataSheet.getRangeByIndex(dataRow, 2).setText(DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.parse(sale.timestamp)));
      dataSheet.getRangeByIndex(dataRow, 3).setText(sale.cashierName);
      dataSheet.getRangeByIndex(dataRow, 4).setNumber(sale.items.fold(0, (sum, item) => sum + item.quantity).toDouble());
      dataSheet.getRangeByIndex(dataRow, 5).setText(sale.paymentMethod);
      
      final totalCell = dataSheet.getRangeByIndex(dataRow, 6);
      totalCell.setNumber(sale.finalTotal);
      totalCell.numberFormat = '\$#,##0.00'; 
      
      // APPLY WRAPPING TO DATA ROWS
      dataSheet.getRangeByIndex(dataRow, 1, dataRow, 6).cellStyle = dataStyle;
      dataRow++;
    }

    // --- 4. SAVE WORKBOOK ---
    final List<int> bytes = workbook.saveSync(); 
    workbook.dispose();

    try {
      File(outputFile).writeAsBytesSync(bytes, flush: true);
      return null;
    } catch (e) {
      return 'Failed to save file: $e';
    }
  }
}