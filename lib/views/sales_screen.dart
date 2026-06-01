import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:barcode_widget/barcode_widget.dart';

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
  final _amountGivenCtrl = TextEditingController(); 
  
  String _paymentMethod = 'Cash';
  String? _selectedProductId;
  String? _error;
  String? _success;
  
  bool _isProcessing = false; 

  static const _paymentMethods = ['Cash', 'Card', 'Mobile Payment'];

  @override
  void initState() {
    super.initState();
    _amountGivenCtrl.addListener(() => setState(() {}));
    _discountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _discountCtrl.dispose();
    _qtyCtrl.dispose(); 
    _amountGivenCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.subtotal);
  double get _discountPct => double.tryParse(_discountCtrl.text) ?? 0;
  double get _discountAmt => _subtotal * _discountPct / 100;
  double get _finalTotal => _subtotal - _discountAmt;
  double get _amountGiven => double.tryParse(_amountGivenCtrl.text) ?? 0.0;
  double get _change => (_amountGiven - _finalTotal) > 0 ? (_amountGiven - _finalTotal) : 0.0;

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
    final err = await provider.addSale(
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

    final allSales = provider.getSales();
    final newSale = allSales.last; 
    final txnId = newSale.id.substring(0, 12).toUpperCase(); 
    
    setState(() {
      _cart.clear();
      _discountCtrl.text = '0';
      _amountGivenCtrl.clear();
      _barcodeCtrl.clear();
      _qtyCtrl.text = '1';
      _success = 'Sale completed successfully!';
    });

    _showReceiptDialog(context, receiptItems, receiptSubtotal, receiptDiscount, receiptTotal, receiptPayment, receiptGiven, receiptChange, txnId, newSale.cashierName);
  }

  void _showReceiptDialog(BuildContext context, List<SaleItem> items, double subtotal, double discountAmt, double finalTotal, String paymentMethod, double given, double change, String txnId, String cashierName) {
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
                    const Center(child: Text('            GIYUMMY\nKOREAN SUPERMARKET', style: TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))),
                    const SizedBox(height: 8),
                    const Text('1972 Pedro Gil St, Santa Ana, Manila\n1009 Metro Manila\nTel.: +0908 888 6756', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                    const SizedBox(height: 16),
                    const _DashedLine(),
                    const SizedBox(height: 12),
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
                                  final time = sale.timestamp.length >= 16 
                                      ? sale.timestamp.substring(0, 16).replaceAll('T', ' ') 
                                      : sale.timestamp;
                                  
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
                                              // --- NEW: SIMPLIFIED THERMAL RECEIPT VIEW ---
                                              Container(
                                                padding: const EdgeInsets.all(24),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey[300]!),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    const Center(child: Text('GIYUMMY KOREAN SUPERMARKET', style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))),
                                                    const SizedBox(height: 8),
                                                    const Center(child: Text('1972 Pedro Gil St, Santa Ana, Manila\n1009 Metro Manila\nTel.: +0908 888 6756', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                    const SizedBox(height: 12),
                                                    const _DashedLine(),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text('Cashier: ${sale.cashierName}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                                                        const Text('Manager: Admin', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Align(alignment: Alignment.centerLeft, child: Text('Date: $time', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                    const SizedBox(height: 8),
                                                    const _DashedLine(),
                                                    const SizedBox(height: 8),
                                                    const Row(
                                                      children: [
                                                        Expanded(flex: 3, child: Text('Name', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                        Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                        Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    ...sale.items.map((i) => Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                                      child: Row(
                                                        children: [
                                                          Expanded(flex: 3, child: Text(i.productName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                          Expanded(flex: 1, child: Text('${i.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                          Expanded(flex: 2, child: Text(fmt.format(i.subtotal), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black))),
                                                        ],
                                                      ),
                                                    )),
                                                    const SizedBox(height: 8),
                                                    const _DashedLine(),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        const Text('Sub Total', style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                                                        Text(fmt.format(sale.finalTotal + sale.discount), style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    if (sale.discount > 0) ...[
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          const Text('DISCOUNT', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                                                          Text('-${fmt.format(sale.discount)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                    ],
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(sale.paymentMethod.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                                                        Text(fmt.format(sale.finalTotal), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),
                                                    BarcodeWidget(
                                                      barcode: Barcode.code128(),
                                                      data: refId,
                                                      width: double.infinity,
                                                      height: 40,
                                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    const Text('THANK YOU!\nGlad to see you again!', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              
                                              if (sale.receiptImagePath != null) ...[
                                                Text('Attached Receipt Image:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                                const SizedBox(height: 8),
                                                Center(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.file(
                                                      File(sale.receiptImagePath!),
                                                      height: 300,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                              ],
                                              
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: OutlinedButton.icon(
                                                  onPressed: () async {
                                                      final result = await FilePicker.pickFiles(type: FileType.image);
                                                    if (result != null && result.files.single.path != null) {
                                                      final appDir = await getApplicationDocumentsDirectory();
                                                      final receiptsDir = Directory('${appDir.path}/receipts');
                                                      if (!await receiptsDir.exists()) {
                                                        await receiptsDir.create(recursive: true);
                                                      }
                                                      
                                                      final ext = path.extension(result.files.single.path!);
                                                      final fileName = 'receipt_${sale.id}$ext';
                                                      final savedImage = await File(result.files.single.path!).copy('${receiptsDir.path}/$fileName');
                                                      
                                                      await provider.attachReceiptToSale(sale.id, savedImage.path);
                                                    }
                                                  },
                                                  icon: Icon(Icons.camera_alt_outlined, color: isDark ? Colors.white : Colors.blue),
                                                  label: Text(sale.receiptImagePath == null ? 'Attach Physical Receipt' : 'Update Receipt Image', style: TextStyle(color: isDark ? Colors.white : Colors.blue)),
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.blue)
                                                  ),
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
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
              ],
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
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    final provider = context.watch<AppProvider>();
    final products = provider.getProducts();
    final allSales = provider.getSales(); 
    final inStockProducts = products.where((p) => p.stock > 0).toList();
    final fmt = NumberFormat.currency(symbol: '₱');

    if (_selectedProductId != null && !inStockProducts.any((p) => p.id == _selectedProductId)) {
      _selectedProductId = null;
    }
    
    _selectedProductId ??= inStockProducts.isNotEmpty ? inStockProducts.first.id : null;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LEFT PANEL: CART & PRODUCT SELECTION (Flex 5) ---
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) _buildAlert(_error!, Colors.red, isDark),
                    if (_success != null) _buildAlert(_success!, Colors.green, isDark, isSuccess: true),
                    
                    // 1. Search & Add Bar
                    Card(
                      color: cardColor,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scan & Add Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _barcodeCtrl,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: 'Scan Barcode',
                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                      prefixIcon: Icon(Icons.qr_code_scanner, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                      isDense: true,
                                      filled: true,
                                      fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
                                    ),
                                    onSubmitted: (_) => _scanBarcode(products),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return DropdownMenu<String>(
                                        width: constraints.maxWidth,
                                        enableFilter: true,
                                        requestFocusOnTap: true,
                                        textStyle: TextStyle(color: textColor),
                                        leadingIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                        label: Text('Search Products manually...', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                        inputDecorationTheme: InputDecorationTheme(
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                        ),
                                        initialSelection: _selectedProductId,
                                        dropdownMenuEntries: inStockProducts.map((p) {
                                          return DropdownMenuEntry<String>(
                                            value: p.id,
                                            label: '${p.name} (Stock: ${p.stock}) - ${fmt.format(p.price)}',
                                          );
                                        }).toList(),
                                        onSelected: (v) => setState(() => _selectedProductId = v),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: _qtyCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: textColor),
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: InputDecoration(
                                      labelText: 'Qty',
                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                      isDense: true,
                                      filled: true,
                                      fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () => _addToCart(products),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    backgroundColor: Colors.blue[800],
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 2. Beautiful Cart Table
                    Expanded(
                      child: Card(
                        color: cardColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey))),
                                  Expanded(flex: 1, child: Text('PRICE', style:  TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey))),
                                  Expanded(flex: 2, child: Center(child: Text('QTY', style:  TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey)))),
                                  Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('TOTAL', style:  TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey)))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _cart.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.shopping_cart_outlined, size: 64, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                                          const SizedBox(height: 16),
                                          Text('Cart is empty', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500], fontSize: 18)),
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
                                          children: [
                                            Expanded(flex: 3, child: Text(item.productName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor))),
                                            Expanded(flex: 1, child: Text(fmt.format(item.price), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]))),
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.remove_circle, color: isDark ? Colors.red[400] : Colors.red[300]),
                                                    onPressed: () => _updateCartQty(i, -1, maxStock),
                                                  ),
                                                  Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                                  IconButton(
                                                    icon: Icon(Icons.add_circle, color: isDark ? Colors.green[400] : Colors.green[400]),
                                                    onPressed: () => _updateCartQty(i, 1, maxStock),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1, 
                                              child: Align(
                                                alignment: Alignment.centerRight, 
                                                child: Text(fmt.format(item.subtotal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))
                                              )
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              
              // --- RIGHT PANEL: PAYMENT & RECENT SALES (Flex 3) ---
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Payment Terminal Card
                    Card(
                      color: cardColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                            const SizedBox(height: 24),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _discountCtrl,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: 'Discount (%)', 
                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                      prefixIcon: Icon(Icons.percent, color: isDark ? Colors.grey[400] : Colors.grey[600]), 
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
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: 'Payment Method', 
                                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
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
                            const SizedBox(height: 24),
                            
                            // Amount Given Field
                            TextField(
                              controller: _amountGivenCtrl,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Amount Given by Customer',
                                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                prefixText: '₱ ',
                                prefixStyle: TextStyle(color: textColor, fontSize: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0D47A1).withOpacity(0.3) : Colors.blue[50], // Dark mode blue tint
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                            
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  _totalRow('Subtotal', fmt.format(_subtotal), isDark),
                                  if (_discountPct > 0) _totalRow('Discount (${_discountPct.toStringAsFixed(0)}%)', '-${fmt.format(_discountAmt)}', isDark, color: isDark ? Colors.red[400] : Colors.red[700]),
                                  Divider(height: 24, color: borderColor),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total Due', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: textColor)),
                                      Text(fmt.format(_finalTotal), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: isDark ? Colors.blue[400] : Colors.blue[900])),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Change Display
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                      Text(fmt.format(_change), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _change > 0 ? (isDark ? Colors.green[400] : Colors.green[700]) : (isDark ? Colors.grey[400] : Colors.grey[700]))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _completeSale,
                                icon: _isProcessing 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) 
                                    : const Icon(Icons.point_of_sale, size: 28),
                                label: Text(_isProcessing ? 'Processing...' : 'Finish Transaction', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.green[700] : Colors.green[600],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 2. Recent Sales Stream
                    Expanded(
                      child: Card(
                        color: cardColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Recent Sales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                  TextButton(
                                    onPressed: () => _showAllSalesDialog(context),
                                    child: const Text('View All'),
                                  )
                                ],
                              ),
                              Divider(color: borderColor),
                              Expanded(
                                child: allSales.isEmpty
                                    ? Center(child: Text('No sales today.', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500])))
                                    : ListView.builder(
                                        itemCount: allSales.length > 5 ? 5 : allSales.length,
                                        itemBuilder: (ctx, i) {
                                          final s = allSales.reversed.toList()[i];
                                          final time = s.timestamp.length >= 16 ? s.timestamp.substring(11, 16) : '';
                                          final refId = s.id.substring(0, 12).toUpperCase();
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(color: isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50], shape: BoxShape.circle),
                                                  child: Icon(Icons.receipt_long, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 20),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('REF: $refId', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor)),
                                                      Text('${s.cashierName} • $time', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                                Text(fmt.format(s.finalTotal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.green[400] : Colors.green)),
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
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, bool isDark, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.grey[400] : Colors.grey[700]), fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? (isDark ? Colors.white : Colors.black), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildAlert(String message, MaterialColor color, bool isDark, {bool isSuccess = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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