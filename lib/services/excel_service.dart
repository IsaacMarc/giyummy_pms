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

    // Filter sales based on the selected timeframe
    final sales = allSales.where((s) {
      final saleDate = DateTime.parse(s.timestamp);
      return saleDate.isAfter(startDate) || saleDate.isAtSameMomentAs(startDate);
    }).toList();

    if (sales.isEmpty) return 'No sales data available for "$timeframe".';

    // Prompt user for save location
    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Analytics Report ($timeframe)',
      fileName: 'POS_Report_${timeframe.replaceAll(' ', '')}_${DateFormat('MM_dd_yyyy').format(DateTime.now())}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputFile == null) return 'Cancelled by user';

    // --- 2. DATA AGGREGATION ---
    final Map<String, double> salesByDate = {};
    final Map<String, double> categorySales = {};
    final Map<String, double> productQty = {};

    double totalRevenue = 0;
    int totalItemsSold = 0;

    for (var sale in sales) {
      totalRevenue += sale.finalTotal;
      String date = DateFormat('MM/dd/yyyy').format(DateTime.parse(sale.timestamp));
      salesByDate[date] = (salesByDate[date] ?? 0) + sale.finalTotal;

      for (var item in sale.items) {
        totalItemsSold += item.quantity;
        productQty[item.productName] = (productQty[item.productName] ?? 0) + item.quantity.toDouble();

        final pIndex = products.indexWhere((p) => p.id == item.productId);
        final category = pIndex >= 0 ? products[pIndex].category : 'Uncategorized';
        categorySales[category] = (categorySales[category] ?? 0) + item.quantity.toDouble();
      }
    }

    // Sort Data
    final sortedDates = salesByDate.entries.toList()
      ..sort((a, b) => DateFormat('MM/dd/yyyy').parse(a.key).compareTo(DateFormat('MM/dd/yyyy').parse(b.key)));
    final sortedProducts = productQty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedProducts.take(5).toList();
    final bottom5 = sortedProducts.reversed.take(5).toList();


    // --- 3. EXCEL WORKBOOK CREATION ---
    final excel.Workbook workbook = excel.Workbook();
    final excel.Worksheet summarySheet = workbook.worksheets[0];
    summarySheet.name = 'Analytics Dashboard';
    summarySheet.showGridlines = false;

    // Header Styling
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

    summarySheet.getRangeByName('A1:L2').merge();
    summarySheet.getRangeByName('A1').setText('EXECUTIVE DASHBOARD: ${timeframe.toUpperCase()}');
    summarySheet.getRangeByName('A1').cellStyle = headerStyle;

    // KPI Summary Metrics
    summarySheet.getRangeByName('A4').setText('Total Revenue:');
    summarySheet.getRangeByName('B4').setNumber(totalRevenue);
    summarySheet.getRangeByName('B4').numberFormat = '\$#,##0.00'; 
    summarySheet.getRangeByName('B4').cellStyle.bold = true;

    summarySheet.getRangeByName('E4').setText('Total Items Sold:');
    summarySheet.getRangeByName('F4').setNumber(totalItemsSold.toDouble());
    summarySheet.getRangeByName('F4').cellStyle.bold = true;

    summarySheet.getRangeByName('I4').setText('Total Transactions:');
    summarySheet.getRangeByName('J4').setNumber(sales.length.toDouble());
    summarySheet.getRangeByName('J4').cellStyle.bold = true;

    summarySheet.autoFitColumn(1); summarySheet.autoFitColumn(5); summarySheet.autoFitColumn(9);
    summarySheet.autoFitColumn(2); summarySheet.autoFitColumn(8); // Give data columns some room

    // -------------------------------------------------------------
    // VISIBLE DATA TABLES & CHARTS (Top Row)
    // -------------------------------------------------------------
    // 1. Trend Table (Starts Row 20)
    summarySheet.getRangeByName('A20').setText('Date');
    summarySheet.getRangeByName('B20').setText('Revenue');
    summarySheet.getRangeByName('A20:B20').cellStyle = tableHeader;

    int r = 21;
    for (var entry in sortedDates) {
      summarySheet.getRangeByIndex(r, 1).setText(entry.key);
      summarySheet.getRangeByIndex(r, 2).setNumber(entry.value);
      summarySheet.getRangeByIndex(r, 2).numberFormat = '\$#,##0.00';
      summarySheet.getRangeByIndex(r, 1, r, 2).cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
      r++;
    }
    int trendEnd = r - 1;

    // 2. Category Table (Starts Row 20)
    summarySheet.getRangeByName('H20').setText('Category');
    summarySheet.getRangeByName('I20').setText('Qty Sold');
    summarySheet.getRangeByName('H20:I20').cellStyle = tableHeader;

    r = 21;
    for (var entry in categorySales.entries) {
      summarySheet.getRangeByIndex(r, 8).setText(entry.key);
      summarySheet.getRangeByIndex(r, 9).setNumber(entry.value);
      summarySheet.getRangeByIndex(r, 8, r, 9).cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
      r++;
    }
    int catEnd = r - 1;

    // Charts 1 & 2
    final ChartCollection charts = ChartCollection(summarySheet);
    
    final Chart trendChart = charts.add();
    trendChart.chartType = ExcelChartType.line;
    trendChart.dataRange = summarySheet.getRangeByName('A20:B$trendEnd');
    trendChart.isSeriesInRows = false;
    trendChart.chartTitle = 'Revenue Trend ($timeframe)';
    trendChart.topRow = 6; trendChart.bottomRow = 18;
    trendChart.leftColumn = 1; trendChart.rightColumn = 6;

    final Chart catChart = charts.add();
    catChart.chartType = ExcelChartType.pie;
    catChart.dataRange = summarySheet.getRangeByName('H20:I$catEnd');
    catChart.isSeriesInRows = false;
    catChart.chartTitle = 'Sales by Category';
    catChart.topRow = 6; catChart.bottomRow = 18;
    catChart.leftColumn = 8; catChart.rightColumn = 13;

    // -------------------------------------------------------------
    // VISIBLE DATA TABLES & CHARTS (Bottom Row)
    // -------------------------------------------------------------
    // Calculate where to start the next row of charts based on how long the tables above are
    int nextSec = (trendEnd > catEnd ? trendEnd : catEnd) + 4;
    int tableStart = nextSec + 14;

    // 3. Top Performers Table
    summarySheet.getRangeByIndex(tableStart, 1).setText('Product');
    summarySheet.getRangeByIndex(tableStart, 2).setText('Qty Sold');
    summarySheet.getRangeByIndex(tableStart, 1, tableStart, 2).cellStyle = tableHeader;

    r = tableStart + 1;
    for (var entry in top5) {
      summarySheet.getRangeByIndex(r, 1).setText(entry.key);
      summarySheet.getRangeByIndex(r, 2).setNumber(entry.value);
      summarySheet.getRangeByIndex(r, 1, r, 2).cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
      r++;
    }
    int topEnd = r - 1;

    // 4. Low Performers Table
    summarySheet.getRangeByIndex(tableStart, 8).setText('Product');
    summarySheet.getRangeByIndex(tableStart, 9).setText('Qty Sold');
    summarySheet.getRangeByIndex(tableStart, 8, tableStart, 9).cellStyle = tableHeader;

    r = tableStart + 1;
    for (var entry in bottom5) {
      summarySheet.getRangeByIndex(r, 8).setText(entry.key);
      summarySheet.getRangeByIndex(r, 9).setNumber(entry.value);
      summarySheet.getRangeByIndex(r, 8, r, 9).cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
      r++;
    }
    int botEnd = r - 1;

    // Charts 3 & 4
    if (top5.isNotEmpty) {
      final Chart topChart = charts.add();
      topChart.chartType = ExcelChartType.column;
      topChart.dataRange = summarySheet.getRangeByIndex(tableStart, 1, topEnd, 2);
      topChart.isSeriesInRows = false;
      topChart.chartTitle = 'Top 5 Best Sellers';
      topChart.topRow = nextSec; topChart.bottomRow = nextSec + 12;
      topChart.leftColumn = 1; topChart.rightColumn = 6;
    }

    if (bottom5.isNotEmpty) {
      final Chart lowChart = charts.add();
      lowChart.chartType = ExcelChartType.bar;
      lowChart.dataRange = summarySheet.getRangeByIndex(tableStart, 8, botEnd, 9);
      lowChart.isSeriesInRows = false;
      lowChart.chartTitle = 'Bottom 5 Performers';
      lowChart.topRow = nextSec; lowChart.bottomRow = nextSec + 12;
      lowChart.leftColumn = 8; lowChart.rightColumn = 13;
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