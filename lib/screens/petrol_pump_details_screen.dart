import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/map_location.dart';

class PetrolPumpDetailsScreen extends StatelessWidget {
  final MapLocation location;

  const PetrolPumpDetailsScreen({
    Key? key,
    required this.location,
  }) : super(key: key);

  Future<void> _launchMaps() async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _launchPhone() async {
    final url = 'tel:${location.contactDetails}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _sharePetrolPumpDetails() {
    final shareText = '''
🚗 Petrol Pump Details

📍 ${location.customerName}
🆔 SAP Code: ${location.sapCode}
🏢 Company: ${location.company}

📍 Location Details:
• Zone: ${location.zone}
• Sales Area: ${location.salesArea}
• CO/CL/DO: ${location.coClDo}
• District: ${location.district}
• Location: ${location.location}

📞 Contact Information:
• Dealer: ${location.dealerName}
• Phone: ${location.contactDetails}

📍 Address:
${location.addressLine1}
${location.addressLine2.isNotEmpty ? location.addressLine2 : ''}
Pincode: ${location.pincode}

🗺️ Coordinates: ${location.latitude}, ${location.longitude}

📍 Get Directions: https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}
''';

    Share.share(shareText, subject: 'Petrol Pump Details - ${location.customerName}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.customerName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'SAP Code: ${location.sapCode}',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // Share Button
          IconButton(
            onPressed: _sharePetrolPumpDetails,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF35C2C1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.share,
                color: Color(0xFF35C2C1),
                size: 20,
              ),
            ),
          ),
          // Company Logo
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: _getCompanyLogo(location.company),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Card
              _buildSection(
                title: 'Location Details',
                icon: Icons.location_on,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Company', location.company),
                    _buildInfoRow('Zone', location.zone),
                    _buildInfoRow('Sales Area', location.salesArea),
                    _buildInfoRow('CO/CL/DO', location.coClDo),
                    _buildInfoRow('District', location.district),
                    _buildInfoRow('Location', location.location),
                    _buildInfoRow('Coordinates', '${location.latitude}, ${location.longitude}'),
                    const SizedBox(height: 16),
                    _buildAddressSection(),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Contact Card
              _buildSection(
                title: 'Contact Information',
                icon: Icons.contact_phone,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Dealer Name', location.dealerName),
                    _buildInfoRow('Contact', location.contactDetails),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _launchPhone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF35C2C1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.phone),
                            label: const Text('Call'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _launchMaps,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF35C2C1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.map),
                            label: const Text('Directions'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final pumpImagePath = _getCompanyPumpImage(location.company);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Faded background image for Location Details section
          if (title == 'Location Details' && pumpImagePath != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Opacity(
                  opacity: 0.2, // Very light opacity
                  child: Image.asset(
                    pumpImagePath,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF35C2C1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF35C2C1),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final displayValue = (value.trim().isEmpty) ? 'N/A' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Address',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (location.addressLine1.trim().isEmpty) ? 'N/A' : location.addressLine1,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                ),
              ),
              if (location.addressLine2.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  (location.addressLine2.trim().isEmpty) ? 'N/A' : location.addressLine2,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Pincode: ' + (location.pincode.trim().isEmpty ? 'N/A' : location.pincode),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _getCompanyPumpImage(String company) {
    switch (company.toUpperCase()) {
      case 'BPCL':
        return 'assets/images/BPCL_pump.jpg';
      case 'HPCL':
        return 'assets/images/HPCL_pump.jpg';
      case 'IOCL':
        return 'assets/images/IOCL_pump.jpg';
      default:
        return null;
    }
  }

  Widget _getCompanyLogo(String company) {
    switch (company.toUpperCase()) {
      case 'BPCL':
        return Image.asset(
          'assets/images/BPCL_logo.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        );
      case 'HPCL':
        return Image.asset(
          'assets/images/HPCL_logo.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        );
      case 'IOCL':
        return Image.asset(
          'assets/images/IOCL_logo.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        );
      default:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.local_gas_station,
            color: Colors.grey,
            size: 16,
          ),
        );
    }
  }
} 