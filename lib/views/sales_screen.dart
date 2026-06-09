import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart'; 

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<SaleItem> _cart = [];
  final _barcodeCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _amountGivenCtrl = TextEditingController(); 
  final _searchCtrl = TextEditingController(); 
  
  String _paymentMethod = 'Cash';
  String _selectedCategory = 'All'; 
  String _searchQuery = ''; 
  String? _error;
  String? _success;
  
  bool _isProcessing = false; 
  int? _customerWindowId; 

  static const _paymentMethods = ['Cash', 'Card', 'Mobile Payment'];

  @override
  void initState() {
    super.initState();
    _amountGivenCtrl.addListener(() {
      setState(() {});
      _syncCartToCustomer();
    });
    _discountCtrl.addListener(() {
      setState(() {});
      _syncCartToCustomer();
    });
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _discountCtrl.dispose();
    _amountGivenCtrl.dispose();
    _searchCtrl.dispose(); 
    super.dispose();
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.subtotal);
  double get _discountPct => double.tryParse(_discountCtrl.text) ?? 0;
  double get _discountAmt => _subtotal * _discountPct / 100;
  double get _finalTotal => _subtotal - _discountAmt;
  double get _amountGiven => double.tryParse(_amountGivenCtrl.text) ?? 0.0;
  double get _change => (_amountGiven - _finalTotal) > 0 ? (_amountGiven - _finalTotal) : 0.0;

  void _openCustomerDisplay() async {
    try {
      final initialPayload = {
        'type': 'customer_display',
        'cart': _cart.map((item) => {
          'productName': item.productName,
          'quantity': item.quantity,
          'subtotal': item.subtotal,
        }).toList(),
        'total': _finalTotal,
        'change': _change,
        'discount': _discountAmt,
      };

      final window = await DesktopMultiWindow.createWindow(jsonEncode(initialPayload));
      
      window
        ..setFrame(const Offset(0, 0) & const Size(1024, 768))
        ..center()
        ..setTitle('Customer Display')
        ..show();
        
      setState(() {
        _customerWindowId = window.windowId;
      });
      
    } catch (e) {
      setState(() => _error = 'Multi-window requires a desktop environment.');
    }
  }

  void _syncCartToCustomer() {
    if (_customerWindowId != null) {
      final payload = {
        'cart': _cart.map((item) => {
          'productName': item.productName,
          'quantity': item.quantity,
          'subtotal': item.subtotal,
        }).toList(),
        'total': _finalTotal,
        'change': _change,
        'discount': _discountAmt,
      };
      
      try {
        DesktopMultiWindow.invokeMethod(
          _customerWindowId!, 
          'sync_cart', 
          jsonEncode(payload),
        );
      } catch (e) {
        _customerWindowId = null;
      }
    }
  }

  void _scanBarcode(List<Product> products) {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;
    
    try {
      final product = products.firstWhere((p) => p.barcode == barcode);
      _addProductToCart(product, 1);
      _barcodeCtrl.clear();
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
    
    _syncCartToCustomer();
  }

  void _updateCartQty(int index, int delta, int maxStock) {
    setState(() {
      final newQty = _cart[index].quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else if (newQty <= maxStock) {
        _cart[index].quantity = newQty;
      } else {
        _error = 'Cannot exceed available stock ($maxStock)';
      }
    });
    
    _syncCartToCustomer();
  }

  void _completeSale() async {
    if (_cart.isEmpty) {
      setState(() => _error = 'Cart is empty');
      return;
    }

    if (_amountGiven < _finalTotal && _paymentMethod == 'Cash') {
      setState(() => _error = 'Insufficient amount given by customer.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
      _success = null;
    });

    final receiptItems = List<SaleItem>.from(_cart);
    final receiptSubtotal = _subtotal;
    final receiptDiscount = _discountAmt;
    final receiptTotal = _finalTotal;
    final receiptPayment = _paymentMethod;
    final receiptGiven = _amountGiven;
    final receiptChange = _change;

    final provider = context.read<AppProvider>();
    final err = await provider.addSale(receiptItems, _discountPct, _paymentMethod);

    if (!mounted) return;
    
    setState(() => _isProcessing = false);

    if (err != null) {
      setState(() => _error = err);
      return;
    }

    final allSales = provider.getSales();
    final newSale = allSales.last; 
    final txnId = newSale.id.substring(0, 12).toUpperCase(); 
    
    setState(() {
      _cart.clear();
      _discountCtrl.text = '0';
      _amountGivenCtrl.clear();
      _barcodeCtrl.clear();
      _success = 'Transaction Complete!';
    });
    _syncCartToCustomer(); 

    _showReceiptDialog(context, receiptItems, receiptSubtotal, receiptDiscount, receiptTotal, receiptPayment, receiptGiven, receiptChange, txnId, newSale.cashierName);
  }

  void _showReceiptDialog(BuildContext context, List<SaleItem> items, double subtotal, double discountAmt, double finalTotal, String paymentMethod, double given, double change, String txnId, String cashierName) {
    final provider = context.read<AppProvider>(); 
    final fmt = NumberFormat.currency(symbol: '₱');
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white, 
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Text(provider.storeName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))),
                    const SizedBox(height: 8),
                    Center(child: Text('${provider.storeAddress}\n${provider.storeContact.isNotEmpty ? "Contact: ${provider.storeContact}" : ""}', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                    const SizedBox(height: 12),
                    
                    const _DashedLine(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cashier: $cashierName', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                        const Text('Manager: Admin', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerLeft, child: Text('Date: $now', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black))),
                    const SizedBox(height: 12),
                    const _DashedLine(),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Name', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black))),
                        Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black))),
                        Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(i.productName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black))),
                          Expanded(flex: 1, child: Text('${i.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black))),
                          Expanded(flex: 2, child: Text(fmt.format(i.subtotal), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 12),
                    const _DashedLine(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sub Total', style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text(fmt.format(subtotal), style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (discountAmt > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('DISCOUNT', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                          Text('-${fmt.format(discountAmt)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(paymentMethod.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                        Text(fmt.format(given > 0 ? given : finalTotal), style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CHANGE', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                        Text(fmt.format(change), style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: txnId,
                      width: double.infinity,
                      height: 60,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    const Text('THANK YOU!\nGlad to see you again!', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.black)),
                  ],
                ),
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
        );
      }
    );
  }

  void _showAllSalesDialog(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₱');
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text('Digital Receipts & Recent Sales', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              content: SizedBox(
                width: 600,
                height: 500,
                child: Consumer<AppProvider>(
                  builder: (context, provider, child) {
                    final allSales = provider.getSales();
                    final sales = allSales.where((s) {
                      final shortId = s.id.substring(0, 12).toUpperCase();
                      return shortId.contains(searchQuery.toUpperCase());
                    }).toList();
                    
                    return Column(
                      children: [
                        TextField(
                          onChanged: (val) => setDialogState(() => searchQuery = val),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Search by Barcode / Reference Number',
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500]),
                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[400] : Colors.blue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: sales.isEmpty
                            ? Center(child: Text('No receipts found.', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black)))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: sales.length,
                                itemBuilder: (context, index) {
                                  final sale = sales.reversed.toList()[index]; 
                                  final time = sale.timestamp.length >= 16 ? sale.timestamp.substring(0, 16).replaceAll('T', ' ') : sale.timestamp;
                                  final refId = sale.id.substring(0, 12).toUpperCase();
                                  
                                  return Card(
                                    color: isDark ? Colors.grey[900] : Colors.white,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ExpansionTile(
                                      leading: Icon(Icons.receipt, color: Colors.blue[700]),
                                      title: Text('REF: $refId  |  ${fmt.format(sale.finalTotal)}', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                      subtitle: Text('Cashier: ${sale.cashierName} • $time • ${sale.paymentMethod}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                      iconColor: isDark ? Colors.white : Colors.black,
                                      collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey[600],
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(24),
                                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Center(child: Text(provider.storeName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))),
                                                    const SizedBox(height: 8),
                                                    Center(child: Text('${provider.storeAddress}\n${provider.storeContact.isNotEmpty ? "Contact: ${provider.storeContact}" : ""}', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                    const SizedBox(height: 12),
                                                    const _DashedLine(),
                                                    const SizedBox(height: 8),
                                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Cashier: ${sale.cashierName}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)), const Text('Manager: Admin', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))]),
                                                    const SizedBox(height: 4),
                                                    Align(alignment: Alignment.centerLeft, child: Text('Date: $time', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                    const SizedBox(height: 8),
                                                    const _DashedLine(),
                                                    const SizedBox(height: 8),
                                                    const Row(children: [Expanded(flex: 3, child: Text('Name', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))), Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))), Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)))]),
                                                    const SizedBox(height: 4),
                                                    ...sale.items.map((i) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(flex: 3, child: Text(i.productName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))), Expanded(flex: 1, child: Text('${i.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))), Expanded(flex: 2, child: Text(fmt.format(i.subtotal), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)))]))),
                                                    const SizedBox(height: 8),
                                                    const _DashedLine(),
                                                    const SizedBox(height: 8),
                                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sub Total', style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)), Text(fmt.format(sale.finalTotal + sale.discount), style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black))]),
                                                    const SizedBox(height: 8),
                                                    if (sale.discount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('DISCOUNT', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)), Text('-${fmt.format(sale.discount)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))]),
                                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(sale.paymentMethod.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)), Text(fmt.format(sale.finalTotal), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))]),
                                                    const SizedBox(height: 16),
                                                    BarcodeWidget(barcode: Barcode.code128(), data: refId, width: double.infinity, height: 40, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                                                    const SizedBox(height: 16),
                                                    const Text('THANK YOU!\nGlad to see you again!', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              
                                              // --- LOCAL FILE RENDERING FOR RECEIPTS ---
                                              if (sale.receiptImagePath != null) ...[
                                                Text('Attached Receipt Image:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                                const SizedBox(height: 8),
                                                Center(
                                                  child: File(sale.receiptImagePath!).existsSync() 
                                                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(sale.receiptImagePath!), height: 300, fit: BoxFit.contain))
                                                    : Container(height: 300, color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)))
                                                ),
                                                const SizedBox(height: 16),
                                              ],
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: OutlinedButton.icon(
                                                  onPressed: () async {
                                                    final result = await FilePicker.pickFiles(type: FileType.image);
                                                    if (result != null && result.files.single.path != null) {
                                                      // Reverted to saving to local Document Directory
                                                      final appDir = await getApplicationDocumentsDirectory();
                                                      final receiptsDir = Directory('${appDir.path}/product_management_data/receipts');
                                                      if (!await receiptsDir.exists()) await receiptsDir.create(recursive: true);
                                                      
                                                      final ext = path.extension(result.files.single.path!);
                                                      final fileName = 'receipt_${sale.id}$ext';
                                                      final savedImage = await File(result.files.single.path!).copy('${receiptsDir.path}/$fileName');
                                                      
                                                      await provider.attachReceiptToSale(sale.id, savedImage.path);
                                                    }
                                                  },
                                                  icon: Icon(Icons.camera_alt_outlined, color: isDark ? Colors.white : Colors.blue),
                                                  label: Text(sale.receiptImagePath == null ? 'Attach Physical Receipt' : 'Update Receipt Image', style: TextStyle(color: isDark ? Colors.white : Colors.blue)),
                                                  style: OutlinedButton.styleFrom(side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.blue)),
                                                ),
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
                      ],
                    );
                  }
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            );
          }
        );
      }
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
    final allProducts = provider.getProducts();
    final products = allProducts.where((p) => p.status != 'Archived').toList();
    
    final categories = ['All', ...products.map((p) => p.category).toSet()];
    
    final displayProducts = products.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || 
                            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            p.barcode.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final fmt = NumberFormat.currency(symbol: '₱');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 1,
        title: Text('Point of Sale Terminal', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _openCustomerDisplay, 
            icon: Icon(Icons.monitor, color: isDark ? Colors.blue[300] : Colors.blue[700]), 
            label: Text('Open Customer Display', style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700]))
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () => _showAllSalesDialog(context), 
            icon: Icon(Icons.history, color: isDark ? Colors.blue[300] : Colors.blue[700]), 
            label: Text('Recent Transactions', style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700]))
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT PANEL: THE REGISTER (Cart & Checkout)
          Expanded(
            flex: 4,
            child: Container(
              color: isDark ? Colors.black : Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                    child: TextField(
                      controller: _barcodeCtrl,
                      style: TextStyle(color: textColor, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Enter Barcode here',
                        hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        prefixIcon: const Icon(Icons.qr_code_scanner, size: 28),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onSubmitted: (_) => _scanBarcode(products),
                    ),
                  ),
                  
                  if (_error != null) Padding(padding: const EdgeInsets.all(16), child: _buildAlert(_error!, Colors.red, isDark)),
                  if (_success != null) Padding(padding: const EdgeInsets.all(16), child: _buildAlert(_success!, Colors.green, isDark, isSuccess: true)),
                  
                  Expanded(
                    child: _cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 64, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('Cart is empty', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 18)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cart.length,
                          separatorBuilder: (_, __) => Divider(color: borderColor),
                          itemBuilder: (_, i) {
                            final item = _cart[i];
                            final maxStock = products.firstWhere((p) => p.id == item.productId).stock;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 3, 
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
                                      Text(fmt.format(item.price), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                                    ],
                                  )
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, color: isDark ? Colors.red[400] : Colors.red[300]),
                                      onPressed: () => _updateCartQty(i, -1, maxStock),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                    Container(
                                      width: 30,
                                      alignment: Alignment.center,
                                      child: Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add_circle_outline, color: isDark ? Colors.green[400] : Colors.green[500]),
                                      onPressed: () => _updateCartQty(i, 1, maxStock),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: Text(fmt.format(item.subtotal), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161616) : Colors.grey[50],
                      border: Border(top: BorderSide(color: borderColor, width: 2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _discountCtrl,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'Discount (%)', 
                                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                                  prefixIcon: Icon(Icons.percent, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]), 
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)), 
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                  isDense: true
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _paymentMethod,
                                dropdownColor: cardColor,
                                style: TextStyle(color: textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Payment', 
                                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)), 
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                  isDense: true
                                ),
                                items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _amountGivenCtrl,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'Amount Tendered',
                            labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            prefixText: '₱ ',
                            prefixStyle: TextStyle(color: textColor, fontSize: 24),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue[300]!, width: 2)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue[400]! : Colors.blue, width: 2)),
                            filled: true,
                            fillColor: isDark ? Colors.black : Colors.white,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),],
                        ),
                        const SizedBox(height: 16),

                        _totalRow('Subtotal', fmt.format(_subtotal), isDark),
                        if (_discountPct > 0) _totalRow('Discount', '-${fmt.format(_discountAmt)}', isDark, color: Colors.red),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: textColor)),
                            Text(fmt.format(_finalTotal), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: isDark ? Colors.blue[400] : Colors.blue[700])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('CHANGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                            Text(fmt.format(_change), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _change > 0 ? Colors.green : (isDark ? Colors.grey[400] : Colors.grey[600]))),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          height: 64,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _completeSale,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.green[700] : Colors.green[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isProcessing 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                : const Text('CHARGE / PAY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Container(width: 1, color: borderColor),

          // RIGHT PANEL: THE KIOSK (Visual Product Grid)
          Expanded(
            flex: 7,
            child: Container(
              color: bgColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search Bar
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search products by name or barcode...',
                            hintStyle: TextStyle(color: subTextColor),
                            prefixIcon: Icon(Icons.search, color: subTextColor),
                            filled: true,
                            fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Category Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : textColor)),
                                  selected: isSelected,
                                  selectedColor: isDark ? Colors.blue[700] : Colors.blue[600],
                                  backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
                                  side: BorderSide(color: isSelected ? Colors.transparent : borderColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                                  onSelected: (_) => setState(() => _selectedCategory = cat),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: displayProducts.isEmpty
                      ? Center(child: Text('No matching products found.', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 18)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: displayProducts.length,
                          itemBuilder: (context, i) {
                            final p = displayProducts[i];
                            final isOutOfStock = p.stock <= 0;
                            
                            return Card(
                              color: cardColor,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: isOutOfStock ? null : () => _addProductToCart(p, 1),
                                child: Opacity(
                                  opacity: isOutOfStock ? 0.5 : 1.0,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // --- RESTORED: Uses Local File Loading System ---
                                            p.imagePath != null && File(p.imagePath!).existsSync()
                                                ? Image.file(File(p.imagePath!), fit: BoxFit.cover)
                                                : Container(color: isDark ? Colors.grey[800] : Colors.grey[100], child: Icon(Icons.fastfood, size: 48, color: Colors.grey[400])),
                                            
                                            if (!isOutOfStock)
                                              Positioned(
                                                bottom: 8, right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                                                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              const Spacer(),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(fmt.format(p.price), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.blue[400] : Colors.blue[700])),
                                                  Text(isOutOfStock ? 'OUT' : '${p.stock} left', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isOutOfStock ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]))),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, bool isDark, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.grey[400] : Colors.grey[700]), fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? (isDark ? Colors.white : Colors.black), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAlert(String message, MaterialColor color, bool isDark, {bool isSuccess = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? color[900]!.withOpacity(0.3) : color[50], 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: isDark ? color[800]! : color[200]!)
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle : Icons.error_outline, color: isDark ? color[300] : color[700], size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: isDark ? color[200] : color[700], fontWeight: FontWeight.w600))),
          if (!isSuccess)
            IconButton(
              icon: Icon(Icons.close, size: 20, color: isDark ? color[300] : color[700]),
              onPressed: () => setState(() => _error = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
            );
          }),
        );
      },
    );
  }
}

// ============================================================================
// CUSTOMER DISPLAY APP (The UI for the Second Monitor)
// ============================================================================
class CustomerDisplayApp extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> initialData; 

  const CustomerDisplayApp({
    super.key, 
    required this.windowId, 
    required this.initialData,
  });

  @override
  State<CustomerDisplayApp> createState() => _CustomerDisplayAppState();
}

class _CustomerDisplayAppState extends State<CustomerDisplayApp> {
  List<dynamic> _customerCart = [];
  double _total = 0.0;
  double _discount = 0.0;
  double _change = 0.0;

  @override
  void initState() {
    super.initState();
    
    _customerCart = widget.initialData['cart'] ?? [];
    
    _total = (widget.initialData['total'] as num?)?.toDouble() ?? 0.0;
    _change = (widget.initialData['change'] as num?)?.toDouble() ?? 0.0;
    _discount = (widget.initialData['discount'] as num?)?.toDouble() ?? 0.0;

    DesktopMultiWindow.setMethodHandler(_handleMethodCallback);
  }

  Future<dynamic> _handleMethodCallback(MethodCall call, int fromWindowId) async {
    if (call.method == 'sync_cart') {
      final payload = jsonDecode(call.arguments.toString());
      
      setState(() {
        _customerCart = payload['cart'] ?? [];
        
        _total = (payload['total'] as num?)?.toDouble() ?? 0.0;
        _change = (payload['change'] as num?)?.toDouble() ?? 0.0;
        _discount = (payload['discount'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₱');
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.blue[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront, size: 120, color: Colors.white),
                      const SizedBox(height: 24),
                      const Text('GiYummy Store', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('Scan items to begin checkout', style: TextStyle(color: Colors.blue[200], fontSize: 24)),
                    ],
                  ),
                ),
              ),
            ),
            
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.grey[50],
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Order', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 16),
                    const Divider(thickness: 2),
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: _customerCart.isEmpty 
                        ? Center(child: Text('Awaiting items...', style: TextStyle(fontSize: 24, color: Colors.grey[400])))
                        : ListView.separated(
                            itemCount: _customerCart.length,
                            separatorBuilder: (_, __) => Divider(color: Colors.grey[300]),
                            itemBuilder: (ctx, i) {
                              final item = _customerCart[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Text('${item['quantity']}x', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                                    const SizedBox(width: 16),
                                    Expanded(child: Text(item['productName'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87))),
                                    Text(fmt.format(item['subtotal']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
                                  ],
                                ),
                              );
                            }
                          ),
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(thickness: 3, color: Colors.black12),
                    const SizedBox(height: 16),
                    
                    if (_discount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('DISCOUNT', style: TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold)),
                          Text('-${fmt.format(_discount)}', style: const TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL DUE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87)),
                        Text(fmt.format(_total), style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.blue[800])),
                      ],
                    ),
                    
                    if (_change > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CHANGE', style: TextStyle(fontSize: 20, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          Text(fmt.format(_change), style: const TextStyle(fontSize: 28, color: Colors.green, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}