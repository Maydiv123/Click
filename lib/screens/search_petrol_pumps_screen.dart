import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/map_location.dart';
import '../services/map_service.dart';
import '../services/custom_auth_service.dart';
import '../widgets/bottom_navigation_bar_widget.dart';
import '../widgets/app_drawer.dart';
import 'petrol_pump_details_screen.dart';
import 'openstreet_map_screen.dart';
import 'nearest_petrol_pumps_screen.dart';

class SearchPetrolPumpsScreen extends StatefulWidget {
  const SearchPetrolPumpsScreen({Key? key}) : super(key: key);

  @override
  State<SearchPetrolPumpsScreen> createState() => _SearchPetrolPumpsScreenState();
}

class _SearchPetrolPumpsScreenState extends State<SearchPetrolPumpsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapService _mapService = MapService();
  final CustomAuthService _authService = CustomAuthService();
  String _selectedZone = 'All Zones';
  String _selectedDistrict = 'All Districts';
  List<String> _zones = ['All Zones'];
  List<String> _districts = ['All Districts'];
  
  // Preferred companies filter
  List<String> _userPreferredCompanies = [];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
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

  Future<void> _loadFilterOptions() async {
    final locations = await _mapService.getMapLocations().first;
    final zones = locations.map((loc) => loc.zone).toSet().toList();
    final districts = locations.map((loc) => loc.district).toSet().toList();
    
    setState(() {
      _zones = ['All Zones', ...zones];
      _districts = ['All Districts', ...districts];
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
        }
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(currentScreen: 'search'),
      appBar: AppBar(
        title: const Text(
          'Search Petrol Pumps',
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
            child: TextField(
              controller: _searchController,
                    style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                      hintText: 'Search by name, location, or address',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: _selectedZone,
                        onTap: () => _showFilterDialog(
                          title: 'Select Zone',
                          items: _zones,
                          onSelect: (value) {
                            setState(() => _selectedZone = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: _selectedDistrict,
                        onTap: () => _showFilterDialog(
                          title: 'Select District',
                          items: _districts,
                          onSelect: (value) {
                            setState(() => _selectedDistrict = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MapLocation>>(
              stream: _mapService.getMapLocations(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF35C2C1)),
                    ),
                  );
                }

                final locations = snapshot.data!;
                final filteredLocations = locations.where((location) {
                  final searchQuery = _searchController.text.toLowerCase();
                  final matchesSearch = searchQuery.isEmpty ||
                      location.customerName.toLowerCase().contains(searchQuery) ||
                      location.location.toLowerCase().contains(searchQuery) ||
                      location.addressLine1.toLowerCase().contains(searchQuery);

                  final matchesZone = _selectedZone == 'All Zones' ||
                      location.zone == _selectedZone;

                  final matchesDistrict = _selectedDistrict == 'All Districts' ||
                      location.district == _selectedDistrict;

                  // Check preferred companies if user has any
                  bool matchesPreferredCompanies = true;
                  if (_userPreferredCompanies.isNotEmpty) {
                    matchesPreferredCompanies = _userPreferredCompanies.contains(location.company);
                  }

                  return matchesSearch && matchesZone && matchesDistrict && matchesPreferredCompanies;
                }).toList();

                if (filteredLocations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userPreferredCompanies.isNotEmpty 
                              ? 'No preferred company pumps found'
                              : 'No petrol pumps found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 18,
                          ),
                        ),
                        if (_userPreferredCompanies.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLocations.length,
              itemBuilder: (context, index) {
                    final location = filteredLocations[index];
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
                        builder: (context) => PetrolPumpDetailsScreen(
                                location: location,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
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
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location.customerName,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      location.addressLine1,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          location.location.isNotEmpty && location.district.isNotEmpty
                                              ? '${location.location}, ${location.district}'
                                              : location.location.isNotEmpty
                                                  ? location.location
                                                  : location.district.isNotEmpty
                                                      ? location.district
                                                      : '',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NearestPetrolPumpsScreen()),
          );
        },
        backgroundColor: const Color(0xFF35C2C1),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 3, // Search index
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
              // Already on search screen, do nothing
              break;
            case 4: // Profile
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
        showFloatingActionButton: true,
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog({
    required String title,
    required List<String> items,
    required Function(String) onSelect,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(color: Colors.black),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(
                  item,
                  style: const TextStyle(color: Colors.black),
                ),
                onTap: () {
                  onSelect(item);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _getCompanyLogo(String company) {
    switch (company.toUpperCase()) {
      case 'BPCL':
        return Image.asset('assets/images/BPCL_logo.png', fit: BoxFit.contain);
      case 'HPCL':
        return Image.asset('assets/images/HPCL_logo.png', fit: BoxFit.contain);
      case 'IOCL':
        return Image.asset('assets/images/IOCL_logo.png', fit: BoxFit.contain);
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