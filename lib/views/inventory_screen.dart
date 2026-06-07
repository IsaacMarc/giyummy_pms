import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../providers/app_provider.dart';
import '../models/models.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _categoryFilter = 'All';
  static const _uuid = Uuid();

  int _currentPage = 0;
  static const int _itemsPerPage = 10; 
  
  int? _sortColumnIndex;
  bool _sortAscending = true;
  
  bool _isGridView = false;
  int _selectedTab = 0; // NEW: 0 = Active, 1 = Archived

  static const List<String> _koreanCategories = [
    'Ramen & Noodles', 'Kimchi & Banchan', 'Sauces & Condiments', 'Snacks & Sweets',
    'Beverages & Tea', 'Rice & Grains', 'Produce', 'Meat & Seafood', 'Frozen Foods',
    'Refrigerated & Dairy', 'Seaweed & Sushi', 'Canned Goods', 'Household', 'Health & Beauty', 'Other'
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _getAverageCost(String productId, AppProvider provider) {
    final batches = provider.getBatchesForProduct(productId);
    if (batches.isEmpty) return 0.0;
    double totalValue = batches.fold(0.0, (sum, b) => sum + (b.cost * b.quantity));
    int totalQty = batches.fold(0, (sum, b) => sum + b.quantity);
    return totalQty == 0 ? 0.0 : totalValue / totalQty;
  }

  DateTime? _getNextExpiration(String productId, AppProvider provider) {
    final batches = provider.getBatchesForProduct(productId); 
    final activeBatches = batches.where((b) => b.quantity > 0).toList();
    if (activeBatches.isEmpty) return null;
    activeBatches.sort((a, b) => DateTime.parse(a.expirationDate).compareTo(DateTime.parse(b.expirationDate)));
    return DateTime.parse(activeBatches.first.expirationDate);
  }

  List<Product> _filtered(List<Product> all, AppProvider provider) {
    var list = List<Product>.from(all); 
    final q = _searchCtrl.text.toLowerCase();
    
    if (q.isNotEmpty) {
      list = list.where((p) => 
        p.name.toLowerCase().contains(q) || 
        p.barcode.toLowerCase().contains(q)
      ).toList();
    }
    if (_categoryFilter != 'All') {
      list = list.where((p) => p.category == _categoryFilter).toList();
    }

    if (_sortColumnIndex != null) {
      list.sort((a, b) {
        int cmp = 0;
          switch (_sortColumnIndex) {
            case 0: cmp = a.barcode.compareTo(b.barcode); break;
            case 1: cmp = a.name.compareTo(b.name); break;
            case 2: cmp = a.category.compareTo(b.category); break;
            case 4: cmp = a.price.compareTo(b.price); break;
            case 5: cmp = a.stock.compareTo(b.stock); break;
            case 6: cmp = a.reorderLevel.compareTo(b.reorderLevel); break; 
            case 7:
              final expA = _getNextExpiration(a.id, provider);
              final expB = _getNextExpiration(b.id, provider);
              
              if (expA == null && expB == null) {
                cmp = 0;
              } else if (expA == null) cmp = 1; 
              else if (expB == null) cmp = -1;
              else cmp = expA.compareTo(expB);
              break;
            case 8: 
              final now = DateTime.now();
              // Helper function to calculate the visual status for sorting
              String getDynamicStatus(Product p) {
                if (p.status == 'Archived') return 'Archived';
                if (p.stock <= 0) return 'Out of Stock';
                final exp = _getNextExpiration(p.id, provider);
                if (exp != null && exp.difference(now).inDays < 0) return 'Expired';
                if (p.stock <= p.reorderLevel) return 'Low Stock';
                return 'In Stock';
              }
              
              // Sort alphabetically by the computed visual status
              cmp = getDynamicStatus(a).compareTo(getDynamicStatus(b)); 
              break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }
    return list;
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _currentPage = 0; 
    });
  }

  List<String> _categories(List<Product> products) {
    final dynamicCats = products.map((p) => p.category).toSet();
    return {'All', ...dynamicCats, ..._koreanCategories}.toList();
  }

  Widget _buildKPICard(String title, String value, String subtitle, Color mainColor, Color bgColor, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mainColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                Icon(icon, color: mainColor.withOpacity(0.5), size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: mainColor == Colors.black ? Colors.black87 : mainColor)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400]! : Colors.grey[600]!, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --- NEW: Tab Builder for Active vs Archived ---
  Widget _buildTabCard(int index, String title, String subtitle, IconData icon, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedTab = index;
          _currentPage = 0; // Reset pagination on tab switch
        }),
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
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    
    final provider = context.watch<AppProvider>();
    final currentUser = provider.currentUser;
    final isEmployee = currentUser?.role == 'Employee'; 
    final isAdmin = currentUser?.role == 'Admin'; 

    final allProducts = provider.getProducts();
    
    // Split the lists
    final activeProducts = allProducts.where((p) => p.status != 'Archived').toList();
    final archivedProducts = allProducts.where((p) => p.status == 'Archived').toList();
    
    // Select the list based on the active tab
    final displayProducts = _selectedTab == 0 ? activeProducts : archivedProducts;
    final filtered = _filtered(displayProducts, provider);
    
    final categories = _categories(allProducts); // Keep category filter universal
    final fmt = NumberFormat.currency(symbol: '₱');

    // KPI Calculations MUST be based purely on active products
    final totalValue = activeProducts.fold(0.0, (sum, p) {
      final avgCost = _getAverageCost(p.id, provider);
      final costToUse = avgCost > 0 ? avgCost : (p.price * 0.6); 
      return sum + (costToUse * p.stock);
    });
    final lowStockCount = activeProducts.where((p) => p.stock <= p.reorderLevel && p.stock > 0).length;
    
    final now = DateTime.now();
    final expiringSoonCount = activeProducts.where((p) {
      final nextExp = _getNextExpiration(p.id, provider);
      if (nextExp == null) return false;
      return nextExp.difference(now).inDays <= 30;
    }).length;

    final currentItemsPerPage = _isGridView ? 16 : _itemsPerPage;
    final totalPages = (filtered.length / currentItemsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1; 
    
    final paginatedProducts = filtered.isNotEmpty 
        ? filtered.skip(_currentPage * currentItemsPerPage).take(currentItemsPerPage).toList()
        : <Product>[];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inventory', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                      const SizedBox(height: 4),
                      Text('${activeProducts.length} active items across ${categories.length - 1} categories', style: TextStyle(fontSize: 15, color: subTextColor)),
                    ],
                  ),
                  if (!isEmployee)
                    ElevatedButton.icon(
                      onPressed: () => _showProductDialog(context, null, false, isAdmin),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add new item'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, elevation: 0),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // --- TAB CONTROLS ---
              Row(
                children: [
                  _buildTabCard(0, 'Active Inventory', 'Manage current stock and incoming batches', Icons.inventory_2_outlined, isDark),
                  const SizedBox(width: 16),
                  _buildTabCard(1, 'Archived Products', 'View or restore discontinued items', Icons.archive_outlined, isDark),
                ],
              ),
              const SizedBox(height: 32),

              // KPI ROW (Only visible on Active Tab)
              if (_selectedTab == 0) ...[
                Row(
                  children: [
                    _buildKPICard('TOTAL STOCKS', '${activeProducts.length}', 'across all categories', isDark ? Colors.white : Colors.black, isDark ? Colors.grey[900]! : Colors.white, Icons.layers),
                    const SizedBox(width: 16),
                    _buildKPICard('EST. STOCK VALUE', fmt.format(totalValue), 'based on batch cost', Colors.green[700]!, isDark ? Colors.green[900]!.withOpacity(0.3) : const Color(0xFFF0FDF4), Icons.monetization_on),
                    const SizedBox(width: 16),
                    _buildKPICard('LOW-STOCK ITEMS', '$lowStockCount', 'below reorder point', Colors.orange[700]!, isDark ? Colors.orange[900]!.withOpacity(0.3) : Colors.orange[50]!, Icons.warning_amber_rounded),
                    const SizedBox(width: 16),
                    _buildKPICard('EXPIRING SOON', '$expiringSoonCount', 'within next 30 days', Colors.red[700]!, isDark ? Colors.red[900]!.withOpacity(0.3) : const Color(0xFFFEF2F2), Icons.event_busy),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _searchCtrl,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: 'Search by Barcode or name',
                                hintStyle: TextStyle(color: subTextColor),
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                isDense: true,
                                filled: true,
                                fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
                              ),
                              onChanged: (_) => setState(() => _currentPage = 0),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _categoryFilter,
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Filter by Category',
                                labelStyle: TextStyle(color: subTextColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                isDense: true,
                              ),
                              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() { _categoryFilter = v!; _currentPage = 0; }),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.list, color: !_isGridView ? Colors.blue : (isDark ? Colors.grey[600] : Colors.grey[400])),
                                  onPressed: () => setState(() { _isGridView = false; _currentPage = 0; }),
                                  tooltip: 'List View',
                                ),
                                Container(width: 1, height: 24, color: borderColor),
                                IconButton(
                                  icon: Icon(Icons.grid_view, color: _isGridView ? Colors.blue : (isDark ? Colors.grey[600] : Colors.grey[400])),
                                  onPressed: () => setState(() { _isGridView = true; _currentPage = 0; }),
                                  tooltip: 'Grid View',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    _isGridView 
                      ? _buildGridView(paginatedProducts, provider, isDark, textColor, subTextColor, borderColor, fmt, now, isEmployee, isAdmin)
                      : _buildTableView(paginatedProducts, provider, isDark, textColor, subTextColor, borderColor, fmt, now, isEmployee, isAdmin),

                    const Divider(height: 1),
                    
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${filtered.isEmpty ? 0 : (_currentPage * currentItemsPerPage) + 1} - ${min((_currentPage + 1) * currentItemsPerPage, filtered.length)} of ${filtered.length} products', style: TextStyle(color: subTextColor, fontSize: 13)),
                          Row(
                            children: [
                              OutlinedButton(onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null, child: const Text('Previous')),
                              const SizedBox(width: 8),
                              OutlinedButton(onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null, child: const Text('Next')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW RENDERERS
  // =========================================================================

  Widget _buildTableView(List<Product> paginatedProducts, AppProvider provider, bool isDark, Color textColor, Color subTextColor, Color borderColor, NumberFormat fmt, DateTime now, bool isEmployee, bool isAdmin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              headingRowColor: WidgetStateProperty.all(isDark ? Colors.grey[900] : Colors.grey[50]),
              dataRowMinHeight: 70,
              dataRowMaxHeight: 70,
              horizontalMargin: 24,
              columnSpacing: 20,
              columns: [
                DataColumn(label: Text('BARCODE', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                DataColumn(label: Text('ITEM', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                DataColumn(label: Text('CATEGORY', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                DataColumn(label: Text('COST', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('PRICE (MARKUP)', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort, numeric: true),
                DataColumn(label: Text('STOCK', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort, numeric: true),
                DataColumn(label: Text('REORDER', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort, numeric: true),
                DataColumn(label: Text('NEXT EXP.', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                DataColumn(label: Text('STATUS', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                DataColumn(label: Text('ACTIONS', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: paginatedProducts.map((p) {
                
                final avgCost = _getAverageCost(p.id, provider);
                final costToDisplay = avgCost > 0 ? avgCost : (p.price * 0.6); 
                final markupPct = costToDisplay > 0 ? ((p.price - costToDisplay) / costToDisplay) * 100 : 0.0;
                
                final nextExp = _getNextExpiration(p.id, provider);
                final expString = nextExp != null ? DateFormat('MMM d, yyyy').format(nextExp) : 'No Batch Data';                                
                final isExpiringSoon = nextExp != null && nextExp.difference(now).inDays <= 30;

                final double stockProgress = p.reorderLevel > 0 ? (p.stock / (p.reorderLevel * 3)).clamp(0.0, 1.0) : 1.0;
                
                String status = p.status;
                if (status != 'Archived') {
                  if (p.stock <= 0) {
                    status = 'Out of Stock';
                  } else if (nextExp != null && nextExp.difference(now).inDays < 0) {
                    status = 'Expired';
                  } else if (p.stock <= p.reorderLevel) {
                    status = 'Low Stock';
                  } else {
                    status = 'In Stock';
                  }
                }

                final statusColor = status == 'Out of Stock' || status == 'Expired' ? Colors.red  
                                  : status == 'Low Stock' ? Colors.orange 
                                  : status == 'Archived' ? Colors.grey
                                  : Colors.green;

                return DataRow(cells: [
                  DataCell(Text(p.barcode.isEmpty ? 'N/A' : p.barcode, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor))),
                  DataCell(
                    Row(
                      children: [
                        p.imagePath != null && File(p.imagePath!).existsSync()
                            ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(p.imagePath!), width: 40, height: 40, fit: BoxFit.cover))
                            : Container(width: 40, height: 40, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(4)), child: Icon(Icons.inventory, size: 20, color: Colors.grey[400])),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                            if (p.description.isNotEmpty) SizedBox(width: 120, child: Text(p.description, style: TextStyle(color: Colors.grey[500], fontSize: 11), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    )
                  ),
                  DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(4)), child: Text(p.category, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[800])))),
                  DataCell(Text(fmt.format(costToDisplay), style: TextStyle(color: subTextColor))),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmt.format(p.price), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        Text('+${markupPct.toStringAsFixed(1)}%', style: TextStyle(color: isDark ? Colors.green[400] : Colors.green[700], fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ),
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p.stock}', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: stockProgress, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], color: statusColor, minHeight: 4, borderRadius: BorderRadius.circular(2)),
                        ],
                      ),
                    ),
                  ),
                  DataCell(Text('${p.reorderLevel}', style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600))),
                  DataCell(Text(
                    expString, 
                    style: TextStyle(
                      color: isExpiringSoon ? (isDark ? Colors.red[400] : Colors.red[700]) : textColor, 
                      fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal
                    )
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: statusColor),
                        const SizedBox(width: 6),
                        Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isEmployee) ...[
                        if (p.status == 'Archived') ...[
                          IconButton(icon: Icon(Icons.unarchive_outlined, color: isDark ? Colors.green[400] : Colors.green, size: 18), tooltip: 'Restore Product', onPressed: () => _restoreProduct(context, p)),
                          IconButton(icon: Icon(Icons.delete_outline_rounded, color: isDark ? Colors.red[400] : Colors.red, size: 18), tooltip: 'Permanently Delete', onPressed: () => _deleteProduct(context, p)),
                        ] else ...[
                          OutlinedButton(
                            onPressed: () => _showBatchesDialog(context, p),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30), side: BorderSide(color: borderColor)),
                            child: Text('Batches', style: TextStyle(fontSize: 12, color: textColor)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(icon: Icon(Icons.edit_outlined, color: isDark ? Colors.blue[400] : Colors.blue, size: 18), tooltip: 'Edit', onPressed: () => _showProductDialog(context, p, isEmployee, isAdmin)),
                          IconButton(icon: Icon(Icons.archive_outlined, color: isDark ? Colors.orange[400] : Colors.orange, size: 18), tooltip: 'Archive Product', onPressed: () => _archiveProduct(context, p)),
                        ]
                      ]
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      }
    );
  }

  Widget _buildGridView(List<Product> paginatedProducts, AppProvider provider, bool isDark, Color textColor, Color subTextColor, Color borderColor, NumberFormat fmt, DateTime now, bool isEmployee, bool isAdmin) {
    if (paginatedProducts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text('No products match your filters.', style: TextStyle(color: subTextColor, fontSize: 16))),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.75, // Adjusts height vs width of cards
      ),
      itemCount: paginatedProducts.length,
      itemBuilder: (context, i) {
        final p = paginatedProducts[i];
        
        final nextExp = _getNextExpiration(p.id, provider);
        String status = p.status;
        if (status != 'Archived') {
          if (p.stock <= 0) {
            status = 'Out of Stock';
          } else if (nextExp != null && nextExp.difference(now).inDays < 0) {
            status = 'Expired';
          } else if (p.stock <= p.reorderLevel) {
            status = 'Low Stock';
          } else {
            status = 'In Stock';
          }
        }
        
        final statusColor = status == 'Out of Stock' || status == 'Expired' ? Colors.red 
                          : status == 'Low Stock' ? Colors.orange 
                          : status == 'Archived' ? Colors.grey
                          : Colors.green;
        final double stockProgress = p.reorderLevel > 0 ? (p.stock / (p.reorderLevel * 3)).clamp(0.0, 1.0) : 1.0;

        return Card(
          color: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Header
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    p.imagePath != null && File(p.imagePath!).existsSync()
                        ? Image.file(File(p.imagePath!), fit: BoxFit.cover)
                        : Container(color: isDark ? Colors.grey[800] : Colors.grey[100], child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400])),
                    // Status Badge overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: isDark ? Colors.black87 : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.5))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: statusColor),
                            const SizedBox(width: 4),
                            Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
              // Body Data
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(p.category, style: TextStyle(color: subTextColor, fontSize: 12)),
                      const Spacer(),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fmt.format(p.price), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.blue[400] : Colors.blue[700])),
                          Text('${p.stock} in stock', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: stockProgress, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], color: statusColor, minHeight: 4, borderRadius: BorderRadius.circular(2)),
                      const Spacer(),
                      
                      // Actions
                      Row(
                        children: [
                          if (!isEmployee) ...[
                            if (p.status == 'Archived') ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.unarchive_outlined, size: 16, color: isDark ? Colors.green[400] : Colors.green),
                                  onPressed: () => _restoreProduct(context, p),
                                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), side: BorderSide(color: borderColor)),
                                  label: Text('Restore', style: TextStyle(fontSize: 12, color: textColor)),
                                ),
                              ),
                              IconButton(icon: Icon(Icons.delete_outline_rounded, color: isDark ? Colors.red[400] : Colors.red, size: 18), tooltip: 'Permanently Delete', onPressed: () => _deleteProduct(context, p), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                            ] else ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _showBatchesDialog(context, p),
                                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), side: BorderSide(color: borderColor)),
                                  child: Text('Batches', style: TextStyle(fontSize: 12, color: textColor)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(icon: Icon(Icons.edit_outlined, color: isDark ? Colors.blue[400] : Colors.blue, size: 18), tooltip: 'Edit', onPressed: () => _showProductDialog(context, p, isEmployee, isAdmin), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                              IconButton(icon: Icon(Icons.archive_outlined, color: isDark ? Colors.orange[400] : Colors.orange, size: 18), tooltip: 'Archive Product', onPressed: () => _archiveProduct(context, p), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                            ]
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBatchesDialog(BuildContext ctx, Product product) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final provider = ctx.read<AppProvider>();
    final fmt = NumberFormat.currency(symbol: '₱');
    
    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) {
          final batches = provider.getBatchesForProduct(product.id);
          
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.blue),
                const SizedBox(width: 12),
                Text('Manage Batches: ${product.name}'),
              ],
            ),
            content: SizedBox(
              width: 700,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Inventory Batches', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Open Add Batch / Restock Dialog
                          await _showAddBatchDialog(dialogCtx, product, provider);
                          setDialogState(() {}); // Refresh batches view
                          setState(() {}); // Refresh main table
                        },
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('Order / Restock New Batch'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Expanded(
                    child: batches.isEmpty 
                        ? const Center(child: Text('No active batches for this product. Restock to create a batch.'))
                        : ListView.separated(
                            itemCount: batches.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final b = batches[index];
                              return ListTile(
                                leading: CircleAvatar(backgroundColor: isDark ? Colors.grey[900] : Colors.white, child: Text('${index+1}')),
                                title: Text('Supplier: ${b.supplier}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reason: ${b.restockReason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                    Text('Cost: ${fmt.format(b.cost)}  •  Expires: ${DateFormat('MMM d, yyyy').format(DateTime.parse(b.expirationDate))}', style: TextStyle(color: Colors.grey[700])),                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('Qty', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text('${b.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, color: Colors.orange, size: 24),
                                      onPressed: () async {
                                        await _showEditBatchDialog(dialogCtx, product, b, provider);
                                        setDialogState(() {}); // Refresh popup
                                        setState(() {}); // Refresh table
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }
                          )
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close'))
            ],
          );
        }
      )
    );
  }
  
  Future<void> _showEditBatchDialog(BuildContext ctx, Product product, ProductBatch batch, AppProvider provider) async {
    final qtyCtrl = TextEditingController(text: batch.quantity.toString());
    final costCtrl = TextEditingController(text: batch.cost.toString());
    final supplierCtrl = TextEditingController(text: batch.supplier);
    final reasonCtrl = TextEditingController(text: batch.restockReason);
    DateTime? expDate = DateTime.parse(batch.expirationDate);
    String? err;
    final int oldQty = batch.quantity; 

    await showDialog(
      context: ctx,
      builder: (editCtx) => StatefulBuilder(
        builder: (_, setEditState) => AlertDialog(
          title: const Text('Edit Batch Information'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (err != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(err!, style: const TextStyle(color: Colors.red))),
                  _field(qtyCtrl, 'Quantity Remaining', isNumber: true),
                  const SizedBox(height: 12),
                  _field(costCtrl, 'Wholesale Cost per unit', isNumber: true),
                  const SizedBox(height: 12),
                  _field(supplierCtrl, 'Supplier Name'),
                  const SizedBox(height: 12),
                  _field(reasonCtrl, 'Reason / Justification for Order', maxLines: 2),
                  const SizedBox(height: 16),
                  const Text('Batch Expiration Date', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(expDate == null ? 'Not Set' : DateFormat.yMMMd().format(expDate!)),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: editCtx, initialDate: expDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (date != null) setEditState(() => expDate = date);
                        },
                        child: const Text('Select Date'),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(editCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text);
                final cost = double.tryParse(costCtrl.text);
                final supplier = supplierCtrl.text.trim();
                final reason = reasonCtrl.text.trim();

                if (qty == null || qty < 0) { setEditState(() => err = 'Enter a valid quantity'); return; }
                if (cost == null || cost < 0) { setEditState(() => err = 'Enter a valid cost'); return; }
                if (supplier.isEmpty) { setEditState(() => err = 'Supplier is required'); return; }
                if (expDate == null) { setEditState(() => err = 'Expiration date is required'); return; }

                batch.quantity = qty;
                batch.cost = cost;
                batch.supplier = supplier;
                batch.restockReason = reason;
                batch.expirationDate = expDate!.toIso8601String();

                await provider.updateBatchInfo(batch, product, oldQty);

                Navigator.pop(editCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white),
              child: const Text('Save Changes'),
            )
          ],
        )
      )
    );
  }
  
  Future<void> _showAddBatchDialog(BuildContext ctx, Product product, AppProvider provider) async {
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime? expDate = DateTime.now().add(const Duration(days: 180));
    String? err;

    await showDialog(
      context: ctx,
      builder: (batchCtx) => StatefulBuilder(
        builder: (_, setBatchState) => AlertDialog(
          title: const Text('Register New Delivery / Batch'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (err != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(err!, style: const TextStyle(color: Colors.red))),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[200]!)),
                    child: Text('Current Stock: ${product.stock}\nReorder Level: ${product.reorderLevel}', style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),

                  _field(qtyCtrl, 'Quantity Received', isNumber: true),
                  const SizedBox(height: 12),
                  _field(costCtrl, 'Wholesale Cost per unit', isNumber: true),
                  const SizedBox(height: 12),
                  _field(supplierCtrl, 'Supplier Name'),
                  const SizedBox(height: 12),
                  _field(reasonCtrl, 'Reason / Justification for Order', maxLines: 2),
                  const SizedBox(height: 16),
                  
                  const Text('Batch Expiration Date', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(expDate == null ? 'Not Set' : DateFormat.yMMMd().format(expDate!)),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: batchCtx, initialDate: expDate ?? DateTime.now(),
                            firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (date != null) setBatchState(() => expDate = date);
                        },
                        child: const Text('Select Date'),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(batchCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text);
                final cost = double.tryParse(costCtrl.text);
                final supplier = supplierCtrl.text.trim();
                final reason = reasonCtrl.text.trim();

                if (qty == null || qty <= 0) { setBatchState(() => err = 'Enter a valid quantity'); return; }
                if (cost == null || cost < 0) { setBatchState(() => err = 'Enter a valid cost'); return; }
                if (supplier.isEmpty) { setBatchState(() => err = 'Supplier is required'); return; }
                if (reason.isEmpty) { setBatchState(() => err = 'A justification reason is required'); return; }
                if (expDate == null) { setBatchState(() => err = 'Expiration date is required for batches'); return; }

                final newBatch = ProductBatch(
                  id: _uuid.v4(),
                  productId: product.id, 
                  supplier: supplier,
                  restockReason: reason,
                  expirationDate: expDate!.toIso8601String(),
                  quantity: qty,
                  cost: cost,
                );

                await provider.addBatchAndRestock(newBatch, product);

                Navigator.pop(batchCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              child: const Text('Confirm Restock'),
            )
          ],
        )
      )
    );
  }

  void _showProductDialog(BuildContext ctx, Product? product, bool isReadOnly, bool isAdmin) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl = TextEditingController(text: product?.price.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?.stock.toString() ?? '');
    final reorderCtrl = TextEditingController(text: product?.reorderLevel.toString() ?? '');
    final barcodeCtrl = TextEditingController(text: product?.barcode ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    
    final dynamicCategories = List<String>.from(_koreanCategories);
    if (product != null && !dynamicCategories.contains(product.category)) {
      dynamicCategories.add(product.category);
    }
    
    String selectedCategory = product?.category ?? dynamicCategories.first;
    String? tempImagePath = product?.imagePath;
    String? err;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(isReadOnly ? 'View Details' : (product == null ? 'Add Product Master' : 'Edit Product Master')),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (err != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(err!, style: const TextStyle(color: Colors.red))),
                  if (product == null) Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                    child: const Text('Note: Adding a product here creates the master record. Use the "Batches" button later to officially restock and track costs/suppliers.', style: TextStyle(color: Colors.blue, fontSize: 12)),
                  ),
                  Center(
                    child: Column(
                      children: [
                        if (tempImagePath != null && File(tempImagePath!).existsSync())
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(tempImagePath!), height: 120, width: 120, fit: BoxFit.cover))
                        else
                          Container(height: 120, width: 120, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Icon(Icons.inventory, size: 50, color: Colors.grey[400])),
                        const SizedBox(height: 8),
                        if (!isReadOnly)
                          TextButton.icon(
                            onPressed: () async {
                               final result = await FilePicker.pickFiles(type: FileType.image);
                              if (result != null && result.files.single.path != null) {
                                final appDir = await getApplicationDocumentsDirectory();
                                final imagesDir = Directory('${appDir.path}/product_management_data/product_images');
                                if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
                                final ext = path.extension(result.files.single.path!);
                                final fileName = 'prod_${_uuid.v4()}$ext';
                                final savedImage = await File(result.files.single.path!).copy('${imagesDir.path}/$fileName');
                                setDialogState(() => tempImagePath = savedImage.path);
                              }
                            },
                            icon: const Icon(Icons.add_a_photo, size: 16),
                            label: const Text('Attach Image'),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(nameCtrl, 'Product Name', readOnly: isReadOnly),
                  const SizedBox(height: 12),
                  isReadOnly
                      ? _field(TextEditingController(text: selectedCategory), 'Category', readOnly: true)
                      : DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                          items: dynamicCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setDialogState(() => selectedCategory = v!),
                        ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(priceCtrl, 'Retail Price', isNumber: true, readOnly: isReadOnly)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(stockCtrl, 'Initial Stock', isNumber: true, readOnly: isReadOnly || (product != null && !isAdmin))), 
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _field(reorderCtrl, 'Reorder Level', isNumber: true, readOnly: isReadOnly)),
                            if (!isReadOnly)
                              IconButton(
                                icon: const Icon(Icons.calculate, color: Colors.blue),
                                tooltip: 'Smart Reorder Calculator',
                                onPressed: () => _showReorderPointCalculator(dialogCtx, reorderCtrl),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(barcodeCtrl, 'Barcode', readOnly: isReadOnly)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(descCtrl, 'Description', maxLines: 2, readOnly: isReadOnly),
                ],
              ),
            ),
          ),
          actions: [
            if (!isReadOnly) TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            if (isReadOnly) ElevatedButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close'))
            else
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final category = selectedCategory;
                  final price = double.tryParse(priceCtrl.text);
                  final stock = int.tryParse(stockCtrl.text) ?? 0;
                  final reorder = int.tryParse(reorderCtrl.text);
                  
                  if (name.isEmpty) { setDialogState(() => err = 'Product name is required'); return; }
                  if (price == null || reorder == null) { setDialogState(() => err = 'Price and reorder must be valid numbers'); return; }
                  
                  final now = DateTime.now().toIso8601String();
                  
                  if (product == null) {
                    ctx.read<AppProvider>().addProduct(Product(
                          id: _uuid.v4(), name: name, category: category, price: price, stock: stock,
                          reorderLevel: reorder, createdAt: now, updatedAt: now, barcode: barcodeCtrl.text.trim(),
                          description: descCtrl.text.trim(), autoDispose: false, imagePath: tempImagePath, 
                        ));
                  } else {
                    product.name = name; product.category = category; product.price = price; 
                    if (isAdmin) product.stock = stock; 
                    product.reorderLevel = reorder; product.barcode = barcodeCtrl.text.trim(); product.description = descCtrl.text.trim();
                    product.updatedAt = now; product.imagePath = tempImagePath; 
                    ctx.read<AppProvider>().updateProduct(product);
                  }
                  Navigator.pop(dialogCtx);
                },
                child: Text(product == null ? 'Create Master Record' : 'Save Changes'),
              ),
          ],
        ),
      ),
    );
  }

  void _archiveProduct(BuildContext ctx, Product product) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Archive Product'),
        content: Text('Are you sure you want to archive "${product.name}"? It will be hidden from the active inventory, but historical sales data will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { 
              product.status = 'Archived';
              ctx.read<AppProvider>().updateProduct(product); 
              Navigator.pop(ctx); 
              setState(() {}); // Refresh UI
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // --- NEW: Restore Archived Product ---
  void _restoreProduct(BuildContext ctx, Product product) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Restore Product'),
        content: Text('Restore "${product.name}" back into active inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { 
              product.status = 'Active'; // Reset to default active state
              ctx.read<AppProvider>().updateProduct(product); 
              Navigator.pop(ctx); 
              setState(() {}); // Refresh UI
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- NEW: Permanently Delete Product (Only visible in Archived tab) ---
  void _deleteProduct(BuildContext ctx, Product product) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Permanent Deletion', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text('Are you absolutely sure you want to permanently delete "${product.name}"? This action cannot be undone and may affect historical reports.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { 
              ctx.read<AppProvider>().deleteProduct(product.id); 
              Navigator.pop(ctx); 
              setState(() {}); // Refresh UI
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1, bool isNumber = false, bool readOnly = false}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return TextField(
        controller: ctrl, 
        maxLines: maxLines, 
        enabled: !readOnly,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
        decoration: InputDecoration(
          labelText: label, 
          border: const OutlineInputBorder(), 
          isDense: true, 
          filled: readOnly, 
          fillColor: readOnly ? (isDark ? Colors.grey[800] : Colors.grey[100]) : null
        ),
      );
    }
    
  Future<void> _showReorderPointCalculator(BuildContext ctx, TextEditingController targetCtrl) async {
    final demandCtrl = TextEditingController();
    final leadTimeCtrl = TextEditingController();
    final safetyCtrl = TextEditingController();
    String? err;

    await showDialog(
      context: ctx,
      builder: (calcCtx) => StatefulBuilder(
        builder: (_, setCalcState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_graph, color: Colors.blue[700]),
              const SizedBox(width: 12),
              const Text('Smart Reorder Calculator', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text('Formula: (Daily Demand × Lead Time) + Safety Stock', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                
                _field(demandCtrl, 'Avg. Daily Demand (units sold/day)'),
                const SizedBox(height: 12),
                _field(leadTimeCtrl, 'Lead Time (days to deliver)'),
                const SizedBox(height: 12),
                _field(safetyCtrl, 'Safety Stock (buffer units)'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(calcCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final demand = double.tryParse(demandCtrl.text) ?? 0;
                final leadTime = double.tryParse(leadTimeCtrl.text) ?? 0;
                final safety = double.tryParse(safetyCtrl.text) ?? 0;

                if (demand <= 0 || leadTime <= 0) {
                  setCalcState(() => err = 'Demand and Lead Time must be greater than 0');
                  return;
                }

                final double exactReorderPoint = (demand * leadTime) + safety;
                
                targetCtrl.text = exactReorderPoint.ceil().toString();
                
                Navigator.pop(calcCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
              child: const Text('Calculate & Apply'),
            )
          ],
        ),
      ),
    );
  }
}