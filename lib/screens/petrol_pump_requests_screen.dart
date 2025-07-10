import 'package:flutter/material.dart';
import '../models/petrol_pump_request.dart';
import '../services/petrol_pump_request_service.dart';
import '../services/custom_auth_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_navigation_bar_widget.dart';
import 'petrol_pump_request_details_screen.dart';

class PetrolPumpRequestsScreen extends StatefulWidget {
  const PetrolPumpRequestsScreen({Key? key}) : super(key: key);

  @override
  State<PetrolPumpRequestsScreen> createState() => _PetrolPumpRequestsScreenState();
}

class _PetrolPumpRequestsScreenState extends State<PetrolPumpRequestsScreen> {
  final PetrolPumpRequestService _requestService = PetrolPumpRequestService();
  final CustomAuthService _authService = CustomAuthService();
  
  List<PetrolPumpRequest> _requests = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadUserRequests();
  }

  Future<void> _loadUserRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final userId = await _authService.getCurrentUserId();
      print('DEBUG: Current user ID: $userId');
      
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      print('DEBUG: Fetching requests for user: $userId');
      final requests = await _requestService.getUserRequests(userId);
      print('DEBUG: Found ${requests.length} requests');
      
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG: Error in _loadUserRequests: $e');
      setState(() {
        _error = 'Error loading requests: $e';
        _isLoading = false;
      });
    }
  }

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

  // Test function to add a sample request
  Future<void> _addTestRequest() async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      // Create a test request
      final testRequest = PetrolPumpRequest(
        zone: 'Test Zone',
        salesArea: 'Test Sales Area',
        coClDo: 'Test CO/CL/DO',
        district: 'Test District',
        sapCode: '123456',
        customerName: 'Test Petrol Pump',
        location: 'Test Location',
        addressLine1: 'Test Address Line 1',
        addressLine2: 'Test Address Line 2',
        pincode: '123456',
        dealerName: 'Test Dealer',
        contactDetails: '9876543210',
        latitude: 28.6139,
        longitude: 77.2090,
        status: 'pending',
        createdAt: DateTime.now(),
        id: '', // Will be set by Firestore
        regionalOffice: 'Test Regional Office',
        company: 'HPCL',
      );

      final requestId = await _requestService.addPetrolPumpRequest(testRequest, userId: userId);
      print('DEBUG: Test request added with ID: $requestId');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test request added successfully! ID: $requestId')),
      );
      
      // Reload the requests
      _loadUserRequests();
    } catch (e) {
      print('DEBUG: Error adding test request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding test request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const AppDrawer(currentScreen: 'requests'),
      appBar: AppBar(
        title: const Text(
          'My Petrol Pump Requests',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserRequests,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTestRequest,
            tooltip: 'Add Test Request',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF35C2C1)),
              ),
            )
          : Column(
              children: [
                // Processing time information banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF35C2C1).withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF35C2C1).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: const Color(0xFF35C2C1),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your request will be processed within 24 hours during business days.',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF35C2C1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main content
                Expanded(
                  child: _error.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadUserRequests,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF35C2C1),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _requests.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No requests found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You haven\'t submitted any petrol pump requests yet.',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadUserRequests,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _requests.length,
                                itemBuilder: (context, index) {
                                  final request = _requests[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PetrolPumpRequestDetailsScreen(
                                              request: request,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        request.customerName,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        request.addressLine1,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey[600],
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(request.status).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: _getStatusColor(request.status),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        _getStatusIcon(request.status),
                                                        size: 16,
                                                        color: _getStatusColor(request.status),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _getStatusText(request.status),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: _getStatusColor(request.status),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.local_gas_station,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  request.company,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatDate(request.createdAt),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (request.adminFeedback != null && request.adminFeedback!.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.all(8),
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
                                                      size: 16,
                                                      color: Colors.orange[700],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        request.adminFeedback!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.orange[700],
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
      // bottomNavigationBar: CustomBottomNavigationBar(
      //   currentIndex: 0, // Home index
      //   onTap: (index) {
      //     switch (index) {
      //       case 0: // Home
      //         Navigator.pushReplacementNamed(context, '/home');
      //         break;
      //       case 1: // Map
      //         Navigator.pushReplacementNamed(context, '/map');
      //         break;
      //       case 3: // Search
      //         Navigator.pushReplacementNamed(context, '/search');
      //         break;
      //       case 4: // Profile
      //         Navigator.pushReplacementNamed(context, '/profile');
      //         break;
      //     }
      //   },
      //   showFloatingActionButton: false,
      // ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 