import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'map_screen.dart';
import 'openstreet_map_screen.dart';
import 'camera_screen.dart';
import 'search_petrol_pumps_screen.dart';
import 'add_petrol_pump_screen.dart';
import 'nearest_petrol_pumps_screen.dart';
import '../widgets/profile_completion_indicator.dart';
import '../widgets/bottom_navigation_bar_widget.dart';
import '../widgets/app_drawer.dart';
import 'create_team_screen.dart';
import 'join_team_screen.dart';
import 'location_history_screen.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../services/custom_auth_service.dart';
import '../services/map_service.dart';
import '../models/map_location.dart';
import 'login_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final DatabaseService _databaseService = DatabaseService();
  final UserService _userService = UserService();
  final CustomAuthService _authService = CustomAuthService();
  
  // User data
  Map<String, dynamic> _userData = {};
  bool _isLoadingUserData = true;
  
  // Location variables
  Position? _currentPosition;
  String _locationMessage = 'Fetching location...';
  bool _isLocationLoading = true;
  double _todayDistance = 0.0;
  Timer? _locationTimer;

  // Static data structure
  final Map<String, dynamic> staticData = {
    'recentActivities': [
      {'type': 'visit', 'location': 'Shell Station', 'time': '2 hours ago', 'rating': 4.5},
      {'type': 'upload', 'location': 'BP Station', 'time': '5 hours ago', 'status': 'Approved'},
      {'type': 'chat', 'location': 'Team Chat', 'time': '1 hour ago', 'message': 'Meeting at 2 PM'},
    ],
    'frequentVisits': [
      {'name': 'Shell Station', 'visits': 8, 'lastVisit': '2 days ago', 'rating': 4.5},
      {'name': 'BP Station', 'visits': 5, 'lastVisit': '5 days ago', 'rating': 4.2},
      {'name': 'IOCL Station', 'visits': 3, 'lastVisit': '1 week ago', 'rating': 4.0},
    ],
    'todayVisits': [
      {'name': 'Shell Station', 'time': '9:30 AM', 'fuel': '20L'},
      {'name': 'BP Station', 'time': '2:15 PM', 'fuel': '15L'},
    ],
    'upcomingTasks': [
      {'title': 'Team Meeting', 'time': '2:00 PM', 'type': 'meeting'},
      {'title': 'Upload Station Photos', 'time': '4:00 PM', 'type': 'task'},
    ],
  };

  // Add this controller as a class field
  late PageController _pageController;

  // Add this field to track current page
  int _currentPage = 0;
  int _currentAdPage = 0;
  Timer? _adTimer;
  PageController? _adPageController;
  final List<String> adImages = [
    'https://www.shutterstock.com/image-vector/engine-oil-advertising-banner-3d-260nw-2419747347.jpg',
    'https://exchange4media.gumlet.io/news-photo/1530600458_Sj56qH_Indian-Oil_Car-creative_final.jpg',
    'https://pbs.twimg.com/media/E3l4p85VEAA0ZhW.jpg:large',
    'https://beast-of-traal.s3.ap-south-1.amazonaws.com/2022/05/hero-pleasureplus-hindi-ad.jpeg'
  ];

  // Add these fields for nearest petrol pumps
  bool _isLoadingNearbyPumps = true;
  List<MapLocation> _nearbyPetrolPumps = [];
  final MapService _mapService = MapService();
  final double _radiusInKm = 5.0; // 5 km radius

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _adPageController = PageController(initialPage: 0);
    _getCurrentLocation();
    _fetchTodayDistance();
    _loadUserData();
    
    // Set up periodic location updates (every 5 minutes)
    _locationTimer = Timer.periodic(
      const Duration(minutes: 5), 
      (timer) => _getCurrentLocation()
    );
    
    // Set up ad slider timer
    _startAdTimer();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pageController.dispose();
    _adPageController?.dispose();
    _adTimer?.cancel();
    super.dispose();
  }

  // Fetch today's distance traveled
  Future<void> _fetchTodayDistance() async {
    try {
      final distance = await _databaseService.getTodaysDistance();
      if (mounted) {
        setState(() {
          _todayDistance = distance;
        });
      }
    } catch (e) {
      print('Error fetching today\'s distance: $e');
    }
  }

  // Get current location and fetch nearby petrol pumps
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (!mounted) return;
      
      setState(() {
        _currentPosition = position;
      });
      
      // Fetch nearby petrol pumps
      await _fetchNearbyPetrolPumps(position.latitude, position.longitude);
      
      // Update user location in Firestore
      await _databaseService.updateSimpleUserLocation(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  // Fetch nearby petrol pumps from the database
  Future<void> _fetchNearbyPetrolPumps(double latitude, double longitude) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingNearbyPumps = true;
    });
    
    try {
      // Get all map locations instead of just within radius
      final allLocations = await _mapService.getAllMapLocations();
      
      // Sort by distance
      allLocations.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
          latitude,
          longitude,
          a.latitude,
          a.longitude,
        );
        
        final distanceB = Geolocator.distanceBetween(
          latitude,
          longitude,
          b.latitude,
          b.longitude,
        );
        
        return distanceA.compareTo(distanceB);
      });
      
      // Take only the top 5 nearest pumps
      final nearestPumps = allLocations.take(5).toList();
      
      if (mounted) {
        setState(() {
          _nearbyPetrolPumps = nearestPumps;
          _isLoadingNearbyPumps = false;
        });
      }
    } catch (e) {
      print('Error fetching nearby petrol pumps: $e');
      if (mounted) {
        setState(() {
          _isLoadingNearbyPumps = false;
        });
      }
    }
  }

  // Get location string from user data
  String _getLocationFromUserData(Map<String, dynamic> userData) {
    if (userData.containsKey('location') && 
        userData['location'] != null && 
        userData['location'] is Map<String, dynamic>) {
      final location = userData['location'] as Map<String, dynamic>;
      if (location.containsKey('latitude') && location.containsKey('longitude')) {
        final lat = location['latitude'];
        final lng = location['longitude'];
        return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      }
    }
    return _locationMessage;
  }

  // Get formatted timestamp for last location update
  String _getLastLocationUpdateTime(Map<String, dynamic> userData) {
    if (userData.containsKey('lastLocationUpdate') && 
        userData['lastLocationUpdate'] != null) {
      final timestamp = userData['lastLocationUpdate'];
      if (timestamp is Timestamp) {
        final dateTime = timestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(dateTime);
        
        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inHours < 1) {
          return '${difference.inMinutes} min ago';
        } else if (difference.inDays < 1) {
          return '${difference.inHours} hr ago';
        } else {
          return '${difference.inDays} days ago';
        }
      }
    }
    return '';
  }

  double _calculateProfileCompletion(Map<String, dynamic> userData) {
    int totalFields = 6; // Total number of required fields
    int filledFields = 0;

    if (userData['firstName'] != null && userData['firstName'].toString().isNotEmpty) filledFields++;
    if (userData['lastName'] != null && userData['lastName'].toString().isNotEmpty) filledFields++;
    if (userData['mobile'] != null && userData['mobile'].toString().isNotEmpty) filledFields++;
    if (userData['dob'] != null && userData['dob'].toString().isNotEmpty) filledFields++;
    if (userData['address'] != null && userData['address'].toString().isNotEmpty) filledFields++;
    if (userData['aadharNo'] != null && userData['aadharNo'].toString().isNotEmpty) filledFields++;

    return (filledFields / totalFields) * 100;
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
      );
    } else if (index == 3) {
      // For search tab, navigate to SearchPetrolPumpsScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
      );
    } else if (index == 4) {
      // For profile tab, navigate to ProfileScreen
      Navigator.pushNamed(context, '/profile');
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _leaveTeam(String? teamCode, String? userId) async {
    // Validate inputs
    if (teamCode == null || teamCode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Team code not found'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    // If no userId provided, use current user's ID
    final currentUserId = await _authService.getCurrentUserId();
    final userIdToUse = userId ?? currentUserId;
    
    if (userIdToUse == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not authenticated'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    try {
      print('Attempting to leave team: $teamCode for user: $userIdToUse');
      await _userService.removeTeamMember(teamCode, userIdToUse.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the team.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('Error leaving team: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave team: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
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
      drawer: _isLoadingUserData 
        ? const Drawer() 
        : const AppDrawer(currentScreen: 'home'),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home/Dashboard View
          _isLoadingUserData 
          ? const Center(child: CircularProgressIndicator()) 
          : Builder(
            builder: (context) {
              final userData = _userData;
              final completionPercentage = _calculateProfileCompletion(userData);
              final stats = userData['stats'] as Map<String, dynamic>? ?? {};

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Navigation Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildNavButton('Profile', 0),
                        const SizedBox(width: 8),
                        _buildNavButton('Team', 1),
                        const SizedBox(width: 8),
                        _buildNavButton('Stats', 2),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // User Status Card
                    Container(
                      height: 150,
                      child: PageView(
                        physics: const BouncingScrollPhysics(),
                        pageSnapping: true,
                        padEnds: false,
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        children: [
                          // First Card - User Details
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.teal.withOpacity(0.7), Colors.teal.withOpacity(0.9)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey[300],
                                      child: const Icon(Icons.person, size: 20, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            userData['userType']?.toString().replaceAll('UserType.', '') ?? 'N/A',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            '',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(context, '/profile');
                                      },
                                      child: Row(
                                        children: [
                                          ProfileCompletionIndicator(
                                            completionPercentage: completionPercentage,
                                            size: 40,
                                            strokeWidth: 3,
                                            progressColor: Colors.white,
                                            backgroundColor: Colors.white,
                                            percentageStyle: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Profile",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Location indicator
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text(
                                                  'Current Location',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  _getLastLocationUpdateTime(userData),
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.7),
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _getLocationFromUserData(userData),
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.7),
                                                      fontSize: 11,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (_isLocationLoading)
                                                  const SizedBox(
                                                    width: 10,
                                                    height: 10,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                if (!_isLocationLoading)
                                                  IconButton(
                                                    icon: const Icon(Icons.refresh, color: Colors.white, size: 14),
                                                    onPressed: _getCurrentLocation,
                                                    constraints: const BoxConstraints(),
                                                    padding: EdgeInsets.zero,
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Second Card - Team Details
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.teal.withOpacity(0.7), Colors.teal.withOpacity(0.9)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      child: const Icon(Icons.group, size: 20, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Team ${userData['teamName'] ?? 'Information'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Code: ${userData['teamCode'] ?? 'N/A'}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Preferred Companies
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Preferred Companies',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (userData['preferredCompanies'] != null && (userData['preferredCompanies'] as List).isNotEmpty)
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            ...(userData['preferredCompanies'] as List).map((company) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                company.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            )).toList(),
                                          ],
                                        )
                                      else
                                        Text(
                                          'No preferred companies selected',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Third Card - Statistics
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.deepPurple.withOpacity(0.7), Colors.deepPurple.withOpacity(0.9)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      child: const Icon(Icons.bar_chart, size: 18, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Activity Statistics',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Your daily activity summary',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildUserStat('Visits', (stats['visits'] ?? 0).toString()),
                                          _buildUserStat('Uploads', (stats['uploads'] ?? 0).toString()),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Row(
                                      //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      //   children: [
                                      //     Column(
                                      //       children: [
                                      //         Text(
                                      //           '${_todayDistance.toStringAsFixed(1)} km',
                                      //           style: const TextStyle(
                                      //             color: Colors.white,
                                      //             fontSize: 14,
                                      //             fontWeight: FontWeight.bold,
                                      //           ),
                                      //         ),
                                      //         Row(
                                      //           children: [
                                      //             Text(
                                      //               'Today',
                                      //               style: TextStyle(
                                      //                 color: Colors.white.withOpacity(0.7),
                                      //                 fontSize: 10,
                                      //               ),
                                      //             ),
                                      //             const SizedBox(width: 2),
                                      //             Icon(
                                      //               Icons.directions_car,
                                      //               color: Colors.white.withOpacity(0.7),
                                      //               size: 8,
                                      //             ),
                                      //           ],
                                      //         ),
                                      //         Text(
                                      //           'Total: ${(stats['totalDistance'] ?? 0).toStringAsFixed(1)} km',
                                      //           style: TextStyle(
                                      //             color: Colors.white.withOpacity(0.5),
                                      //             fontSize: 8,
                                      //           ),
                                      //         ),
                                      //       ],
                                      //     ),
                                      //   ],
                                      // ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Fourth Card - Ads
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.withOpacity(0.7), Colors.orange.withOpacity(0.9)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      child: const Icon(Icons.campaign, size: 18, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Special Offer',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Limited time promotion',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      image: const DecorationImage(
                                        image: NetworkImage('https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT6S46DNdLXGnF9MaHKWKx4JRhArFU-Jmxg6g&s'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Add page indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index 
                              ? const Color(0xFF35C2C1)
                              : Colors.grey.withOpacity(0.3),
                        ),
                      )),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // First row of quick actions
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  context,
                                  'Map',
                                  '',
                                  Icons.location_on,
                                  const Color(0xFF4A6FFF),
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionCard(
                                  context,
                                  'Search',
                                  '',
                                  Icons.search,
                                  const Color(0xFF35C2C1),
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Second row of quick actions
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  context,
                                  'Add Pump',
                                  '',
                                  Icons.add_location,
                                  const Color(0xFFF9746D),
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const AddPetrolPumpScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionCard(
                                  context,
                                  'Nearest',
                                  '',
                                  Icons.near_me,
                                  const Color(0xFF8E44AD),
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const NearestPetrolPumpsScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Advertisement Slider
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Sponsored',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Ad',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: _buildAdSlider(),
                          ),
                        ],
                      ),
                    ),
                    
                    // Nearest Petrol Pumps Section
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Nearest Petrol Pumps',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const NearestPetrolPumpsScreen()),
                                  );
                                },
                                child: const Text(
                                  'View All',
                                  style: TextStyle(
                                    color: Color(0xFF35C2C1),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _isLoadingNearbyPumps
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(color: Color(0xFF35C2C1)),
                                  ),
                                )
                              : _nearbyPetrolPumps.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.location_off, size: 36, color: Colors.grey[400]),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No petrol pumps found nearby',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              if (_currentPosition != null) {
                                                _fetchNearbyPetrolPumps(
                                                  _currentPosition!.latitude,
                                                  _currentPosition!.longitude,
                                                );
                                              } else {
                                                _getCurrentLocation();
                                              }
                                            },
                                            icon: const Icon(Icons.refresh, size: 16),
                                            label: const Text('Refresh'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF35C2C1),
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: 320, // Fixed height for the list view
                                    child: _buildNearestPetrolPumpsList(),
                                  ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
          // Map View with options
          _buildMapSelectionView(),
          // Search View
          const SearchPetrolPumpsScreen(),
          // Profile View
          _isLoadingUserData 
          ? const Center(child: CircularProgressIndicator())
          : _buildProfileView(_userData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NearestPetrolPumpsScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF35C2C1),
        heroTag: 'homeScreenFAB',
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showFloatingActionButton: true,
      ),
    );
  }

  Widget _buildMapSelectionView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choose Map View',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select which map view you want to use:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            // Google Maps Option
            Card(
              elevation: 2,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map, color: Colors.blue),
                ),
                title: const Text(
                  'Google Maps',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Traditional Google Maps view with satellite imagery'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // OpenStreetMap Option
            Card(
              elevation: 2,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined, color: Colors.green),
                ),
                title: const Text(
                  'OpenStreetMap',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Open source map with detailed street information'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Both maps show the same petrol pump locations from your database.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _selectedIndex == index ? const Color(0xFF35C2C1) : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: _selectedIndex == index ? const Color(0xFF35C2C1) : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView(Map<String, dynamic> userData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.black.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Color(0xFF35C2C1), size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  userData['mobile'] ?? 'No mobile number',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ProfileCompletionIndicator(
                  completionPercentage: userData['profileCompletion'].toDouble(),
                  size: 60,
                  strokeWidth: 4,
                  progressColor: Colors.white,
                  backgroundColor: Colors.white,
                  percentageStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notice about Profile Screen
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF35C2C1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF35C2C1).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF35C2C1)),
                const SizedBox(width: 12),
                Expanded(
                  child: const Text(
                    'Please use the Edit Profile button to view and modify your complete profile details.',
                    style: TextStyle(color: Color(0xFF35C2C1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account Actions section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(Icons.logout, 'Logout', () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _signOut();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                }, iconColor: Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {
    bool isHighlighted = false,
    bool showCopyButton = false,
    bool showBadge = false,
    bool showIcon = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const Spacer(),
        if (showBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        if (showCopyButton) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Colors.white),
            onPressed: () {
              // TODO: Implement copy functionality
            },
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
        if (showIcon) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ],
      ],
    );
  }

  Widget _buildTeamStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF35C2C1).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFF35C2C1),
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF35C2C1),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF35C2C1).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF35C2C1)),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap, {Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: iconColor,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        height: 100, // Reduced height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                icon,
                size: 80, // Reduced size
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18, // Slightly smaller font
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDistanceStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
    bool hasNew = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF35C2C1).withOpacity(0.1) 
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon, 
          color: isActive ? const Color(0xFF35C2C1) : Colors.grey[600],
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          color: isActive ? Colors.black : Colors.black87,
        ),
      ),
      trailing: hasNew 
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '2',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            )
          : null,
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }

  // Add this method to the class
  Widget _buildNavButton(String label, int pageIndex) {
    Color buttonColor;
    if (pageIndex == _currentPage) {
      switch (pageIndex) {
        case 0:
          buttonColor = Colors.teal.withOpacity(0.7);
          break;
        case 1:
          buttonColor = Colors.teal.withOpacity(0.7);
          break;
        case 2:
          buttonColor = Colors.deepPurple.withOpacity(0.7);
          break;
        default:
          buttonColor = Colors.grey.withOpacity(0.7);
      }
    } else {
      buttonColor = Colors.grey.withOpacity(0.3);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentPage = pageIndex;
        });
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Increased padding
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(20), // Increased border radius
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15, // Increased font size
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Load user data from custom auth service
  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingUserData = true;
    });
    
    try {
      final userData = await _authService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoadingUserData = false;
        });
        print('Loaded user data: $_userData');
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  // Update the signOut method to use CustomAuthService
  void _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  // Build advertisement slider
  Widget _buildAdSlider() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            itemCount: adImages.length,
            controller: _adPageController,
            onPageChanged: (index) {
              setState(() {
                _currentAdPage = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    adImages[index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFF35C2C1),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.error_outline, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(adImages.length, (index) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentAdPage == index 
                  ? const Color(0xFF35C2C1)
                  : Colors.grey.withOpacity(0.3),
            ),
          )),
        ),
      ],
    );
  }

  void _startAdTimer() {
    _adTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        if (_currentAdPage < adImages.length - 1) {
          _currentAdPage++;
        } else {
          _currentAdPage = 0;
        }
        
        if (_adPageController!.hasClients) {
          _adPageController!.animateToPage(
            _currentAdPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeIn,
          );
        }
      }
    );
  }

  // Add this method to launch Google Maps navigation
  void _launchMapsUrl(double latitude, double longitude) async {
    final currentLat = _currentPosition?.latitude ?? 0;
    final currentLng = _currentPosition?.longitude ?? 0;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$currentLat,$currentLng&destination=$latitude,$longitude&travelmode=driving');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Widget _buildNearestPetrolPumpsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: _nearbyPetrolPumps.length,
      itemBuilder: (context, index) {
        final pump = _nearbyPetrolPumps[index];
        
        // Calculate distance text
        String distanceText = '';
        if (_currentPosition != null) {
          final distanceInKm = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            pump.latitude,
            pump.longitude,
          ) / 1000; // Convert to km
          
          if (distanceInKm < 1) {
            distanceText = '${(distanceInKm * 1000).toStringAsFixed(0)}m';
          } else {
            distanceText = '${distanceInKm.toStringAsFixed(1)}km';
          }
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCompanyColor(pump.coClDo).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.local_gas_station,
                  color: _getCompanyColor(pump.coClDo),
                  size: 20,
                ),
              ),
            ),
            title: Text(
              pump.customerName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              pump.addressLine1,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distanceText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF35C2C1),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.directions,
                  color: Colors.blue,
                  size: 16,
                ),
              ],
            ),
            onTap: () {
              // Navigate to Google Maps with directions
              _launchMapsUrl(
                pump.latitude,
                pump.longitude,
              );
            },
          ),
        );
      },
    );
  }
  
  Color _getCompanyColor(String company) {
    if (company.contains('IOCL')) {
      return Colors.blue;
    } else if (company.contains('HPCL')) {
      return Colors.orange;
    } else if (company.contains('BPCL')) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }
}