import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _qtyCtrl = TextEditingController(text: '1'); 
  
  String _paymentMethod = 'Cash';
  String? _selectedProductId;
  String? _error;
  String? _success;
  
  bool _isProcessing = false; 

  static const _paymentMethods = ['Cash', 'Card', 'Mobile Payment'];

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _discountCtrl.dispose();
    _qtyCtrl.dispose(); 
    super.dispose();
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.subtotal);
  double get _discountPct => double.tryParse(_discountCtrl.text) ?? 0;
  double get _discountAmt => _subtotal * _discountPct / 100;
  double get _finalTotal => _subtotal - _discountAmt;

  void _addToCart(List<Product> products) {
    if (_selectedProductId == null) return;
    
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (qty <= 0) {
      setState(() => _error = 'Quantity must be at least 1');
      return;
    }

    final product = products.firstWhere((p) => p.id == _selectedProductId, orElse: () => products.first);
    _addProductToCart(product, qty);
    _qtyCtrl.text = '1';
  }

  void _scanBarcode(List<Product> products) {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;
    
    final qty = int.tryParse(_qtyCtrl.text) ?? 1; 

    try {
      final product = products.firstWhere((p) => p.barcode == barcode);
      _addProductToCart(product, qty);
      _barcodeCtrl.clear();
      _qtyCtrl.text = '1'; 
    } catch (_) {
      setState(() => _error = 'Product with barcode "$barcode" not found');
      _barcodeCtrl.clear();
    }
  }

  void _addProductToCart(Product product, int qtyToAdd) {
    if (product.stock == 0) {
      setState(() => _error = '${product.name} is out of stock');
      return;
    }
    
    final idx = _cart.indexWhere((i) => i.productId == product.id);
    
    if (idx >= 0) {
      final currentQty = _cart[idx].quantity;
      if (currentQty + qtyToAdd > product.stock) {
        setState(() => _error = 'Cannot exceed available stock (${product.stock})');
        return;
      }
      setState(() {
        _cart[idx].quantity += qtyToAdd;
        _error = null;
        _success = null;
      });
    } else {
      if (qtyToAdd > product.stock) {
        setState(() => _error = 'Cannot exceed available stock (${product.stock})');
        return;
      }
      setState(() {
        _cart.add(SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: qtyToAdd,
          price: product.price,
        ));
        _error = null;
        _success = null;
      });
    }
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

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

      // 1. Snapshot the data for the receipt before the cart clears
      final receiptItems = List<SaleItem>.from(_cart);
      final receiptSubtotal = _subtotal;
      final receiptDiscount = _discountAmt;
      final receiptTotal = _finalTotal;
      final receiptPayment = _paymentMethod;

      // 2. FIX: Pass 'receiptItems' instead of '_cart' so clearing the UI doesn't wipe the memory!
      final err = await context.read<AppProvider>().addSale(
            receiptItems, 
            _discountPct, 
            _paymentMethod,
          );

      if (!mounted) return;
      
      setState(() => _isProcessing = false);

      if (err != null) {
        setState(() => _error = err);
        return;
      }
      
      // 3. Clear the cart data on the UI
      setState(() {
        _cart.clear(); // This is now safe to do!
        _discountCtrl.text = '0';
        _barcodeCtrl.clear();
        _qtyCtrl.text = '1';
        _success = 'Sale completed successfully!';
      });

      // 4. Display the Receipt Dialog
      _showReceiptDialog(context, receiptItems, receiptSubtotal, receiptDiscount, receiptTotal, receiptPayment);
    }

  // --- NEW: Receipt Dialog Widget ---
  void _showReceiptDialog(BuildContext context, List<SaleItem> items, double subtotal, double discountAmt, double finalTotal, String paymentMethod) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold))),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(now, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                const Divider(thickness: 2),
                ...items.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${i.productName} (x${i.quantity})', overflow: TextOverflow.ellipsis)),
                      Text(fmt.format(i.subtotal)),
                    ],
                  ),
                )),
                const Divider(thickness: 2),
                _totalRow('Subtotal', fmt.format(subtotal)),
                if (discountAmt > 0)
                  _totalRow('Discount', '-${fmt.format(discountAmt)}', color: Colors.red),
                _totalRow('Total', fmt.format(finalTotal), isBold: true),
                const SizedBox(height: 8),
                Text('Paid via $paymentMethod', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                const SizedBox(height: 24),
                const Text('Thank you for your purchase!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            child: const Text('Close & Next Sale'),
          )
        ],
      )
    );
  }

  // --- NEW: View All Recent Sales Dialog Widget ---
  void _showAllSalesDialog(BuildContext context, List<Sale> sales, NumberFormat fmt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Recent Sales'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: sales.isEmpty 
            ? const Center(child: Text('No recent sales found.'))
            : ListView.builder(
              shrinkWrap: true,
              itemCount: sales.length,
              itemBuilder: (context, index) {
                // Show newest first
                final sale = sales.reversed.toList()[index]; 
                final time = sale.timestamp.length >= 16 
                    ? sale.timestamp.substring(0, 16).replaceAll('T', ' ') 
                    : sale.timestamp;
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ExpansionTile(
                    leading: Icon(Icons.receipt, color: Colors.blue[700]),
                    title: Text('${fmt.format(sale.finalTotal)} - ${sale.paymentMethod}'),
                    subtitle: Text('Cashier: ${sale.cashierName} • $time'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            ...sale.items.map((i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${i.quantity}x ${i.productName}'),
                                  Text(fmt.format(i.subtotal)),
                                ],
                              ),
                            )),
                            const Divider(),
                            if (sale.discount > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Discount:', style: TextStyle(color: Colors.red)),
                                  Text('-${fmt.format(sale.discount)}', style: const TextStyle(color: Colors.red)),
                                ],
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Final Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(fmt.format(sale.finalTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              }
            ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final products = provider.getProducts();
    final allSales = provider.getSales(); 
    final inStockProducts = products.where((p) => p.stock > 0).toList();
    final fmt = NumberFormat.currency(symbol: '\$');

    _selectedProductId ??= inStockProducts.isNotEmpty ? inStockProducts.first.id : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Product Selection & Cart
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
                        
                        // Dropdown, Quantity Field, and Add Button
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
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
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _qtyCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
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
                // Shopping Cart
                Expanded(
                  child: Card(
                    color: Colors.white,
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
          
          // Right: Checkout & Recent Sales Stream
          SizedBox(
            width: 300,
            // Wrapped in a ScrollView so the right side never overflows
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Checkout Card
                  Card(
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
                              onPressed: _isProcessing ? null : _completeSale,
                              icon: _isProcessing 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(_isProcessing ? 'Processing...' : 'Complete Sale',
                                  style: const TextStyle(
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
                  const SizedBox(height: 16),
                  
                  // 2. Recent Sales Card
                  Card(
                    color: Colors.white,
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Recent Sales', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              TextButton(
                                onPressed: () => _showAllSalesDialog(context, allSales, fmt),
                                child: const Text('View All'),
                              )
                            ],
                          ),
                          const Divider(),
                          if (allSales.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No sales today.', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            // Render a quick preview of the last 3 sales
                            ...allSales.reversed.take(3).map((s) {
                              final time = s.timestamp.length >= 16 
                                  ? s.timestamp.substring(11, 16) 
                                  : '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt, color: Colors.grey[400], size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.cashierName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          Text('${s.items.length} items · $time',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Text(fmt.format(s.finalTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    )
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.black : Colors.grey[700], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}