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

// --- NEW: Local Data Models for Batches (To be moved to models.dart later) ---
class ProductBatch {
  final String id;
  final String supplier;
  final String restockReason;
  final DateTime expirationDate;
  int quantity;
  final double cost;

  ProductBatch({
    required this.id,
    required this.supplier,
    required this.restockReason,
    required this.expirationDate,
    required this.quantity,
    required this.cost,
  });
}

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

  // --- NEW: Local State to simulate database relations ---
  // In a real app, this would be fetched from your database provider.
  final Map<String, List<ProductBatch>> _productBatches = {};

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

  // --- Helper to calculate batch-driven metrics ---
  double _getAverageCost(String productId) {
    final batches = _productBatches[productId] ?? [];
    if (batches.isEmpty) return 0.0;
    double totalValue = batches.fold(0.0, (sum, b) => sum + (b.cost * b.quantity));
    int totalQty = batches.fold(0, (sum, b) => sum + b.quantity);
    return totalQty == 0 ? 0.0 : totalValue / totalQty;
  }

  DateTime? _getNextExpiration(String productId) {
    final batches = _productBatches[productId] ?? [];
    final activeBatches = batches.where((b) => b.quantity > 0).toList();
    if (activeBatches.isEmpty) return null;
    activeBatches.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
    return activeBatches.first.expirationDate;
  }

  List<Product> _filtered(List<Product> all) {
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
            case 8: cmp = a.status.compareTo(b.status); break; 
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
    return ['All', ...dynamicCats, ..._koreanCategories].toSet().toList();
  }

  // --- KPI Card Widget ---
  Widget _buildKPICard(String title, String value, String subtitle, Color mainColor, Color bgColor, IconData icon) {
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
                Text(title, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                Icon(icon, color: mainColor.withOpacity(0.5), size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: mainColor == Colors.black ? Colors.black87 : mainColor)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currentUser = provider.currentUser;
    final isEmployee = currentUser?.role == 'Employee'; 

    final products = provider.getProducts();
    final filtered = _filtered(products);
    final categories = _categories(products);
    final fmt = NumberFormat.currency(symbol: '\₱');

    // KPI Calculations
    final totalValue = products.fold(0.0, (sum, p) {
      final avgCost = _getAverageCost(p.id);
      final costToUse = avgCost > 0 ? avgCost : (p.price * 0.6); // Fallback cost if no batches
      return sum + (costToUse * p.stock);
    });
    final lowStockCount = products.where((p) => p.stock <= p.reorderLevel && p.stock > 0).length;
    
    // NEW: Expiring Soon Logic (Within 30 Days)
    final now = DateTime.now();
    final expiringSoonCount = products.where((p) {
      final nextExp = _getNextExpiration(p.id);
      if (nextExp == null) return false;
      return nextExp.difference(now).inDays <= 30;
    }).length;

    final totalPages = (filtered.length / _itemsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1; 
    
    final paginatedProducts = filtered.isNotEmpty 
        ? filtered.skip(_currentPage * _itemsPerPage).take(_itemsPerPage).toList()
        : <Product>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Inventory', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
                      const SizedBox(height: 4),
                      Text('${products.length} items across ${categories.length - 1} categories', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                    ],
                  ),
                  if (!isEmployee)
                    ElevatedButton.icon(
                      onPressed: () => _showProductDialog(context, null, false),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add new item'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, elevation: 0),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // --- KPI ROW ---
              Row(
                children: [
                  _buildKPICard('TOTAL STOCKS', '${products.length}', 'across all categories', Colors.black, Colors.white, Icons.layers),
                  const SizedBox(width: 16),
                  _buildKPICard('EST. STOCK VALUE', fmt.format(totalValue), 'based on batch cost', Colors.green[700]!, const Color(0xFFF0FDF4), Icons.monetization_on),
                  const SizedBox(width: 16),
                  _buildKPICard('LOW-STOCK ITEMS', '$lowStockCount', 'below reorder point', Colors.orange[700]!, Colors.orange[50]!, Icons.warning_amber_rounded),
                  const SizedBox(width: 16),
                  // NEW: Expiring Soon KPI
                  _buildKPICard('EXPIRING SOON', '$expiringSoonCount', 'within next 30 days', Colors.red[700]!, const Color(0xFFFEF2F2), Icons.event_busy),
                ],
              ),
              const SizedBox(height: 32),

              // --- MAIN TABLE CARD ---
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- FILTERS ---
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search by Barcode or name',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              onChanged: (_) => setState(() => _currentPage = 0),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // NEW: Category Dropdown instead of Chips
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _categoryFilter,
                              decoration: InputDecoration(
                                labelText: 'Filter by Category',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() { _categoryFilter = v!; _currentPage = 0; }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // --- DATA TABLE ---
                    // NEW: LayoutBuilder forces the DataTable to stretch across the full width
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
child: DataTable(
                              sortColumnIndex: _sortColumnIndex,
                              sortAscending: _sortAscending,
                              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                              dataRowMinHeight: 70,
                              dataRowMaxHeight: 70,
                              horizontalMargin: 24,
                              columnSpacing: 20,
                              columns: [
                                // 1
                                DataColumn(label: Text('BARCODE', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                                // 2
                                DataColumn(label: Text('ITEM', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                                // 3
                                DataColumn(label: Text('CATEGORY', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                                // 4
                                DataColumn(label: Text('COST', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                // 5
                                DataColumn(label: Text('PRICE (MARKUP)', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort, numeric: true),
                                // 6
                                DataColumn(label: Text('STOCK', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort, numeric: true),
                                // 7
                                DataColumn(label: Text('REORDER', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort, numeric: true),
                                // 8
                                DataColumn(label: Text('NEXT EXP.', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                                // 9
                                DataColumn(label: Text('STATUS', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)), onSort: _onSort),
                                // 10
                                DataColumn(label: Text('ACTIONS', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                              rows: paginatedProducts.map((p) {
                                final status = p.status;
                                final statusColor = status == 'Out of Stock' || status == 'Expired' ? Colors.red 
                                                  : status == 'Low Stock' ? Colors.orange : Colors.green;
                                
                                final avgCost = _getAverageCost(p.id);
                                final costToDisplay = avgCost > 0 ? avgCost : (p.price * 0.6); 
                                final markupPct = costToDisplay > 0 ? ((p.price - costToDisplay) / costToDisplay) * 100 : 0.0;
                                
                                final nextExp = _getNextExpiration(p.id);
                                final expString = nextExp != null ? DateFormat('MMM d, yyyy').format(nextExp) : 'No Batch Data';
                                final isExpiringSoon = nextExp != null && nextExp.difference(now).inDays <= 30;

                                final double stockProgress = p.reorderLevel > 0 ? (p.stock / (p.reorderLevel * 3)).clamp(0.0, 1.0) : 1.0;

                                return DataRow(cells: [
                                  // 1
                                  DataCell(Text(p.barcode.isEmpty ? 'N/A' : p.barcode, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                  // 2
                                  DataCell(
                                    Row(
                                      children: [
                                        p.imagePath != null && File(p.imagePath!).existsSync()
                                            ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(p.imagePath!), width: 40, height: 40, fit: BoxFit.cover))
                                            : Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)), child: Icon(Icons.inventory, size: 20, color: Colors.grey[400])),
                                        const SizedBox(width: 12),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                            if (p.description.isNotEmpty) SizedBox(width: 120, child: Text(p.description, style: TextStyle(color: Colors.grey[500], fontSize: 11), overflow: TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      ],
                                    )
                                  ),
                                  // 3
                                  DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)), child: Text(p.category, style: TextStyle(fontSize: 12, color: Colors.grey[800])))),
                                  // 4
                                  DataCell(Text(fmt.format(costToDisplay), style: TextStyle(color: Colors.grey[600]))),
                                  // 5
                                  DataCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(fmt.format(p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('+${markupPct.toStringAsFixed(1)}%', style: TextStyle(color: Colors.green[700], fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  ),
                                  // 6
                                  DataCell(
                                    SizedBox(
                                      width: 80,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${p.stock}', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(value: stockProgress, backgroundColor: Colors.grey[200], color: statusColor, minHeight: 4, borderRadius: BorderRadius.circular(2)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // 7: REORDER (This was missing from the DataRow before)
                                  DataCell(Text('${p.reorderLevel}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600))),
                                  // 8
                                  DataCell(Text(expString, style: TextStyle(color: isExpiringSoon ? Colors.red[700] : Colors.black87, fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal))),
                                  // 9
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
                                  // 10
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isEmployee)
                                        OutlinedButton(
                                          onPressed: () => _showBatchesDialog(context, p),
                                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                                          child: const Text('Batches', style: TextStyle(fontSize: 12)),
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18), onPressed: () => _showProductDialog(context, p, isEmployee)),
                                      IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Color.fromARGB(255, 255, 82, 82), size: 18), onPressed: () => _deleteProduct(context, p,)),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        );
                      }
                    ),
                    const Divider(height: 1),
                    
                    // --- PAGINATION ---
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${filtered.isEmpty ? 0 : (_currentPage * _itemsPerPage) + 1} - ${min((_currentPage + 1) * _itemsPerPage, filtered.length)} of ${filtered.length} products', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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

  // --- NEW: Batch & Restock Management Dialog ---
  void _showBatchesDialog(BuildContext ctx, Product product) {
    final provider = ctx.read<AppProvider>();
    final fmt = NumberFormat.currency(symbol: '\₱');
    
    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) {
          final batches = _productBatches[product.id] ?? [];
          
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
                      Text('Active Inventory Batches (FIFO)', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
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
                                leading: CircleAvatar(backgroundColor: Colors.blue[50], child: Text('${index+1}')),
                                title: Text('Supplier: ${b.supplier}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reason: ${b.restockReason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                    Text('Cost: ${fmt.format(b.cost)}  •  Expires: ${DateFormat('MMM d, yyyy').format(b.expirationDate)}', style: TextStyle(color: Colors.grey[700])),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Qty Remaining', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text('${b.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
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

  // --- NEW: Add Batch (Restock) Dialog ---
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
              onPressed: () {
                final qty = int.tryParse(qtyCtrl.text);
                final cost = double.tryParse(costCtrl.text);
                final supplier = supplierCtrl.text.trim();
                final reason = reasonCtrl.text.trim();

                if (qty == null || qty <= 0) { setBatchState(() => err = 'Enter a valid quantity'); return; }
                if (cost == null || cost < 0) { setBatchState(() => err = 'Enter a valid cost'); return; }
                if (supplier.isEmpty) { setBatchState(() => err = 'Supplier is required'); return; }
                if (reason.isEmpty) { setBatchState(() => err = 'A justification reason is required'); return; }
                if (expDate == null) { setBatchState(() => err = 'Expiration date is required for batches'); return; }

                // Create the batch locally
                final newBatch = ProductBatch(
                  id: _uuid.v4(),
                  supplier: supplier,
                  restockReason: reason,
                  expirationDate: expDate!,
                  quantity: qty,
                  cost: cost,
                );

                _productBatches.putIfAbsent(product.id, () => []).add(newBatch);

                // Update the global product stock
                product.stock += qty;
                product.updatedAt = DateTime.now().toIso8601String();
                if (product.status == 'Expired' || product.status == 'Out of Stock') {
                  product.autoDispose = false; // Reset if it was dumped
                }
                provider.updateProduct(product);

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

  // --- STANDARD PRODUCT ADD/EDIT DIALOG ---
  void _showProductDialog(BuildContext ctx, Product? product, bool isReadOnly) {
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
                          value: selectedCategory,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                          items: dynamicCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setDialogState(() => selectedCategory = v!),
                        ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(priceCtrl, 'Retail Price', isNumber: true, readOnly: isReadOnly)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(stockCtrl, 'Initial Stock', isNumber: true, readOnly: isReadOnly || product != null)), // Lock stock edit if product exists (force batches)
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(reorderCtrl, 'Reorder Level', isNumber: true, readOnly: isReadOnly)),
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

  void _deleteProduct(BuildContext ctx, Product product) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { ctx.read<AppProvider>().deleteProduct(product.id); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1, bool isNumber = false, bool readOnly = false}) {
    return TextField(
      controller: ctrl, maxLines: maxLines, enabled: !readOnly,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, filled: readOnly, fillColor: readOnly ? Colors.grey[100] : null),
    );
  }
}