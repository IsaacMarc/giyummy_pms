import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<SaleItem> _cart = [];
  final _barcodeCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  String _paymentMethod = 'Cash';
  String? _selectedProductId;
  String? _error;
  String? _success;
  
  // 1. ADDED: Missing boolean for the loading state
  bool _isProcessing = false; 

  static const _paymentMethods = ['Cash', 'Card', 'Mobile Payment'];

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.subtotal);
  double get _discountPct => double.tryParse(_discountCtrl.text) ?? 0;
  double get _discountAmt => _subtotal * _discountPct / 100;
  double get _finalTotal => _subtotal - _discountAmt;

  void _addToCart(List<Product> products) {
    if (_selectedProductId == null) return;
    final product = products.firstWhere((p) => p.id == _selectedProductId, orElse: () => products.first);
    _addProductToCart(product);
  }

  void _addProductToCart(Product product) {
    if (product.stock == 0) {
      setState(() => _error = '${product.name} is out of stock');
      return;
    }
    final idx = _cart.indexWhere((i) => i.productId == product.id);
    if (idx >= 0) {
      final currentQty = _cart[idx].quantity;
      if (currentQty >= product.stock) {
        setState(() => _error = 'Cannot exceed available stock (${product.stock})');
        return;
      }
      setState(() {
        _cart[idx].quantity++;
        _error = null;
        _success = null;
      });
    } else {
      setState(() {
        _cart.add(SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          price: product.price,
        ));
        _error = null;
        _success = null;
      });
    }
  }

  void _scanBarcode(List<Product> products) {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;
    try {
      final product = products.firstWhere((p) => p.barcode == barcode);
      _addProductToCart(product);
      _barcodeCtrl.clear();
    } catch (_) {
      setState(() => _error = 'Product with barcode "$barcode" not found');
      _barcodeCtrl.clear();
    }
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  // 2. ADDED: 'async' keyword
  void _completeSale() async {
    if (_cart.isEmpty) {
      setState(() => _error = 'Cart is empty');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
      _success = null;
    });

    // 3. FIXED: Changed _discount to _discountPct
    final err = await context.read<AppProvider>().addSale(
          _cart,
          _discountPct, 
          _paymentMethod,
        );

    if (!mounted) return;
    
    setState(() => _isProcessing = false);

    if (err != null) {
      // 4. FIXED: Display provider error on the UI safely
      setState(() => _error = err);
      return;
    }
    
    // 5. FIXED: Clear the cart and reset values on a successful sale!
    setState(() {
      _cart.clear();
      _discountCtrl.text = '0';
      _barcodeCtrl.clear();
      _success = 'Sale completed successfully!';
    });
  }

  // ==========================================
  // KEEP YOUR @override Widget build(...) BELOW 
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final products = context.watch<AppProvider>().getProducts();
    final inStockProducts = products.where((p) => p.stock > 0).toList();
    final fmt = NumberFormat.currency(symbol: '\$');

    _selectedProductId ??= inStockProducts.isNotEmpty ? inStockProducts.first.id : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: product selection
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Colors.red[700], fontSize: 13)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _error = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                if (_success != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(_success!,
                        style: TextStyle(color: Colors.green[700])),
                  ),
                Card(
                  color: Colors.white,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Product Selection',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        // Barcode scanner
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _barcodeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Scan Barcode',
                                  prefixIcon:
                                      Icon(Icons.qr_code_scanner_outlined),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _scanBarcode(products),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _scanBarcode(products),
                              child: const Text('Scan'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        // Dropdown
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedProductId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Product',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: inStockProducts.map((p) {
                                  return DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                        '${p.name} (Stock: ${p.stock}) - ${fmt.format(p.price)}',
                                        overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedProductId = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _addToCart(products),
                              icon: const Icon(Icons.add_shopping_cart),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Cart
                Expanded(
                  child: Card(
                    color:Colors.white,
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Shopping Cart',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const Spacer(),
                              Text('${_cart.length} items',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          Expanded(
                            child: _cart.isEmpty
                                ? Center(
                                    child: Text('Cart is empty',
                                        style: TextStyle(
                                            color: Colors.grey[400])))
                                : ListView.separated(
                                    itemCount: _cart.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final item = _cart[i];
                                      return ListTile(
                                        dense: true,
                                        title: Text(item.productName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        subtitle: Text(
                                            '${fmt.format(item.price)} × ${item.quantity}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                                fmt.format(item.subtotal),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline,
                                                  color: Colors.red, size: 20),
                                              onPressed: () =>
                                                  _removeFromCart(i),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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
          const SizedBox(width: 16),
          // Right: checkout
          SizedBox(
            width: 280,
            child: Card(
              color: Colors.white,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Checkout',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _discountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Discount (%)',
                        prefixIcon: Icon(Icons.percent),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _paymentMethods
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v ?? 'Cash'),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    _totalRow('Subtotal', fmt.format(_subtotal)),
                    if (_discountPct > 0)
                      _totalRow(
                          'Discount (${_discountPct.toStringAsFixed(0)}%)',
                          '-${fmt.format(_discountAmt)}',
                          color: Colors.red[700]),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text(
                            fmt.format(_finalTotal),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _completeSale,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Complete Sale',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
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
    );
  }

  Widget _totalRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
