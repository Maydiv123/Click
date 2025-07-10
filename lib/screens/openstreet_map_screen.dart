import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/map_location.dart';
import '../services/map_service.dart';
import '../services/database_service.dart';
import '../services/custom_auth_service.dart';
import '../widgets/bottom_navigation_bar_widget.dart';
import '../widgets/app_drawer.dart';
import 'petrol_pump_details_screen.dart';
import 'search_petrol_pumps_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class OpenStreetMapScreen extends StatefulWidget {
  const OpenStreetMapScreen({Key? key}) : super(key: key);

  @override
  State<OpenStreetMapScreen> createState() => _OpenStreetMapScreenState();
}

class _OpenStreetMapScreenState extends State<OpenStreetMapScreen> {
  final MapService _mapService = MapService();
  final MapController _mapController = MapController();
  final CustomAuthService _authService = CustomAuthService();
  
  List<Marker> _markers = [];
  List<MapLocation> _allLocations = [];
  List<MapLocation> _filteredLocations = [];
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showCurrentLocation = false;
  bool _hasShownSlider = false; // Track if slider has been shown at least once
  
  // Remove zone filter
  String? _selectedState;
  String? _selectedDistrict;
  List<String> _states = [];
  List<String> _districts = [];
  Map<String, List<String>> _stateDistrictMap = {};
  
  // Radius filter
  double _radiusInKm = 0.0;  // Start at 0 km - no data loaded initially
  bool _useRadiusFilter = false;
  final List<double> _availableRadiusOptions = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
  
  // Preferred companies filter
  List<String> _userPreferredCompanies = [];
  List<String> _selectedCompanies = [];
  List<String> _appliedCompanies = []; // New variable for applied filters
  TextEditingController _stateSearchController = TextEditingController();
  TextEditingController _districtSearchController = TextEditingController();
  List<String> _filteredStates = [];
  List<String> _filteredDistricts = [];
  
  // Applied filter variables
  String? _appliedState;
  String? _appliedDistrict;
  
  final TextEditingController _searchController = TextEditingController();
  
  static const latlong.LatLng _defaultCenter = latlong.LatLng(23.0225, 72.5714);
  double _currentZoom = 7.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadMapLocations();
    _loadUserPreferredCompanies();
    _loadStateDistrictData();
    _searchController.addListener(_onSearchChanged);
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _stateSearchController.dispose();
    _districtSearchController.dispose();
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
        _hasShownSlider = true; // Mark that slider should be shown
      });

      if (mounted) {
        _mapController.move(
          latlong.LatLng(position.latitude, position.longitude),
          12.0,
        );
        
        // Don't apply filters automatically - wait for user to move slider
      }
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadMapLocations() {
    _mapService.getMapLocations().listen((locations) {
      setState(() {
        _allLocations = locations;
        _isLoading = false;
      });
      
      _updateFilterOptions();
      // Don't apply filters automatically - wait for user to apply them
    });
  }

  Future<void> _loadUserPreferredCompanies() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData.isNotEmpty && userData['preferredCompanies'] != null) {
        final preferredCompanies = List<String>.from(userData['preferredCompanies'] as List);
        setState(() {
          _userPreferredCompanies = preferredCompanies;
          // Initialize selected companies with user's preferred companies
          _selectedCompanies = List.from(preferredCompanies);
          // Initialize applied companies with user's preferred companies
          _appliedCompanies = List.from(preferredCompanies);
        });
        // Don't apply filters automatically - wait for user to move slider
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
            // Update selected companies if they were using the old preferred companies
            if (listEquals(_selectedCompanies, _userPreferredCompanies)) {
              _selectedCompanies = List.from(preferredCompanies);
            }
            // Update applied companies if they were using the old preferred companies
            if (listEquals(_appliedCompanies, _userPreferredCompanies)) {
              _appliedCompanies = List.from(preferredCompanies);
            }
          });
          // Don't apply filters automatically - wait for user to move slider
        }
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  Future<void> _loadStateDistrictData() async {
    final String jsonString = await rootBundle.loadString('assets/json/statewise_districts.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    setState(() {
      _stateDistrictMap = jsonData.map((k, v) => MapEntry(k, List<String>.from(v)));
      _states = _stateDistrictMap.keys.toList();
      _filteredStates = List.from(_states);
    });
  }

  void _updateFilterOptions() {
    // This method is no longer needed since we're using state/district from JSON
    // and companies are hardcoded. Keeping it for potential future use.
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final searchQuery = _searchController.text.toLowerCase();

    setState(() {
      // If slider is at 0, show nothing
      if (_radiusInKm == 0.0) {
        _filteredLocations = [];
      } else {
        _filteredLocations = _allLocations.where((location) {
          // Text search
          final matchesSearch = searchQuery.isEmpty ||
              location.customerName.toLowerCase().contains(searchQuery) ||
              location.location.toLowerCase().contains(searchQuery) ||
              location.addressLine1.toLowerCase().contains(searchQuery) ||
              location.dealerName.toLowerCase().contains(searchQuery);

          // State filter - check if location's district belongs to selected state
          bool matchesState = true;
          if (_appliedState != null && _appliedState!.isNotEmpty) {
            // Get districts for the selected state
            final stateDistricts = _stateDistrictMap[_appliedState!] ?? [];
            // Check if location's district is in the state's district list
            matchesState = location.district.isNotEmpty &&
                stateDistricts.any((stateDistrict) => 
                    location.district.toLowerCase().contains(stateDistrict.toLowerCase()) ||
                    stateDistrict.toLowerCase().contains(location.district.toLowerCase())
                );
          }

          // District filter - direct match
          bool matchesDistrict = true;
          if (_appliedDistrict != null && _appliedDistrict!.isNotEmpty) {
            matchesDistrict = location.district.toLowerCase().contains(_appliedDistrict!.toLowerCase()) ||
                            _appliedDistrict!.toLowerCase().contains(location.district.toLowerCase());
          }

          // Radius
          bool withinRadius = true;
          if (_useRadiusFilter && _currentPosition != null) {
            final distanceInKm = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              location.latitude,
              location.longitude,
            ) / 1000;
            withinRadius = distanceInKm <= _radiusInKm;
          }

          // Preferred companies filter
          bool matchesPreferredCompanies = true;
          if (_appliedCompanies.isNotEmpty) {
            // If user has manually selected companies in filter, use those
            matchesPreferredCompanies = _appliedCompanies.contains(location.company);
          } else if (_userPreferredCompanies.isNotEmpty) {
            // If no manual selection, use user's preferred companies
            matchesPreferredCompanies = _userPreferredCompanies.contains(location.company);
          }

          return matchesSearch && matchesState && matchesDistrict && withinRadius && matchesPreferredCompanies;
        }).toList();
      }
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
              onTap: () => _showLocationDetails(location),
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

  bool _hasActiveFilters() {
    // Only consider filters active if user has explicitly applied them through the filter dialog
    // Don't count default preferred companies as active filters
    return (_appliedState != null && _appliedState!.isNotEmpty) ||
           (_appliedDistrict != null && _appliedDistrict!.isNotEmpty) ||
           (_appliedCompanies.isNotEmpty && !listEquals(_appliedCompanies, _userPreferredCompanies));
  }

  void _showLocationDetails(MapLocation location) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_gas_station, color: Colors.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location.customerName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                location.location,
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Address', '${location.addressLine1}, ${location.addressLine2}'),
                    const SizedBox(height: 8),
                    _buildInfoRow('District', location.district),
                    const SizedBox(height: 8),
                    _buildInfoRow('Zone', location.zone),
                    const SizedBox(height: 8),
                    _buildInfoRow('Dealer', location.dealerName),
                    const SizedBox(height: 8),
                    _buildInfoRow('Company', location.company),
                  const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final url = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(Uri.parse(url));
                              }
                            },
                            icon: const Icon(Icons.location_on),
                            label: const Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF35C2C1),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PetrolPumpDetailsScreen(location: location),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline),
                            label: const Text('View Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'N/A',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
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
      drawer: const AppDrawer(currentScreen: 'map'),
      appBar: AppBar(
        title: const Text(
          'Petrol Pump Locations',
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
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search petrol pumps...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.filter_list, color: _hasActiveFilters() ? Colors.teal : 
                    Colors.grey),
                        onPressed: _showFilterDialog,
                      ),
                      if (_hasActiveFilters())
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Stats bar
          if (_useRadiusFilter && _currentPosition != null && _radiusInKm > 0.0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (_useRadiusFilter && _currentPosition != null && _radiusInKm > 0.0)
                  _buildStatItem('In Radius', _filteredLocations.length.toString()),
                  if (_useRadiusFilter && _currentPosition != null && _radiusInKm > 0.0)
                  _buildStatItem('Radius', '${_radiusInKm.toStringAsFixed(1)} km'),
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
                            // Ensure slider remains visible during location fetch
                            if (!_hasShownSlider) {
                              setState(() {
                                _hasShownSlider = true;
                              });
                            }
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
                  // Always show the radius slider if current position is available or if it was shown before
                  if (_currentPosition != null || _hasShownSlider) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _radiusInKm,
                              min: 0.0,
                              max: 100.0,
                              divisions: 20,
                              label: _radiusInKm == 0.0 ? 'No filter' : '${_radiusInKm.toStringAsFixed(1)} km',
                              onChanged: (value) {
                                setState(() {
                                  _radiusInKm = value;
                                  _useRadiusFilter = value > 0.0;
                                });
                                _applyFilters();
                              },
                            ),
                          ),
                          Text(
                            _radiusInKm == 0.0 ? 'No filter' : '${_radiusInKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
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
                                      _radiusInKm == 0.0 ? Icons.tune : Icons.location_off,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _radiusInKm == 0.0 
                                          ? 'Move the slider to load nearby petrol pumps'
                                          : 'No locations found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_radiusInKm == 0.0) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Adjust the radius to see petrol pumps in your area',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
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
        currentIndex: 1, // Map index
        onTap: (index) {
          switch (index) {
            case 0: // Home
              Navigator.pop(context);
              break;
            case 1: // Map
              // Already on map screen, do nothing
              break;
            case 3: // Search
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
              );
              break;
            case 4: // Profile
              Navigator.pushNamed(context, '/profile');
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
            // Don't reset radius to 0 - maintain user's last setting or use default
            if (_radiusInKm == 0.0) {
              _radiusInKm = 5.0; // Default to 5km if no radius was set
              _useRadiusFilter = true;
            }
            // Keep the current radius value instead of resetting to 0
            // Preserve the slider visibility flag
            if (!_hasShownSlider) {
              _hasShownSlider = true;
            }
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
          _showLocationDetails(location);
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
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _getCompanyLogo(location.company),
                    ),
                  ),
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF35C2C1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Filter Options',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preferred Companies Section
                        _buildSectionHeader(
                          icon: Icons.business,
                          title: 'Preferred Companies',
                          subtitle: 'Select your preferred fuel companies',
                        ),
                        const SizedBox(height: 16),
                        _userPreferredCompanies.isNotEmpty
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: _userPreferredCompanies.map((company) {
                                    final isSelected = _selectedCompanies.contains(company);
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      child: FilterChip(
                                        label: Text(
                                          company,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.black87,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFF35C2C1),
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: isSelected ? const Color(0xFF35C2C1) : Colors.grey[300]!,
                                          width: 1.5,
                                        ),
                                        elevation: isSelected ? 4 : 0,
                                        shadowColor: const Color(0xFF35C2C1).withOpacity(0.3),
                                        showCheckmark: false,
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedCompanies.add(company);
                                            } else {
                                              if (_selectedCompanies.length > 1) {
                                                _selectedCompanies.remove(company);
                                              }
                                            }
                                          });
                                          setDialogState(() {});
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No preferred companies set. Please update your profile.',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 24),
                        
                        // Location Filters Section
                        _buildSectionHeader(
                          icon: Icons.location_on,
                          title: 'Location Filters',
                          subtitle: 'Filter by state and district',
                        ),
                        const SizedBox(height: 16),
                        
                        // State Filter
                        _buildFilterField(
                          label: 'State',
                          icon: Icons.map,
                          child: _buildAutocompleteSearch(
                            value: _selectedState,
                            hintText: 'Search and select state...',
                            items: _states,
                            onChanged: (value) {
                              setState(() {
                                _selectedState = value;
                                _selectedDistrict = null;
                                _districts = value != null ? _stateDistrictMap[value]! : [];
                                _filteredDistricts = List.from(_districts);
                                _districtSearchController.clear();
                              });
                              setDialogState(() {});
                            },
                            searchController: _stateSearchController,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // District Filter
                        _buildFilterField(
                          label: 'District',
                          icon: Icons.location_city,
                          child: _selectedState != null
                              ? _buildAutocompleteSearch(
                                  value: _selectedDistrict,
                                  hintText: 'Search and select district...',
                                  items: _districts,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDistrict = value;
                                    });
                                    setDialogState(() {});
                                  },
                                  searchController: _districtSearchController,
                                )
                              : _buildAutocompleteSearch(
                                  value: null,
                                  hintText: 'Select State First',
                                  items: [],
                                  onChanged: (value) {},
                                  searchController: _districtSearchController,
                                  enabled: false,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedCompanies.clear();
                              _selectedState = null;
                              _selectedDistrict = null;
                              _districts = [];
                              _filteredStates = List.from(_states);
                              _filteredDistricts = [];
                              _stateSearchController.clear();
                              _districtSearchController.clear();
                              
                              // Also clear applied filters
                              _appliedCompanies.clear();
                              _appliedState = null;
                              _appliedDistrict = null;
                            });
                            _applyFilters(); // Apply the cleared filters
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear All'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              // Apply the selected filters
                              _appliedCompanies = List.from(_selectedCompanies);
                              _appliedState = _selectedState;
                              _appliedDistrict = _selectedDistrict;
                            });
                            _applyFilters(); // Apply the filters
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Apply Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF35C2C1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildAutocompleteSearch({
    required String? value,
    required String hintText,
    required List<String> items,
    required Function(String?) onChanged,
    required TextEditingController searchController,
    bool enabled = true,
  }) {
    return Autocomplete<String>(
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        // Sync the controller with our search controller
        if (textEditingController.text != searchController.text) {
          textEditingController.text = searchController.text;
          textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: searchController.text.length),
          );
        }
        
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: enabled ? Colors.grey[600] : Colors.grey[400],
              size: 20,
            ),
            suffixIcon: value != null ? IconButton(
              icon: Icon(
                Icons.clear,
                color: Colors.grey[600],
                size: 20,
              ),
              onPressed: () {
                searchController.clear();
                textEditingController.clear();
                onChanged(null);
              },
            ) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF35C2C1), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: TextStyle(
            fontSize: 14,
            color: enabled ? Colors.black87 : Colors.grey[600],
          ),
          onChanged: (text) {
            searchController.text = text;
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return items;
        }
        return items.where((item) => 
          item.toLowerCase().contains(textEditingValue.text.toLowerCase())
        ).toList();
      },
      onSelected: (String selection) {
        searchController.text = selection;
        onChanged(selection);
      },
      displayStringForOption: (String option) => option,
      optionsViewBuilder: (context, onSelected, options) {
        return Material(
          elevation: 8.0,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (BuildContext context, int index) {
                final String option = options.elementAt(index);
                final bool isSelected = value == option;
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? const Color(0xFF35C2C1) : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF35C2C1).withOpacity(0.1),
                  onTap: () {
                    onSelected(option);
                  },
                  trailing: isSelected ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF35C2C1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  LatLngBounds _calculateBounds(List<MapLocation> locations) {
    if (locations.isEmpty) {
      return LatLngBounds(
        const latlong.LatLng(-90, -180),
        const latlong.LatLng(90, 180),
      );
    }

    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      minLat = minLat < location.latitude ? minLat : location.latitude;
      maxLat = maxLat > location.latitude ? maxLat : location.latitude;
      minLng = minLng < location.longitude ? minLng : location.longitude;
      maxLng = maxLng > location.longitude ? maxLng : location.longitude;
    }

    return LatLngBounds(
      latlong.LatLng(minLat, minLng),
      latlong.LatLng(maxLat, maxLng),
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
      width: 40,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(40, 48),
            painter: _PinShapePainter(pinColor),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
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
        return Image.asset('assets/images/BPCL_logo.png', width: 24, height: 24, fit: BoxFit.contain);
      case 'HPCL':
        return Image.asset('assets/images/HPCL_logo.png', width: 24, height: 24, fit: BoxFit.contain);
      case 'IOCL':
        return Image.asset('assets/images/IOCL_logo.png', width: 24, height: 24, fit: BoxFit.contain);
      default:
        return Container(
          width: 24,
          height: 24,
          color: Colors.grey[200],
          child: const Icon(Icons.local_gas_station, color: Colors.grey, size: 16),
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
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.35), 16, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 