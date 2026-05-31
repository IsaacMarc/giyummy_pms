import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[200]!),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. HERO / ABOUT THE SYSTEM ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F36), // Deep navy matching your system headers
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.storefront, size: 64, color: Colors.white),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(20)),
                            child: const Text('VERSION 1.0.0', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                          const SizedBox(height: 16),
                          const Text('Advanced POS & Inventory Management', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 12),
                          Text(
                            'A comprehensive, offline-first retail solution engineered to streamline checkout operations, track real-time stock health, mitigate spoilage risks, and generate actionable business analytics.',
                            style: TextStyle(fontSize: 16, color: Colors.blue[50], height: 1.5),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // --- 2. SYSTEM FEATURES ---
              const Text('System Features', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
              const SizedBox(height: 8),
              Text('Core capabilities driving operational efficiency.', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.4, // Adjusted slightly to ensure 3-line text fits perfectly
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                children: [
                  _buildFeatureCard(Icons.point_of_sale, 'Smart POS Checkout', 'Barcode scanning, dynamic cart management, and automated receipt generation.', Colors.blue),
                  _buildFeatureCard(Icons.inventory_2, 'Batch & FIFO Inventory', 'Track exact wholesale costs and expiration dates across multiple product batches.', Colors.green),
                  _buildFeatureCard(Icons.auto_delete, 'Auto-Dump Engine', 'Automated system scanners that detect and isolate expired goods to prevent accidental sale.', Colors.red),
                  _buildFeatureCard(Icons.radar, 'Dead Stock Radar', 'Analytics tool to identify non-moving inventory and optimize shelf space.', Colors.purple),
                  _buildFeatureCard(Icons.request_quote, 'Automated POs', 'One-click generation of printable Purchase Orders for low-stock supplier restocks.', Colors.orange),
                  _buildFeatureCard(Icons.admin_panel_settings, 'Secure RBAC', 'Strict Role-Based Access Control ensuring secure employee and admin data boundaries.', Colors.teal),
                  _buildFeatureCard(Icons.analytics, 'Data Export & Analytics', 'Generate comprehensive Excel workbooks and professional PDF reports for accounting.', Colors.indigo),
                  _buildFeatureCard(Icons.wifi_off, 'Offline Architecture', 'Fully functional without internet connectivity using a localized high-speed database.', Colors.blueGrey),
                  _buildFeatureCard(Icons.settings_backup_restore, 'Encrypted Backups', 'Create secure, point-in-time system backups and restore operations to prevent data loss.', Colors.brown),
                ],
              ),
              const SizedBox(height: 48),

              // --- 3. DEVELOPMENT TEAM & TECH STACK ROW ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TEAM
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Development Team', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
                        const SizedBox(height: 8),
                        Text('Technological Institute of the Philippines - Quezon City', style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: _cardDecoration(),
                          child: Column(
                            children: [
                              _buildTeamMember('Isaac Marcus Santos', 'Lead Developer / Security & UI Architecture', Icons.code),
                              const Divider(height: 32),
                              _buildTeamMember('Jannalyn Cruz', 'Systems Analyst & Quality Assurance', Icons.schema),
                              const Divider(height: 32),
                              _buildTeamMember('Klent Charlo Obsioma', 'Backend Developer & Database Engineer', Icons.storage),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),

                  // TECH STACK
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tech Stack', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1F36))),
                        const SizedBox(height: 8),
                        Text('Libraries and frameworks powering the system.', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: _cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStackCategory('Core Framework', [
                                _buildChip('Flutter', Colors.blue),
                                _buildChip('Dart', Colors.lightBlue),
                              ]),
                              const SizedBox(height: 24),
                              _buildStackCategory('State & Architecture', [
                                _buildChip('Provider', Colors.purple),
                              ]),
                              const SizedBox(height: 24),
                              _buildStackCategory('Local Database & File System', [
                                _buildChip('SQLite (sqflite)', Colors.green),
                                _buildChip('path_provider', Colors.teal),
                              ]),
                              const SizedBox(height: 24),
                              _buildStackCategory('Analytics & Reporting', [
                                _buildChip('fl_chart', Colors.orange),
                                _buildChip('pdf', Colors.red),
                                _buildChip('printing', Colors.redAccent),
                                _buildChip('excel', Colors.green[700]!),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 48),
              
              // Footer
              Center(
                child: Text('Built with secure coding practices and risk assessment protocols.\n© ${DateTime.now().year} All Rights Reserved.', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildFeatureCard(IconData icon, String title, String desc, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color[50], borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color[700], size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTeamMember(String name, String role, IconData icon) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[100],
          child: Icon(icon, color: Colors.grey[700]),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text(role, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        )
      ],
    );
  }

  Widget _buildStackCategory(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}