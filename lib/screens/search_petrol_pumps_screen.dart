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
  TextEditingController _stateSearchController = TextEditingController();
  TextEditingController _districtSearchController = TextEditingController();
  List<String> _filteredStates = [];
  List<String> _filteredDistricts = [];

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
                  child: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilterDialog,
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
                  if (_selectedCompanies.isNotEmpty) {
                    // If user has manually selected companies in filter, use those
                    matchesPreferredCompanies = _selectedCompanies.contains(location.company);
                  } else if (_userPreferredCompanies.isNotEmpty) {
                    // If no manual selection, use user's preferred companies
                    matchesPreferredCompanies = _userPreferredCompanies.contains(location.company);
                  }

                  // State filter - check if location's district belongs to selected state
                  bool matchesState = true;
                  if (_selectedState != null && _selectedState!.isNotEmpty) {
                    // Get districts for the selected state
                    final stateDistricts = _stateDistrictMap[_selectedState!] ?? [];
                    // Check if location's district is in the state's district list
                    matchesState = location.district.isNotEmpty &&
                        stateDistricts.any((stateDistrict) => 
                            location.district.toLowerCase().contains(stateDistrict.toLowerCase()) ||
                            stateDistrict.toLowerCase().contains(location.district.toLowerCase())
                        );
                  }

                  // District filter - direct match
                  bool matchesDistrict = true;
                  if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
                    matchesDistrict = location.district.toLowerCase().contains(_selectedDistrict!.toLowerCase()) ||
                                    _selectedDistrict!.toLowerCase().contains(location.district.toLowerCase());
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
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Options'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preferred Companies (multi-select chips)
                const Text('Preferred Companies', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _userPreferredCompanies.isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _userPreferredCompanies.map((company) {
                        final isSelected = _selectedCompanies.contains(company);
                                                return ChoiceChip(
                          label: Text(company),
                          selected: isSelected,
                          selectedColor: const Color(0xFF35C2C1),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCompanies.add(company);
                              } else {
                                // Prevent deselecting the last company
                                if (_selectedCompanies.length > 1) {
                                  _selectedCompanies.remove(company);
                                }
                                // No warning message - silently prevent deselection
                              }
                            });
                            setDialogState(() {});
                          },
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: Colors.grey[100],
                          showCheckmark: false,
                        );
                      }).toList(),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'No preferred companies set. Please update your profile.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                // State filter (autocomplete search)
                const Text('State', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildAutocompleteSearch(
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
                const SizedBox(height: 16),
                // District filter (autocomplete search, state-dependent)
                const Text('District', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _selectedState != null
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
              ],
            ),
          ),
          actions: [
            TextButton(
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
                });
                Navigator.pop(context);
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
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
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value != null ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                searchController.clear();
                textEditingController.clear();
                onChanged(null);
              },
            ) : null,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
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
          elevation: 4.0,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (BuildContext context, int index) {
                final String option = options.elementAt(index);
                final bool isSelected = value == option;
                return ListTile(
                  title: Text(option),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF35C2C1).withOpacity(0.1),
                  onTap: () {
                    onSelected(option);
                  },
                  trailing: isSelected ? const Icon(
                    Icons.check,
                    color: Color(0xFF35C2C1),
                  ) : null,
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