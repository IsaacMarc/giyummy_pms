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
    
    // Simulate network delay
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
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                      ),
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
                          Tab(icon: Icon(Icons.question_answer_outlined), text: 'FAQ'),
                          Tab(icon: Icon(Icons.menu_book_outlined), text: 'User Guides'),
                          Tab(icon: Icon(Icons.support_agent_outlined), text: 'Contact Support'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildFAQTab(),
                          _buildUserGuidesTab(),
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

  // --- 1. FAQ TAB ---
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

  // --- 2. USER GUIDES TAB ---
  Widget _buildUserGuidesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            childAspectRatio: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _guideCard(Icons.point_of_sale, 'Sales & Checkout', 'Learn how to scan barcodes, apply discounts, and generate receipts.'),
              _guideCard(Icons.inventory_2, 'Inventory Management', 'Manage stock levels, barcodes, and spoilage tracking.'),
              _guideCard(Icons.bar_chart, 'Dynamic Reports', 'Analyze sales trends and export data to CSV format.'),
              _guideCard(Icons.admin_panel_settings, 'Access Control', 'Manage employee roles, deactivate accounts, and reset passwords.'),
              _guideCard(Icons.build, 'System Maintenance', 'Create daily backups and restore data from hard drives.'),
              _guideCard(Icons.notifications_active, 'Alert Engine', 'Configure low-stock thresholds and monitor critical warnings.'),
            ],
          )
        ],
      ),
    );
  }

  Widget _guideCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.blue[700], size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- 3. CONTACT SUPPORT TAB ---
  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Contact Info
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
          
          // Right Side: Ticket Form
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
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Describe your issue...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
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