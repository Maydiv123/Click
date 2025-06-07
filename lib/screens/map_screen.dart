import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/map_location.dart';
import '../services/map_service.dart';
import 'petrol_pump_details_screen.dart';
import 'openstreet_map_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapService _mapService = MapService();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _isMapCreated = false;
  bool _hasMapError = false;
  Position? _currentPosition;
  List<MapLocation> _nearbyPumps = [];
  static const double _radiusInMeters = 500;
  static const LatLng _defaultLocation = LatLng(24.589795, 73.695265); // Default to Udaipur

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadNearbyPetrolPumps(); // Load data even without location
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required to show nearby petrol pumps'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      _loadNearbyPetrolPumps();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadNearbyPetrolPumps() async {
    try {
      final locations = await _mapService.getMapLocations().first;
      
      // If we have current position, filter and sort by distance
      if (_currentPosition != null) {
        _nearbyPumps = locations.where((location) {
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            location.latitude,
            location.longitude,
          );
          return distance <= _radiusInMeters;
        }).toList();
      } else {
        // If no current position, just take first 10 locations
        _nearbyPumps = locations.take(10).toList();
      }

      // Sort by distance if we have current position
      if (_currentPosition != null) {
        _nearbyPumps.sort((a, b) {
          final distanceA = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            a.latitude,
            a.longitude,
          );
          final distanceB = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            b.latitude,
            b.longitude,
          );
          return distanceA.compareTo(distanceB);
        });
      }

      setState(() {
        _markers = _nearbyPumps.map((location) {
          final snippet = _currentPosition != null 
              ? '${(Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  location.latitude,
                  location.longitude,
                ) / 1000).toStringAsFixed(1)} km away'
              : location.addressLine1;
          return Marker(
            markerId: MarkerId(location.customerName),
            position: LatLng(location.latitude, location.longitude),
            infoWindow: InfoWindow(
              title: location.customerName,
              snippet: snippet,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PetrolPumpDetailsScreen(
                      location: location,
                    ),
                  ),
                );
              },
            ),
          );
        }).toSet();
        _isLoading = false;
      });

      // Center map on current location
      if (_isMapCreated && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading petrol pumps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMapWidget() {
    // Check if we're on web and should use alternative map
    if (_hasMapError || kIsWeb) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                kIsWeb ? 'Web Map Alternative' : 'Google Maps Not Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kIsWeb 
                    ? 'Google Maps has compatibility issues on web.\nUse our OpenStreetMap alternative for better performance.'
                    : 'There was an issue loading Google Maps.\nYou can try the OpenStreetMap alternative.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OpenStreetMapScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('Use OpenStreetMap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35C2C1),
                  foregroundColor: Colors.white,
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _hasMapError = false;
                    });
                  },
                  child: const Text('Retry Google Maps'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    try {
      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : _defaultLocation,
          zoom: 15,
        ),
        onMapCreated: (controller) {
          try {
            setState(() {
              _mapController = controller;
              _isMapCreated = true;
            });
            if (_currentPosition != null) {
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    zoom: 15,
                  ),
                ),
              );
            }
          } catch (e) {
            print('Error in onMapCreated: $e');
            setState(() {
              _hasMapError = true;
            });
          }
        },
        markers: _markers,
        myLocationEnabled: false, // Disabled to avoid web issues
        myLocationButtonEnabled: false,
        mapType: MapType.normal,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false, // Disabled to avoid web issues
        rotateGesturesEnabled: true,
        scrollGesturesEnabled: true,
        tiltGesturesEnabled: false, // Disabled to avoid web issues
        zoomGesturesEnabled: true,
        onCameraMove: (position) {
          // Optional: Add any camera move handling here
        },
        onCameraIdle: () {
          // Optional: Add any camera idle handling here
        },
      );
    } catch (e) {
      print('Error building GoogleMap: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasMapError = true;
          });
        }
      });
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Nearby Petrol Pumps',
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
      body: Stack(
        children: [
          _buildMapWidget(),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF35C2C1)),
                ),
              ),
            ),
          // Nearby Pumps List
          if (!_isLoading && _nearbyPumps.isNotEmpty)
          Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: _nearbyPumps.length,
                  itemBuilder: (context, index) {
                    final pump = _nearbyPumps[index];
                    final distance = _currentPosition != null 
                        ? Geolocator.distanceBetween(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            pump.latitude,
                            pump.longitude,
                          )
                        : 0.0;
                    return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PetrolPumpDetailsScreen(
                              location: pump,
                                    ),
                                  ),
                                );
                              },
                      child: Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pump.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pump.addressLine1,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: const Color(0xFF35C2C1),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _currentPosition != null
                                      ? '${(distance / 1000).toStringAsFixed(1)} km'
                                      : pump.district,
                                  style: const TextStyle(
                                    color: Color(0xFF35C2C1),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                      ),
                    ],
                  ),
                ),
              );
            },
                ),
              ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  zoom: 15,
                ),
              ),
            );
          } else {
            _getCurrentLocation();
          }
        },
        backgroundColor: const Color(0xFF35C2C1),
        child: const Icon(
          Icons.my_location,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 