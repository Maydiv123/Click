import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/map_location.dart';
import '../services/map_service.dart';
import '../services/database_service.dart';
import '../services/custom_auth_service.dart';
import '../widgets/bottom_navigation_bar_widget.dart';
import 'petrol_pump_details_screen.dart';
import 'search_petrol_pumps_screen.dart';
import 'camera_screen.dart';
import 'image_review_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'camera_selection_screen.dart';
import 'openstreet_map_screen.dart';
// import '../widgets/custom_bottom_navigation_bar.dart';

class NearestPetrolPumpsScreen extends StatefulWidget {
  const NearestPetrolPumpsScreen({Key? key}) : super(key: key);

  @override
  State<NearestPetrolPumpsScreen> createState() => _NearestPetrolPumpsScreenState();
}

class _NearestPetrolPumpsScreenState extends State<NearestPetrolPumpsScreen> {
  final MapService _mapService = MapService();
  final MapController _mapController = MapController();
  final CustomAuthService _authService = CustomAuthService();
  
  List<Marker> _markers = [];
  List<MapLocation> _allLocations = [];
  List<MapLocation> _filteredLocations = [];
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showCurrentLocation = false;
  
  // Radius filter - automatically set to 100m (0.1km)
  double _radiusInKm = 0.1;  // 100 meters
  bool _useRadiusFilter = true;  // Always enabled
  
  // Preferred companies filter
  List<String> _userPreferredCompanies = [];
  bool _usePreferredCompaniesFilter = true; // Always enabled when user has preferred companies
  
  static const latlong.LatLng _defaultCenter = latlong.LatLng(23.0225, 72.5714);
  double _currentZoom = 7.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadMapLocations();
    _loadUserPreferredCompanies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh user data when screen is focused (in case profile was updated)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Set a timeout
      ).catchError((error) {
        print('Error in getCurrentPosition: $error');
        // Fall back to last known position if available
        return Geolocator.getLastKnownPosition();
      });
      
      // If position is null (both methods failed), exit early
      if (position == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentPosition = position;
        _showCurrentLocation = true;
        _isLoading = false;
      });

      if (mounted) {
        _mapController.move(
          latlong.LatLng(position.latitude, position.longitude),
          12.0,
        );
        
        // Apply filters after getting location
        _applyFilters();
      }
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get your location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadMapLocations() {
    _mapService.getMapLocations().listen((locations) {
      setState(() {
        _allLocations = locations;
        _filteredLocations = []; // Start with empty filtered list
        _isLoading = false;
      });
      
      // Apply filters after loading locations
      _applyFilters();
    });
  }

  Future<void> _loadUserPreferredCompanies() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData.isNotEmpty && userData['preferredCompanies'] != null) {
        final preferredCompanies = List<String>.from(userData['preferredCompanies'] as List);
        setState(() {
          _userPreferredCompanies = preferredCompanies;
        });
        // Apply filters after loading preferred companies
        _applyFilters();
      }
    } catch (e) {
      print('Error loading user preferred companies: $e');
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData.isNotEmpty && userData['preferredCompanies'] != null) {
        final preferredCompanies = List<String>.from(userData['preferredCompanies'] as List);
        if (!listEquals(preferredCompanies, _userPreferredCompanies)) {
          setState(() {
            _userPreferredCompanies = preferredCompanies;
          });
          _applyFilters();
        }
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLocations = _allLocations.where((location) {
        // Check radius - always enabled and set to 100m
        bool withinRadius = false; // Changed to false by default
        if (_currentPosition != null) {
          final distanceInKm = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            location.latitude,
            location.longitude,
          ) / 1000; // Convert to km
          
          withinRadius = distanceInKm <= _radiusInKm;
        }

        // Check preferred companies if filter is enabled
        bool matchesPreferredCompanies = true;
        if (_userPreferredCompanies.isNotEmpty) {
          matchesPreferredCompanies = _userPreferredCompanies.contains(location.company);
        }

        return withinRadius && matchesPreferredCompanies;
      }).toList();
    });
    
    _createMarkers();
  }

  void _createMarkers() {
    final List<Marker> markers = [];

    if (_showCurrentLocation && _currentPosition != null) {
      markers.add(
        Marker(
          point: latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }

    for (final location in _filteredLocations) {
      if (location.latitude != 0.0 && location.longitude != 0.0) {
        markers.add(
          Marker(
            point: latlong.LatLng(location.latitude, location.longitude),
            width: 40,
            height: 48,
            child: GestureDetector(
              onTap: () {
                _highlightAndCenterOnMap(location);
                _openCamera(location);
              },
              child: CompanyPinMarker(company: location.company),
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  void _moveToLocation(latlong.LatLng location) {
    _mapController.move(location, 15.0);
  }
  
  void _highlightAndCenterOnMap(MapLocation location) {
    _moveToLocation(latlong.LatLng(location.latitude, location.longitude));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nearby Pumps (100m)',
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
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('In Radius', _filteredLocations.length.toString()),
                _buildStatItem('Radius', '${_radiusInKm * 1000} m'),
              ],
            ),
          ),
          
          // Top 50%: Map
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition != null
                        ? latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : _defaultCenter,
                    initialZoom: _currentZoom,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    onPositionChanged: (position, hasGesture) {
                      _currentZoom = position.zoom ?? 7.0;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.click',
                      maxZoom: 19,
                    ),
                    MarkerLayer(markers: _markers),
                    // Add a circle to show 100m radius
                    if (_currentPosition != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            radius: 100,
                            color: Colors.blue.withOpacity(0.1),
                            borderColor: Colors.blue.withOpacity(0.3),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                  ],
                ),
                
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                
                // Map Controls
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FloatingActionButton(
                        heroTag: "location",
                        mini: true,
                        onPressed: () {
                          if (_currentPosition != null) {
                            _moveToLocation(latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
                          } else {
                            _getCurrentLocation();
                          }
                        },
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom 50%: Location list
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // List content
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredLocations.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_off,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No petrol pumps within 100m',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Move to a different location or check your GPS',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  // Location list
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _filteredLocations.length,
                                      padding: const EdgeInsets.all(0),
                                      itemBuilder: (context, index) {
                                        final location = _filteredLocations[index];
                                        return _buildLocationListItem(location);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: -1, // No tab highlighted so all tabs are tappable
        onTap: (index) {
          switch (index) {
            case 0: // Home
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1: // Map
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
              );
              break;
            case 3: // Search
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
              );
              break;
            case 4: // Profile
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
        showFloatingActionButton: true,
        floatingActionButtonTooltip: 'Refresh',
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isLoading = true;
          });
          _loadMapLocations();
          _getCurrentLocation();
        },
        backgroundColor: const Color(0xFF35C2C1),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildLocationListItem(MapLocation location) {
    String distanceText = '';
    if (_currentPosition != null) {
      final distanceInKm = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        location.latitude,
        location.longitude,
      ) / 1000; // Convert to km
      
      if (distanceInKm < 1) {
        distanceText = '${(distanceInKm * 1000).toStringAsFixed(0)}m';
      } else {
        distanceText = '${distanceInKm.toStringAsFixed(1)}km';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          _highlightAndCenterOnMap(location);
          _openCamera(location);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyPinMarker(company: location.company),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                location.customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_currentPosition != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 12,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      distanceText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          location.addressLine1,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _getCompanyLogo(String company) {
    switch (company.toUpperCase()) {
      case 'BPCL':
        return Image.asset(
          'assets/images/BPCL_logo.png',
          fit: BoxFit.contain,
        );
      case 'HPCL':
        return Image.asset(
          'assets/images/HPCL_logo.png',
          fit: BoxFit.contain,
        );
      case 'IOCL':
        return Image.asset(
          'assets/images/IOCL_logo.png',
          fit: BoxFit.contain,
        );
      default:
        return Container(
          color: Colors.grey[200],
          child: const Icon(
            Icons.local_gas_station,
            color: Colors.grey,
            size: 16,
          ),
        );
    }
  }

  void _openCamera(MapLocation location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraSelectionScreen(location: location),
      ),
    );
  }
}

class CompanyPinMarker extends StatelessWidget {
  final String company;
  const CompanyPinMarker({Key? key, required this.company}) : super(key: key);

  Color _getPinColor(String company) {
    switch (company.toUpperCase()) {
      case 'BPCL':
        return const Color(0xFFFFE001); // Yellow (BPCL)
      case 'HPCL':
        return const Color(0xFF000269); // Blue (HPCL)
      case 'IOCL':
        return const Color(0xFFF37022); // Orange (IOCL)
      default:
        return const Color(0xFF9C27B0); // Default purple
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinColor = _getPinColor(company);
    return SizedBox(
      width: 32,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(32, 38),
            painter: _PinShapePainter(pinColor),
          ),
          Positioned(
            top: 6,
            left: 6,
            right: 6,
            child: ClipOval(
              child: _getCompanyLogo(company),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCompanyLogo(String company) {
    switch (company.toUpperCase()) {
      case 'BPCL':
        return Image.asset('assets/images/BPCL_logo.png', width: 20, height: 20, fit: BoxFit.contain);
      case 'HPCL':
        return Image.asset('assets/images/HPCL_logo.png', width: 20, height: 20, fit: BoxFit.contain);
      case 'IOCL':
        return Image.asset('assets/images/IOCL_logo.png', width: 20, height: 20, fit: BoxFit.contain);
      default:
        return Container(
          width: 20,
          height: 20,
          color: Colors.grey[200],
          child: const Icon(Icons.local_gas_station, color: Colors.grey, size: 14),
        );
    }
  }
}

class _PinShapePainter extends CustomPainter {
  final Color pinColor;
  _PinShapePainter(this.pinColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.quadraticBezierTo(size.width, size.height * 0.6, size.width, size.height * 0.35);
    path.arcToPoint(
      Offset(0, size.height * 0.35),
      radius: Radius.circular(size.width / 2),
      clockwise: false,
    );
    path.quadraticBezierTo(0, size.height * 0.6, size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Draw white circle in the center for the logo background
    final circlePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.35), 10, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 