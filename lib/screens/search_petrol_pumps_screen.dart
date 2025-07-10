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
import 'dart:convert';
import 'package:flutter/services.dart';

class SearchPetrolPumpsScreen extends StatefulWidget {
  const SearchPetrolPumpsScreen({Key? key}) : super(key: key);

  @override
  State<SearchPetrolPumpsScreen> createState() => _SearchPetrolPumpsScreenState();
}

class _SearchPetrolPumpsScreenState extends State<SearchPetrolPumpsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapService _mapService = MapService();
  final CustomAuthService _authService = CustomAuthService();
  // Remove zone
  // String _selectedZone = 'All Zones';
  String? _selectedState;
  String? _selectedDistrict;
  List<String> _states = [];
  List<String> _districts = [];
  Map<String, List<String>> _stateDistrictMap = {};
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

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _loadUserPreferredCompanies();
    _loadStateDistrictData();
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
    // This method is no longer needed since we're using state/district from JSON
    // and companies are hardcoded. Keeping it for potential future use.
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
                    onChanged: (value) {
                      setState(() {});
                    },
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
                        icon: Icon(
                          Icons.filter_list,
                          color: _hasActiveFilters() ? const Color(0xFF35C2C1) : Colors.grey[600],
                        ),
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
                              color: Color(0xFF35C2C1),
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

                  // Preferred companies filter
                  bool matchesPreferredCompanies = true;
                  if (_appliedCompanies.isNotEmpty) {
                    // If user has manually selected companies in filter, use those
                    matchesPreferredCompanies = _appliedCompanies.contains(location.company);
                  } else if (_userPreferredCompanies.isNotEmpty) {
                    // If no manual selection, use user's preferred companies
                    matchesPreferredCompanies = _userPreferredCompanies.contains(location.company);
                  }

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

                  return matchesSearch && matchesPreferredCompanies && matchesState && matchesDistrict;
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

  bool _hasActiveFilters() {
    // Check if any filters are applied
    bool hasCompanyFilters = _appliedCompanies.isNotEmpty && 
                           !listEquals(_appliedCompanies, _userPreferredCompanies);
    bool hasStateFilter = _appliedState != null && _appliedState!.isNotEmpty;
    bool hasDistrictFilter = _appliedDistrict != null && _appliedDistrict!.isNotEmpty;
    
    return hasCompanyFilters || hasStateFilter || hasDistrictFilter;
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

  @override
  void dispose() {
    _searchController.dispose();
    _stateSearchController.dispose();
    _districtSearchController.dispose();
    super.dispose();
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