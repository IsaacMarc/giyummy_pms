import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _faqSearchCtrl = TextEditingController();
  String _faqSearchQuery = '';
  bool _isSending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _faqSearchCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_subjectCtrl.text.isEmpty || _messageCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out all fields'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSending = true);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasInternet = !connectivityResult.contains(ConnectivityResult.none);

      if (!hasInternet) {
        setState(() => _isSending = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No internet connection. Please check your network.'), backgroundColor: Colors.red));
        return;
      }
    } catch (e) {
      // Fallback for desktop environments
    }

    try {
      String systemEmail = 'qimgsantos@tip.edu.ph'; 
      String appPassword = 'vjes ohev rzwj fftp'; 
      String supportInbox = 'isaacmarcussantos22@gmail.com'; 

      final smtpServer = gmail(systemEmail, appPassword);
      final message = Message()
        ..from = Address(systemEmail, 'GiYummy System Automated Ticket')
        ..recipients.add(supportInbox)
        ..subject = 'Support Ticket: ${_subjectCtrl.text}'
        ..text = '''
A new support ticket has been submitted from the POS System.

Subject: ${_subjectCtrl.text}
Time: ${DateTime.now().toString()}

Message:
${_messageCtrl.text}
''';

      await send(message, smtpServer);

      if (!mounted) return;
      
      setState(() {
        _isSending = false;
        _subjectCtrl.clear();
        _messageCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support request sent successfully!'), backgroundColor: Colors.green));
    } on MailerException catch (e) {
      print('Message not sent. \n${e.toString()}');
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message. Please try again later.'), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: DefaultTabController(
        length: 3,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP HEADER ---
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: isDark ? Colors.blue[800] : Colors.blue[600], borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.support_agent, size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Help & Support Center', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                        const SizedBox(height: 4),
                        Text('Find answers, learn the system, or contact our technical team.', style: TextStyle(fontSize: 15, color: subTextColor)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- CUSTOM PILL TAB BAR ---
                Container(
                  height: 50,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white, 
                      borderRadius: BorderRadius.circular(8), 
                      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                    ),
                    labelColor: isDark ? Colors.blue[300] : Colors.blue[800],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
                    tabs: const [
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_book, size: 18), SizedBox(width: 8), Text('User Guides')])),
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.question_answer, size: 18), SizedBox(width: 8), Text('FAQ')])),
                      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.email, size: 18), SizedBox(width: 8), Text('Contact Support')])),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- TAB VIEWS ---
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildUserGuidesTab(isDark, textColor, subTextColor),
                      _buildFAQTab(isDark, textColor, subTextColor),
                      _buildContactTab(isDark, textColor, subTextColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. USER GUIDES TAB (GRID LAYOUT) ---
  Widget _buildUserGuidesTab(bool isDark, Color textColor, Color subTextColor) {
    final List<Map<String, dynamic>> guides = [
      {
        'icon': Icons.dashboard, 'title': 'Dashboard Overview',
        'desc': 'Your daily snapshot of business performance and critical alerts.',
        'definition': 'The Dashboard is the central hub of your POS System. It aggregates real-time data from all other modules to give you an immediate understanding of your store\'s health.',
        'features': [
          {'title': 'KPI Cards', 'detail': 'View total revenue, active users, and low stock items at a glance.'},
          {'title': 'Recent Activity', 'detail': 'Monitor a live, scrollable feed of the most recent transactions.'},
          {'title': 'Quick Alerts', 'detail': 'See immediate, color-coded warnings for expired or depleted inventory.'}
        ]
      },
      {
        'icon': Icons.point_of_sale, 'title': 'Sales & Checkout',
        'desc': 'Complete guide to processing transactions and printing receipts.',
        'definition': 'The Point of Sale interface is where cashiers process customer orders, handle payments, apply discounts, and generate final receipts.',
        'features': [
          {'title': 'Search & Scan', 'detail': 'Use the barcode scanner or the smart dropdown search to instantly find items.'},
          {'title': 'Manage Cart', 'detail': 'Adjust quantities or remove items dynamically before finalizing the order.'},
          {'title': 'Apply Discounts', 'detail': 'Enter a percentage discount that automatically applies to the entire subtotal.'},
          {'title': 'Complete & Receipt', 'detail': 'Select the payment method. The system will log the sale and generate a detailed digital receipt.'}
        ]
      },
      {
        'icon': Icons.inventory_2, 'title': 'Inventory Management',
        'desc': 'Managing stock levels, reorder points, and automated alerts.',
        'definition': 'The Inventory module is the master database of all your products. It tracks current stock levels, pricing, category classifications, and expiration data.',
        'features': [
          {'title': 'Product Creation', 'detail': 'Add new products, set pricing, assign barcodes, and upload product images.'},
          {'title': 'Reorder Levels', 'detail': 'Define a minimum stock threshold. If stock falls below this number, the system triggers a warning.'},
          {'title': 'Auto-Dispose (Expiry)', 'detail': 'Assign expiration dates. The system will automatically set stock to 0 and alert you when an item expires.'},
          {'title': 'Bulk Restock', 'detail': 'Click the Bulk Restock button to view all low-stock items and update delivery quantities in one click.'}
        ]
      },
      {
        'icon': Icons.bar_chart, 'title': 'System Reports',
        'desc': 'Visualizing sales trends and exporting data to PDF/Excel.',
        'definition': 'The Reports module is an advanced analytics engine that translates raw sales data into interactive visual charts and professional documents.',
        'features': [
          {'title': 'Time Filters', 'detail': 'Use the dropdown to filter data by Today, Last 7 Days, or Last 30 Days.'},
          {'title': 'Dynamic Charts', 'detail': 'Analyze Revenue Trends, Payment Mixes, Peak Hours, and Dead Stock radars.'},
          {'title': 'PDF Exporting', 'detail': 'Export reports to native PDF files, generating formal Purchase Orders and Sales Sheets.'}
        ]
      },
      {
        'icon': Icons.admin_panel_settings, 'title': 'User Management',
        'desc': 'Managing employee roles and security credentials.',
        'definition': 'The administrative control center for managing employee access, assigning system roles, and maintaining security protocols.',
        'features': [
          {'title': 'Role-Based Access', 'detail': 'Assign Admin, Manager, or Employee roles. Employees have restricted, read-only access to critical modules.'},
          {'title': 'Account Status', 'detail': 'Instantly deactivate a user\'s account to revoke their system access.'},
          {'title': 'Password Control', 'detail': 'Admins can securely overwrite and reset passwords for any employee.'}
        ]
      },
      {
        'icon': Icons.build, 'title': 'System Maintenance',
        'desc': 'Creating and restoring encrypted database backups.',
        'definition': 'The Maintenance module handles data security by allowing you to create physical backup files of your entire database to prevent data loss.',
        'features': [
          {'title': 'Create Backups', 'detail': 'Generates a secure, encrypted file containing all users, products, sales, and logs.'},
          {'title': 'Restore Data', 'detail': 'If the system crashes, simply select a backup file from your computer to instantly rebuild the database.'}
        ]
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.6,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: guides.length,
      itemBuilder: (ctx, i) {
        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _GuideDetailScreen(guide: guides[i])));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50], 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Icon(guides[i]['icon'] as IconData, color: isDark ? Colors.blue[400] : Colors.blue[700], size: 24),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400])
                  ],
                ),
                const Spacer(),
                Text(guides[i]['title'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                const SizedBox(height: 8),
                Text(guides[i]['desc'] as String, style: TextStyle(color: subTextColor, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 2. FAQ TAB ---
  Widget _buildFAQTab(bool isDark, Color textColor, Color subTextColor) {
    final faqs = [
      {'q': 'Can I use this POS system offline?', 'a': 'Yes! Because the system uses a localized database, all core functions (Sales, Inventory, Alerts) work perfectly without an internet connection. Internet is only required to send Support Tickets.'},
      {'q': 'How do I process a refund or return?', 'a': 'Currently, returns must be handled administratively. An Admin can adjust the inventory stock manually to add the returned item back, and adjust the daily revenue records accordingly.'},
      {'q': 'How does the Auto-Dump feature work?', 'a': 'When adding a product, you can set an expiration date and toggle "Auto-Dump". A background scanner checks the database periodically. Once the date passes, the system will automatically set that product\'s stock to 0 and generate a critical alert.'},
      {'q': 'How do I update product prices?', 'a': 'Navigate to the Inventory module, click the "Edit" (pencil) icon next to the product, type the new price, and hit Save. The new price will apply immediately to all future transactions.'},
      {'q': 'How do I export my data?', 'a': 'Navigate to the Reports module. Use "Export PDF" to generate formal Purchase Orders and Sales Sheets, or "Export Excel" to generate a master .xlsx workbook for accounting.'},
      {'q': 'Why is my dashboard alert not disappearing?', 'a': 'Stock alerts clear automatically when you restock the item. You can manually dismiss them by clicking the "Read" button on the alert, or use the "Clear All" button in the Alerts module.'},
      {'q': 'How do I restore my database if the computer crashes?', 'a': 'Click "Restore Backup" in the Maintenance tab, select your saved backup file from your computer, and the system will instantly decrypt and overwrite the empty database with your saved data.'},
      {'q': 'What happens if I forget my password?', 'a': 'You must consult an Admin for a password reset. Admins have access to the User Management module and can overwrite your password with a new one.'},
    ];

    final filteredFaqs = faqs.where((faq) {
      final matchQ = faq['q']!.toLowerCase().contains(_faqSearchQuery);
      final matchA = faq['a']!.toLowerCase().contains(_faqSearchQuery);
      return matchQ || matchA;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _faqSearchCtrl,
          onChanged: (val) => setState(() => _faqSearchQuery = val.toLowerCase()),
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Search frequently asked questions...',
            hintStyle: TextStyle(color: subTextColor),
            prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[400] : Colors.blue),
            suffixIcon: _faqSearchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: subTextColor), onPressed: () { _faqSearchCtrl.clear(); setState(() => _faqSearchQuery = ''); }) : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: filteredFaqs.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 48, color: isDark ? Colors.grey[800] : Colors.grey[400]), const SizedBox(height: 16), Text('No FAQs match your search.', style: TextStyle(color: subTextColor, fontSize: 16))]))
              : ListView.builder(
                  itemCount: filteredFaqs.length,
                  itemBuilder: (ctx, i) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: _cardDecoration(isDark),
                      child: ExpansionTile(
                        shape: const Border(), // Remove default borders
                        iconColor: isDark ? Colors.blue[300] : Colors.blue[700],
                        textColor: isDark ? Colors.blue[300] : Colors.blue[900],
                        collapsedIconColor: subTextColor,
                        collapsedTextColor: textColor,
                        title: Text(filteredFaqs[i]['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(filteredFaqs[i]['a']!, style: TextStyle(color: subTextColor, height: 1.5, fontSize: 14)),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- 3. CONTACT SUPPORT TAB ---
  Widget _buildContactTab(bool isDark, Color textColor, Color subTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Get in Touch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text('Our technical support team is available during standard business hours to assist you with any system errors or inquiries.', style: TextStyle(color: subTextColor, height: 1.5)),
              const SizedBox(height: 40),
              _contactInfoRow(Icons.email_outlined, 'Email Support', 'support@pms-system.com', isDark, textColor, subTextColor),
              const SizedBox(height: 24),
              _contactInfoRow(Icons.phone_outlined, 'Phone Support', '+1 (800) 555-0199', isDark, textColor, subTextColor),
              const SizedBox(height: 24),
              _contactInfoRow(Icons.access_time, 'Business Hours', 'Mon-Fri, 9:00 AM - 5:00 PM', isDark, textColor, subTextColor),
            ],
          ),
        ),
        const SizedBox(width: 64),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: _cardDecoration(isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Send us a Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 24),
                TextField(
                  controller: _subjectCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Subject', 
                    labelStyle: TextStyle(color: subTextColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)), 
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)),
                    isDense: true
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 6,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Describe your issue...', 
                    labelStyle: TextStyle(color: subTextColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)), 
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!)),
                    alignLabelWithHint: true
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                    label: Text(_isSending ? 'Sending...' : 'Submit Support Ticket', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _contactInfoRow(IconData icon, String title, String value, bool isDark, Color textColor, Color subTextColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50], borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: isDark ? Colors.blue[400] : Colors.blue[700], size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
          ],
        )
      ],
    );
  }
}

// ============================================================================
// BEAUTIFUL DRILL-DOWN DETAIL SCREEN
// ============================================================================
class _GuideDetailScreen extends StatelessWidget {
  final Map<String, dynamic> guide; 
  const _GuideDetailScreen({required this.guide});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    final List<Map<String, String>> features = (guide['features'] as List<dynamic>).map((e) => Map<String, String>.from(e as Map)).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Module Documentation', style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF1A1F36), // Deep navy to match reports (Looks good in light/dark)
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HERO BANNER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F36), // Keeping the hero banner deep navy
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
                    child: Icon(guide['icon'] as IconData, size: 64, color: Colors.white),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(guide['title'] as String, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 12),
                        Text(guide['desc'] as String, style: TextStyle(fontSize: 18, color: Colors.blue[100])),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            // --- CONTENT BODY ---
            Padding(
              padding: const EdgeInsets.all(48.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Definition & Overview
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Module Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: cardColor, 
                            borderRadius: BorderRadius.circular(16), 
                            border: Border.all(color: borderColor), 
                            boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                          ),
                          child: Text(
                            guide['definition'] as String,
                            style: TextStyle(fontSize: 15, height: 1.8, color: subTextColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 48),
                  
                  // Right Side: Step-by-Step Features
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Key Features & Workflows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: features.length,
                          itemBuilder: (ctx, i) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(24.0),
                              decoration: BoxDecoration(
                                color: cardColor, 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(color: borderColor), 
                                boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50],
                                    child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(features[i]['title']!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                        const SizedBox(height: 8),
                                        Text(features[i]['detail']!, style: TextStyle(color: subTextColor, height: 1.5)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}