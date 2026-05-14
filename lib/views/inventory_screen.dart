import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> all) {
    var list = all;
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    if (_categoryFilter != 'All') {
      list = list.where((p) => p.category == _categoryFilter).toList();
    }
    return list;
  }

  List<String> _categories(List<Product> products) {
    final cats = {'All', ...products.map((p) => p.category)};
    return cats.toList();
  }

  void _showAddDialog(BuildContext ctx) {
    _showProductDialog(ctx, null);
  }

  void _showEditDialog(BuildContext ctx, Product product) {
    _showProductDialog(ctx, product);
  }

  void _showProductDialog(BuildContext ctx, Product? product) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final categoryCtrl = TextEditingController(text: product?.category ?? '');
    final priceCtrl =
        TextEditingController(text: product?.price.toString() ?? '');
    final stockCtrl =
        TextEditingController(text: product?.stock.toString() ?? '');
    final reorderCtrl =
        TextEditingController(text: product?.reorderLevel.toString() ?? '');
    final barcodeCtrl = TextEditingController(text: product?.barcode ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    String? err;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Add Product' : 'Edit Product'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(err!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  _field(nameCtrl, 'Product Name'),
                  const SizedBox(height: 12),
                  _field(categoryCtrl, 'Category'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(priceCtrl, 'Price')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(stockCtrl, 'Stock')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(reorderCtrl, 'Reorder Level')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(barcodeCtrl, 'Barcode')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(descCtrl, 'Description', maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final category = categoryCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text);
                final stock = int.tryParse(stockCtrl.text);
                final reorder = int.tryParse(reorderCtrl.text);
                if (name.isEmpty || category.isEmpty) {
                  setDialogState(() => err = 'Name and category are required');
                  return;
                }
                if (price == null || stock == null || reorder == null) {
                  setDialogState(
                      () => err = 'Price, stock, reorder must be numbers');
                  return;
                }
                final now = DateTime.now().toIso8601String();
                if (product == null) {
                  ctx.read<AppProvider>().addProduct(Product(
                        id: _uuid.v4(),
                        name: name,
                        category: category,
                        price: price,
                        stock: stock,
                        reorderLevel: reorder,
                        createdAt: now,
                        updatedAt: now,
                        barcode: barcodeCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                      ));
                } else {
                  product.name = name;
                  product.category = category;
                  product.price = price;
                  product.stock = stock;
                  product.reorderLevel = reorder;
                  product.barcode = barcodeCtrl.text.trim();
                  product.description = descCtrl.text.trim();
                  product.updatedAt = now;
                  ctx.read<AppProvider>().updateProduct(product);
                }
                Navigator.pop(dialogCtx);
              },
              child: Text(product == null ? 'Add' : 'Save'),
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
        content: Text(
            'Are you sure you want to delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ctx.read<AppProvider>().deleteProduct(product.id);
              Navigator.pop(ctx);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<AppProvider>().getProducts();
    final filtered = _filtered(products);
    final categories = _categories(products);
    final fmt = NumberFormat.currency(symbol: '\$');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Products',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _categoryFilter,
                    items: categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _categoryFilter = v ?? 'All'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          Colors.grey[50]),
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Reorder')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered.map((p) {
                        final status = p.status;
                        final statusColor = status == 'Out of Stock'
                            ? Colors.red
                            : status == 'Low Stock'
                                ? Colors.orange
                                : Colors.green;
                        return DataRow(cells: [
                          DataCell(Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                          DataCell(Text(p.category)),
                          DataCell(Text(fmt.format(p.price))),
                          DataCell(Text('${p.stock}')),
                          DataCell(Text('${p.reorderLevel}')),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          )),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.blue, size: 18),
                                onPressed: () =>
                                    _showEditDialog(context, p),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 18),
                                onPressed: () =>
                                    _deleteProduct(context, p),
                                tooltip: 'Delete',
                              ),
                            ],
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '${filtered.length} of ${products.length} products',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
