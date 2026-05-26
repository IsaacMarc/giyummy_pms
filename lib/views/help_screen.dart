import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_subjectCtrl.text.isEmpty || _messageCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    setState(() {
      _isSending = false;
      _subjectCtrl.clear();
      _messageCtrl.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support request sent successfully!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Top Header ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                      child: Icon(Icons.help_center, size: 40, color: Colors.blue[700]),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Help & Support', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Find answers, learn the system, or contact our technical team.', style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Tabbed Content ---
            Expanded(
              child: Card(
                elevation: 2,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: const TabBar(
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue,
                        tabs: [
                          Tab(icon: Icon(Icons.menu_book_outlined), text: 'User Guides'),
                          Tab(icon: Icon(Icons.question_answer_outlined), text: 'FAQ'),
                          Tab(icon: Icon(Icons.support_agent_outlined), text: 'Contact Support'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildUserGuidesTab(),
                          _buildFAQTab(),
                          _buildContactTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. USER GUIDES TAB (Now with all modules!) ---
  Widget _buildUserGuidesTab() {
    // Explicitly typed as List<Map<String, dynamic>> to prevent routing errors
    final List<Map<String, dynamic>> guides = [
      {
        'icon': Icons.dashboard,
        'title': 'Dashboard Overview',
        'desc': 'Your daily snapshot of business performance and critical alerts.',
        'definition': 'The Dashboard is the central hub of your POS System. It aggregates real-time data from all other modules to give you an immediate understanding of your store\'s health.',
        'features': [
          {'title': 'KPI Cards', 'detail': 'View total revenue, active users, and low stock items at a glance.'},
          {'title': 'Recent Activity', 'detail': 'Monitor a live, scrollable feed of the most recent transactions.'},
          {'title': 'Quick Alerts', 'detail': 'See immediate, color-coded warnings for expired or depleted inventory.'}
        ]
      },
      {
        'icon': Icons.point_of_sale,
        'title': 'Sales & Checkout',
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
        'icon': Icons.inventory_2,
        'title': 'Inventory Management',
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
        'icon': Icons.bar_chart,
        'title': 'System Reports',
        'desc': 'Visualizing sales trends and exporting data to Excel.',
        'definition': 'The Reports module is an advanced analytics engine that translates raw sales data into interactive visual charts and professional Excel workbooks.',
        'features': [
          {'title': 'Time Filters', 'detail': 'Use the dropdown to filter data by Today, Last 7 Days, or Last 30 Days.'},
          {'title': 'Dynamic Charts', 'detail': 'Switch between Line Charts (Sales Trend), Pie Charts (Categories), and Bar Graphs (Top Performers).'},
          {'title': 'Excel Exporting', 'detail': 'Export reports to native .xlsx files containing formatted Summary sheets and raw data tables.'}
        ]
      },
      {
        'icon': Icons.admin_panel_settings,
        'title': 'User Management',
        'desc': 'Managing employee roles and security credentials.',
        'definition': 'The administrative control center for managing employee access, assigning system roles, and maintaining security protocols.',
        'features': [
          {'title': 'Role-Based Access', 'detail': 'Assign Admin, Manager, or Employee roles. Employees have restricted, read-only access to critical modules.'},
          {'title': 'Account Status', 'detail': 'Instantly deactivate a user\'s account to revoke their system access.'},
          {'title': 'Password Control', 'detail': 'Admins can securely overwrite and reset passwords for any employee.'}
        ]
      },
      {
        'icon': Icons.notifications_active,
        'title': 'Alerts Engine',
        'desc': 'Automated notification system for critical warnings.',
        'definition': 'The Alerts Engine constantly monitors the database in the background, generating notifications to prevent stockouts and manage expired goods.',
        'features': [
          {'title': 'Low Stock Warnings', 'detail': 'Generated automatically when a product\'s inventory drops below its defined reorder level.'},
          {'title': 'Expiration Notices', 'detail': 'Generated when the Auto-Dispose scanner detects a product has passed its expiration date.'},
          {'title': 'Clear Notifications', 'detail': 'Alerts clear automatically when stock is replenished, or can be manually wiped using the "Clear All" tool.'}
        ]
      },
      {
        'icon': Icons.build,
        'title': 'System Maintenance',
        'desc': 'Creating and restoring local database backups.',
        'definition': 'The Maintenance module handles data security by allowing you to create physical backup files of your entire database to prevent data loss.',
        'features': [
          {'title': 'Create Backups', 'detail': 'Generates a secure .json file containing all users, products, sales, and logs.'},
          {'title': 'Restore Data', 'detail': 'If the system crashes, simply select a backup file from your computer to instantly rebuild the database.'}
        ]
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: guides.length,
      itemBuilder: (ctx, i) {
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: Icon(guides[i]['icon'] as IconData, color: Colors.blue[700]),
            ),
            title: Text(guides[i]['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(guides[i]['desc'] as String),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => _GuideDetailScreen(guide: guides[i]))
              );
            },
          ),
        );
      },
    );
  }

  // --- 2. FAQ TAB ---
  Widget _buildFAQTab() {
    final faqs = [
      {
        'q': 'How does the Auto-Dump feature work?',
        'a': 'When adding a product to inventory, you can set an expiration date and toggle "Auto-Dump". A background scanner checks the database every 60 seconds. Once the expiration date passes, the system will automatically set that product\'s stock to 0 and generate a critical alert.'
      },
      {
        'q': 'How do I export my data to Excel?',
        'a': 'Navigate to the Reports module. You can use the "Export Current" button to save the currently viewed chart data, or the "Export All Data" button to generate a master CSV file of every transaction. CSV files open natively in Microsoft Excel and Google Sheets.'
      },
      {
        'q': 'Why is my dashboard alert not disappearing?',
        'a': 'Alerts clear automatically when you replenish the stock of the triggering item. You can also manually dismiss them by clicking the "Read" button on the alert itself, or use the "Clear All" button in the Alerts module to wipe all notifications.'
      },
      {
        'q': 'How do I restore my database if the computer crashes?',
        'a': 'If you have been using the Maintenance module to create backups, simply click the "Restore from Computer" button in the Maintenance tab, select your saved .json backup file, and the system will instantly rebuild your entire database.'
      },
      {
        'q': 'Who is allowed to change passwords?',
        'a': 'For security reasons, only users with the "Admin" role can change passwords. Admins can do this by navigating to the User Management module, clicking the edit (pencil) icon next to an account, and entering a new password.'
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: faqs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (ctx, i) {
        return ExpansionTile(
          iconColor: Colors.blue[700],
          textColor: Colors.blue[900],
          title: Text(faqs[i]['q']!, style: const TextStyle(fontWeight: FontWeight.w600)),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(faqs[i]['a']!, style: TextStyle(color: Colors.grey[700], height: 1.5)),
              ),
            )
          ],
        );
      },
    );
  }

  // --- 3. CONTACT SUPPORT TAB ---
  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Get in Touch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Our technical support team is available during standard business hours.', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 32),
                _contactInfoRow(Icons.email_outlined, 'Email Support', 'support@pms-system.com'),
                const SizedBox(height: 20),
                _contactInfoRow(Icons.phone_outlined, 'Phone Support', '+1 (800) 555-0199'),
                const SizedBox(height: 20),
                _contactInfoRow(Icons.access_time, 'Business Hours', 'Mon-Fri, 9:00 AM - 5:00 PM'),
              ],
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Send us a Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _subjectCtrl,
                    decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Describe your issue...', border: OutlineInputBorder(), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: Text(_isSending ? 'Sending...' : 'Submit Ticket'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _contactInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[700], size: 28),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        )
      ],
    );
  }
}

// ============================================================================
// NEW: BEAUTIFUL DRILL-DOWN DETAIL SCREEN
// ============================================================================
class _GuideDetailScreen extends StatelessWidget {
  final Map<String, dynamic> guide; // Set to dynamic to handle Strings and Lists
  const _GuideDetailScreen({required this.guide});

  @override
  Widget build(BuildContext context) {
    // Extract the list of features safely
    final List<Map<String, String>> features = (guide['features'] as List<dynamic>)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Module Guide'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER BANNER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              decoration: BoxDecoration(
                color: Colors.blue[800],
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(guide['icon'] as IconData, size: 64, color: Colors.white),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(guide['title'] as String, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(guide['desc'] as String, style: TextStyle(fontSize: 16, color: Colors.blue[100])),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            // --- CONTENT BODY ---
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Definition & Overview
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Module Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            guide['definition'] as String,
                            style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 48),
                  
                  // Right Side: Step-by-Step Features
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Key Features & Workflows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: features.length,
                          itemBuilder: (ctx, i) {
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[300]!)
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.blue[100],
                                      child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(features[i]['title']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Text(features[i]['detail']!, style: TextStyle(color: Colors.grey[700], height: 1.5)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
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