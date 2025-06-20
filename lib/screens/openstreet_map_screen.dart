import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/map_location.dart';
import '../services/map_service.dart';
import '../services/database_service.dart';
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
  
  List<Marker> _markers = [];
  List<MapLocation> _allLocations = [];
  List<MapLocation> _filteredLocations = [];
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showCurrentLocation = false;
  
  String _selectedZone = 'All Zones';
  String _selectedDistrict = 'All Districts';
  List<String> _zones = ['All Zones'];
  List<String> _districts = ['All Districts'];
  
  // Radius filter
  double _radiusInKm = 1.0;  // Default radius 5km
  bool _useRadiusFilter = false;
  final List<double> _availableRadiusOptions = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
  
  final TextEditingController _searchController = TextEditingController();
  
  static const LatLng _defaultCenter = LatLng(23.0225, 72.5714);
  double _currentZoom = 7.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadMapLocations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
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
          LatLng(position.latitude, position.longitude),
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
    }
  }

  void _loadMapLocations() {
    _mapService.getMapLocations().listen((locations) {
      setState(() {
        _allLocations = locations;
        _filteredLocations = locations;
        _isLoading = false;
      });
      
      _updateFilterOptions();
      _createMarkers();
    });
  }

  void _updateFilterOptions() {
    final zones = _allLocations.map((loc) => loc.zone).where((zone) => zone.isNotEmpty).toSet().toList();
    final districts = _allLocations.map((loc) => loc.district).where((district) => district.isNotEmpty).toSet().toList();
    
    zones.sort();
    districts.sort();
    
    setState(() {
      _zones = ['All Zones', ...zones];
      _districts = ['All Districts', ...districts];
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final searchQuery = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredLocations = _allLocations.where((location) {
        // Check text search
        final matchesSearch = searchQuery.isEmpty ||
            location.customerName.toLowerCase().contains(searchQuery) ||
            location.location.toLowerCase().contains(searchQuery) ||
            location.addressLine1.toLowerCase().contains(searchQuery) ||
            location.dealerName.toLowerCase().contains(searchQuery);

        // Check zone
        final matchesZone = _selectedZone == 'All Zones' ||
            location.zone == _selectedZone;

        // Check district
        final matchesDistrict = _selectedDistrict == 'All Districts' ||
            location.district == _selectedDistrict;
            
        // Check radius if filter is enabled and we have current position
        bool withinRadius = true;
        if (_useRadiusFilter && _currentPosition != null) {
          final distanceInKm = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            location.latitude,
            location.longitude,
          ) / 1000; // Convert to km
          
          withinRadius = distanceInKm <= _radiusInKm;
        }

        return matchesSearch && matchesZone && matchesDistrict && withinRadius;
      }).toList();
    });
    
    _createMarkers();
  }

  void _createMarkers() {
    final List<Marker> markers = [];

    if (_showCurrentLocation && _currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
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
            point: LatLng(location.latitude, location.longitude),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showLocationDetails(location),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_gas_station,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  void _showLocationDetails(MapLocation location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
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
                    const Spacer(),
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
          ],
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

  void _moveToLocation(LatLng location) {
    _mapController.move(location, 15.0);
  }
  
  void _highlightAndCenterOnMap(MapLocation location) {
    _moveToLocation(LatLng(location.latitude, location.longitude));
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
                  child: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilterDialog,
                  ),
                ),
              ],
            ),
          ),
          
          // Stats bar
          if (_useRadiusFilter && _currentPosition != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('In Radius', _filteredLocations.length.toString()),
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
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
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
                            _moveToLocation(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
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
                  // Always show the radius slider if current position is available
                  if (_currentPosition != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _radiusInKm,
                              min: 1.0,
                              max: 100.0,
                              divisions: 20,
                              label: '${_radiusInKm.toStringAsFixed(1)} km',
                              onChanged: (value) {
                                setState(() {
                                  _radiusInKm = value;
                                  _useRadiusFilter = true;
                                });
                                _applyFilters();
                              },
                            ),
                          ),
                          Text(
                            '${_radiusInKm.toStringAsFixed(1)} km',
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
                                      Icons.location_off,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No locations found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isLoading = true;
            _useRadiusFilter = false;
            _radiusInKm = 1.0;
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_gas_station, 
                      color: Colors.red, 
                      size: 16,
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
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Options'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone filter
                DropdownButtonFormField<String>(
                  value: _selectedZone,
                  decoration: const InputDecoration(
                    labelText: 'Zone',
                    border: OutlineInputBorder(),
                  ),
                  items: _zones.map((zone) {
                    return DropdownMenuItem(value: zone, child: Text(zone));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedZone = value!;
                    });
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 16),
                
                // District filter
                DropdownButtonFormField<String>(
                  value: _selectedDistrict,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    border: OutlineInputBorder(),
                  ),
                  items: _districts.map((district) {
                    return DropdownMenuItem(value: district, child: Text(district));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDistrict = value!;
                    });
                    setDialogState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedZone = 'All Zones';
                  _selectedDistrict = 'All Districts';
                });
                _applyFilters();
                Navigator.pop(context);
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () {
                _applyFilters();
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  LatLngBounds _calculateBounds(List<MapLocation> locations) {
    if (locations.isEmpty) {
      return LatLngBounds(
        const LatLng(-90, -180),
        const LatLng(90, 180),
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
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }
} 