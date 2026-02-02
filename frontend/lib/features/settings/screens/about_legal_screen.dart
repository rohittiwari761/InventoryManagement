import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutLegalScreen extends StatelessWidget {
  const AboutLegalScreen({Key? key}) : super(key: key);

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About & Legal Information'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Information
            _buildSection(
              title: 'Inventory Management System',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A comprehensive inventory and invoice management solution for businesses.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // NON-OFFICIAL STATUS DISCLAIMER (Required by Google)
            _buildSection(
              title: '⚠️ Important Disclaimer',
              titleColor: Colors.red[700],
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THIS IS NOT A GOVERNMENT APPLICATION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This application is a private commercial product and is NOT affiliated with, endorsed by, or connected to any government entity, department, or organization in India or any other country.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[900],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This app is independently developed and operated for business inventory and invoice management purposes only.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[900],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 32),

            // GOVERNMENT DATA SOURCE ATTRIBUTION (Required by Google)
            _buildSection(
              title: 'Government Data Sources & Attribution',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This application uses the following government data sources:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pincode Data Attribution
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Indian Postal Code Data',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'PIN code, city, and state information is sourced from:',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),

                        // India Post Link
                        InkWell(
                          onTap: () => _launchURL('https://www.indiapost.gov.in'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.language, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'India Post - Department of Posts',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      Text(
                                        'https://www.indiapost.gov.in',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.open_in_new, size: 16, color: Colors.blue[700]),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Data.gov.in Link
                        InkWell(
                          onTap: () => _launchURL('https://data.gov.in'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.language, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Open Government Data (OGD) Platform India',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      Text(
                                        'https://data.gov.in',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.open_in_new, size: 16, color: Colors.blue[700]),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'The postal code data is used solely for address auto-completion and convenience purposes. This app does not claim ownership of this data.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // GST Information
            _buildSection(
              title: 'GST & Tax Information',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This app helps businesses create GST-compliant invoices according to Indian tax regulations. Tax calculations are performed within the app and should be verified by qualified tax professionals.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _launchURL('https://www.gst.gov.in'),
                    child: Text(
                      'Official GST Portal: https://www.gst.gov.in',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // Legal & Privacy
            _buildSection(
              title: 'Legal & Privacy',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLinkTile(
                    icon: Icons.privacy_tip,
                    title: 'Privacy Policy',
                    onTap: () => _launchURL('https://sites.google.com/d/1LxxeHlQ_29kzh6VoXKlAqQwTyf6KvT17/p/13R8S6c_0GB7Rxps-l3Eu8sv1GqlAy53L/edit'),
                  ),
                  const SizedBox(height: 8),
                  _buildLinkTile(
                    icon: Icons.description,
                    title: 'Terms of Service',
                    onTap: () {
                      // TODO: Add terms of service URL when available
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Terms of Service will be available soon')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // Contact Information
            _buildSection(
              title: 'Contact & Support',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      const Text(
                        'tiwari.rohit761@gmail.com',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'For questions, support, or feedback, please contact us at the email above.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Copyright
            Center(
              child: Text(
                '© 2024 Inventory Management System\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Color? titleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor ?? Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
