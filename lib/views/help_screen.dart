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
        'definition': 'The Dashboard is the central command hub of your POS System. It aggregates real-time data from inventory, sales, and personnel modules to give you an immediate, visual understanding of your store\'s health.',
        'features': [
          {'title': 'Real-Time KPI Cards', 'detail': 'Tracks daily revenue and estimated profit against your customizable targets. Progress bars fill dynamically as sales are processed.'},
          {'title': 'Dynamic Goal Setting', 'detail': 'Click the pencil icon next to your Revenue or Profit targets to set daily goals. These are saved locally to your device and persist across reboots.'},
          {'title': 'Decision Support Alerts', 'detail': 'A specialized algorithm scans your inventory and pushes critical warnings here. It flags items that are completely out of stock or dipping below your defined reorder threshold.'},
          {'title': '7-Day Trend Analytics', 'detail': 'An interactive line chart overlays your last 7 days of gross revenue alongside estimated profit margins, allowing you to identify peak business days at a glance.'},
          {'title': 'Quick Actions & Routing', 'detail': 'Provides one-click navigation to essential workflows. The buttons displayed automatically adapt based on the role of the user currently logged in (Admin, Manager, or Employee).'}
        ]
      },
      {
        'icon': Icons.point_of_sale, 'title': 'Sales & Checkout',
        'desc': 'Complete guide to processing transactions and managing the cart.',
        'definition': 'The Point of Sale interface is the fastest way to process customer orders. It is designed for high-speed environments, allowing cashiers to scan, adjust, and finalize transactions seamlessly.',
        'features': [
          {'title': 'Barcode & Keyword Scanning', 'detail': 'Use the unified search bar to scan a physical barcode or type a keyword. Exact barcode matches instantly add the item to the cart without requiring an extra click.'},
          {'title': 'Dynamic Cart Management', 'detail': 'Use the (+) and (-) buttons inside the cart to adjust quantities. The system automatically recalculates the subtotal, taxes, and final total in real-time.'},
          {'title': 'Percentage Discounts', 'detail': 'Apply a global percentage discount to the entire order. The system calculates the exact currency amount deducted and clearly displays it on the final digital receipt.'},
          {'title': 'Payment Processing', 'detail': 'Select from Cash, Card, E-Wallet, or Other. Upon completion, the system immediately deducts the sold quantities from your live inventory database to prevent overselling.'},
          {'title': 'Digital Receipts', 'detail': 'Generates a unique 36-character transaction ID. Cashiers can view the digital receipt overlay or save it directly to the system logs for future auditing.'}
        ]
      },
      {
        'icon': Icons.inventory_2, 'title': 'Inventory Management',
        'desc': 'Managing product masters, delivery batches, and stock algorithms.',
        'definition': 'The Inventory module utilizes a dual-layer architecture. First, you create a "Product Master" (the template). Then, you receive "Batches" (deliveries) to populate the stock, allowing for accurate wholesale cost tracking and expiration management.',
        'features': [
          {'title': 'Product Master Creation', 'detail': 'Add a new product by defining its Name, Category, Retail Price, Barcode, and uploading an image. This creates the blueprint for the item in your database.'},
          {'title': 'Batch Management (Restocking)', 'detail': 'To add stock, click "Batches" on a product. Enter the quantity received, the wholesale cost per unit, the supplier, and the expiration date. The system averages these costs to calculate your actual profit margins.'},
          {'title': 'Smart Reorder Calculator', 'detail': 'When editing a product, click the calculator icon next to the Reorder Level. Input your daily demand and delivery lead time, and the system will mathematically determine your ideal reorder threshold.'},
          {'title': 'Active vs. Archived Views', 'detail': 'Discontinued products can be archived to hide them from the active sales floor. Archiving preserves all historical sales data associated with that product.'}
        ]
      },
      {
        'icon': Icons.bar_chart, 'title': 'System Reports',
        'desc': 'Visualizing sales trends and exporting data to PDF/Excel.',
        'definition': 'The Reports module is an advanced analytics engine that translates raw sales data into interactive visual charts, leaderboards, and professional documents for accounting purposes.',
        'features': [
          {'title': 'Advanced Time Filtering', 'detail': 'Instantly pivot your entire data view between Today, Last 7 Days, Last 30 Days, or All Time. All charts, totals, and tables recalculate dynamically based on the selected window.'},
          {'title': 'Top Performers & Dead Stock', 'detail': 'Identify your best-selling items via the Top Items leaderboard. Conversely, check the Dead Stock radar to find products that are taking up shelf space without generating revenue.'},
          {'title': 'Formal PDF Exporting', 'detail': 'Generate professional PDF reports instantly. Create a "Sales Sheet" for end-of-day accounting, or generate a "Purchase Order" report that lists all low-stock items for your suppliers.'},
          {'title': 'Category & Payment Mixes', 'detail': 'Interactive donut and pie charts break down exactly which departments (e.g., Noodles, Beverages) are driving your revenue and how customers prefer to pay.'}
        ]
      },
      {
        'icon': Icons.admin_panel_settings, 'title': 'User Management',
        'desc': 'Managing employee roles, auto-generated IDs, and security.',
        'definition': 'The administrative control center for managing employee access, assigning system roles, and maintaining security protocols. This module is strictly locked to Admin personnel.',
        'features': [
          {'title': 'Smart ID Generation', 'detail': 'When adding a new user, the system automatically reads their assigned role and the current date to generate a standardized Employee ID (e.g., ADMN-202606-001 or EMP-202606-005).'},
          {'title': 'Role-Based Access Control (RBAC)', 'detail': 'Assign Admin, Manager, or Employee roles. Employees are restricted to Sales and Inventory viewing. Managers can view Reports. Only Admins can modify users or export databases.'},
          {'title': 'Instant Account Deactivation', 'detail': 'Toggle the "Account Active" switch to immediately revoke a user\'s ability to log into the system. This is crucial for offboarding terminated employees securely.'},
          {'title': 'Password Overrides', 'detail': 'If an employee forgets their password, an Admin can open their profile and type a new password into the override field to instantly reset their credentials.'}
        ]
      },
      {
        'icon': Icons.build, 'title': 'System Maintenance',
        'desc': 'Creating encrypted backups and restoring offline databases.',
        'definition': 'The Maintenance module handles data security by allowing you to create physical, encrypted backup files of your entire localized database to prevent catastrophic data loss.',
        'features': [
          {'title': 'Comprehensive Data Snapshots', 'detail': 'Clicking "Create Backup" compiles all Users, Products, Batches, Sales, and Audit Logs into a single, highly compressed JSON payload saved directly to your hard drive.'},
          {'title': 'One-Click Restoration', 'detail': 'If the system crashes or you move to a new computer, simply select a previous backup file. The system will wipe the current corrupt tables and perfectly rebuild the database state.'},
          {'title': 'Audit Log Tracking', 'detail': 'Monitor the security of your system. Every login, product creation, deletion, and settings change is permanently logged here with a timestamp and the specific user who triggered the action.'}
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
      {'q': 'Can I use this POS system offline?', 'a': 'Yes! Because the system uses a localized database engine, all core functions (Sales, Inventory, Alerts, Reports) work perfectly without an internet connection. Internet is only required to send Support Tickets via this Help module.'},
      {'q': 'What is the difference between a Product and a Batch?', 'a': 'A "Product" is the master template (it holds the name, barcode, retail price, and image). A "Batch" is a physical delivery of that product. By using Batches, the system can track differing wholesale costs from different suppliers and manage distinct expiration dates for the exact same item.'},
      {'q': 'Can I use a physical USB barcode scanner?', 'a': 'Absolutely. Physical barcode scanners act exactly like high-speed keyboards. Simply click into the search bar in the Sales or Inventory module and pull the scanner trigger. The barcode will populate instantly.'},
      {'q': 'How do I process a refund or return?', 'a': 'Currently, returns must be handled administratively. A Manager or Admin must locate the transaction ID, adjust the inventory stock manually to add the returned item back, and note the refund in your daily cash ledger.'},
      {'q': 'How does the Smart Reorder Calculator work?', 'a': 'Inside the Inventory edit screen, the calculator uses standard supply-chain mathematics. It takes your Average Daily Demand (how many you sell a day) multiplied by your Lead Time (how many days the supplier takes to deliver), and adds your Safety Stock buffer to give you the perfect restock threshold.'},
      {'q': 'Why can\'t I access the Export Data or User Management screens?', 'a': 'Your account role restricts access to administrative tools. "Employees" can only conduct sales and view inventory. "Managers" can view reports. Only "Admins" have full rights to export data, alter backups, and manage personnel.'},
      {'q': 'Can I sell an item if the system says it is Out of Stock?', 'a': 'Yes. The system will flag the item with a red warning, but it currently allows the transaction to proceed in case of a physical inventory mismatch. You must resolve the negative stock by logging a restock Batch as soon as possible.'},
      {'q': 'What happens to my sales data if I Archive a product?', 'a': 'Archiving is perfectly safe. It only hides the product from the active inventory floor so cashiers can no longer sell it. All historical sales data, reports, and charts associated with that product will remain perfectly intact.'},
      {'q': 'How do I switch between Light Mode and Dark Mode?', 'a': 'Look for the Sun/Moon toggle icon in the top right corner of the Dashboard. Clicking it will instantly shift the entire application theme, which is helpful for reducing eye strain during night shifts.'},
      {'q': 'How do I restore my database if the computer crashes?', 'a': 'If you have been saving backups, simply click "Restore Backup" in the Maintenance tab on your new computer. Select your `.json` backup file, and the system will instantly decrypt and reconstruct your entire store database.'},
      {'q': 'What happens if I forget my password?', 'a': 'You must consult an Admin for a password reset. Admins have access to the User Management module and can overwrite your password with a new one without needing your old password.'},
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
              Text('Our technical support team is available during standard business hours to assist you with any system errors, database migrations, or inquiries.', style: TextStyle(color: subTextColor, height: 1.5)),
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
                    labelText: 'Describe your issue in detail...', 
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
        backgroundColor: const Color(0xFF1A1F36), // Deep navy to match reports
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