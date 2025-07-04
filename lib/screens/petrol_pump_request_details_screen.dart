import 'package:flutter/material.dart';
import '../models/petrol_pump_request.dart';
import '../widgets/app_drawer.dart';

class PetrolPumpRequestDetailsScreen extends StatelessWidget {
  final PetrolPumpRequest request;

  const PetrolPumpRequestDetailsScreen({
    Key? key,
    required this.request,
  }) : super(key: key);

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'verified':
        return 'Verified';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'verified':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'verified':
        return Icons.verified;
      default:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const AppDrawer(currentScreen: 'requests'),
      appBar: AppBar(
        title: const Text(
          'Request Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(request.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(request.status),
                        color: _getStatusColor(request.status),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getStatusText(request.status),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(request.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Rejection Reason (if rejected)
            if (request.status.toLowerCase() == 'rejected' && request.rejectionReason != null && request.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Rejection Reason',
                icon: Icons.cancel,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel,
                          size: 20,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            request.rejectionReason!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Petrol Pump Details
            _buildSectionCard(
              title: 'Petrol Pump Details',
              icon: Icons.local_gas_station,
              children: [
                _buildInfoRow('Petrol Pump Name', request.customerName),
                _buildInfoRow('Company', request.company),
                _buildInfoRow('SAP Code', request.sapCode ?? 'Not provided'),
                _buildInfoRow('Dealer Name', request.dealerName),
                _buildInfoRow('Contact Number', request.contactDetails),
              ],
            ),
            const SizedBox(height: 16),

            // Location Details
            _buildSectionCard(
              title: 'Location Details',
              icon: Icons.location_on,
              children: [
                _buildInfoRow('Address Line 1', request.addressLine1),
                if (request.addressLine2.isNotEmpty)
                  _buildInfoRow('Address Line 2', request.addressLine2),
                _buildInfoRow('District', request.district),
                _buildInfoRow('Zone', request.zone),
                _buildInfoRow('Sales Area', request.salesArea),
                _buildInfoRow('Regional Office', request.regionalOffice),
                _buildInfoRow('CO/CL/DO', request.coClDo),
                _buildInfoRow('Coordinates', '${request.latitude}, ${request.longitude}'),
              ],
            ),
            const SizedBox(height: 16),

            // Request Information
            _buildSectionCard(
              title: 'Request Information',
              icon: Icons.info,
              children: [
                _buildInfoRow('Request ID', request.id),
                _buildInfoRow('Submitted On', _formatDate(request.createdAt)),
                if (request.updatedAt != null)
                  _buildInfoRow('Last Updated', _formatDate(request.updatedAt!)),
                _buildInfoRow('Submitted By', request.requestedByUserId ?? 'Unknown'),
              ],
            ),

            // Admin Feedback (if available)
            if (request.adminFeedback != null && request.adminFeedback!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Admin Feedback',
                icon: Icons.feedback,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.feedback,
                          size: 20,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            request.adminFeedback!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF35C2C1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF35C2C1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 