import 'package:flutter/material.dart';
import 'dart:async';
import 'map_screen.dart';
import 'openstreet_map_screen.dart';
import 'camera_screen.dart';
import 'search_petrol_pumps_screen.dart';
import 'add_petrol_pump_screen.dart';
import '../widgets/profile_completion_indicator.dart';
import 'create_team_screen.dart';
import 'join_team_screen.dart';
import 'location_history_screen.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final DatabaseService _databaseService = DatabaseService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchTodayDistance();
    
    // Set up periodic location updates (every 5 minutes)
    _locationTimer = Timer.periodic(
      const Duration(minutes: 5), 
      (timer) => _getCurrentLocation()
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
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

  // Request location permission and get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _locationMessage = 'Fetching location...';
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationMessage = 'Location permission denied';
            _isLocationLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationMessage = 'Location permissions permanently denied';
          _isLocationLoading = false;
        });
        
        // Show dialog to open app settings
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text('This app needs location permission to show your current location. Please enable it in app settings.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                ),
              ],
            ),
          );
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationMessage = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          _isLocationLoading = false;
        });
        
        // Save location to user's database entry
        try {
          await _databaseService.updateUserLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now()
          );
          
          // Refresh distance data after location update
          await _fetchTodayDistance();
        } catch (e) {
          print('Error saving location: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationMessage = 'Error getting location: $e';
          _isLocationLoading = false;
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
    final currentUserId = _auth.currentUser?.uid;
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
      await _userService.removeTeamMember(teamCode, userIdToUse);
      
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      drawer: StreamBuilder<Map<String, dynamic>>(
        stream: _databaseService.getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Drawer();
          }
          final userData = snapshot.data!;
          final completionPercentage = _calculateProfileCompletion(userData);
          final bool inTeam = userData['teamCode'] != null && userData['teamCode'].toString().isNotEmpty;
          final String userId = userData['uid'] ?? '';

          return Drawer(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      // Gradient Header with User Profile
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF35C2C1), const Color(0xFF35C2C1).withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, '/profile');
                                  },
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 32,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        child: const Icon(Icons.person, size: 32, color: Colors.white),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.edit, color: Color(0xFF35C2C1), size: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
                                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        userData['mobile'] ?? 'No mobile number',
                                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          userData['userType']?.toString().replaceAll('UserType.', '') ?? 'User',
                                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Profile Completion Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Profile Completion: ${completionPercentage.toStringAsFixed(0)}%',
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                          const Spacer(),
                                          InkWell(
                                            onTap: () {
                                              Navigator.pop(context);
                                              Navigator.pushNamed(context, '/profile');
                                            },
                                            child: const Text(
                                              'Complete',
                                              style: TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.underline),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: completionPercentage / 100,
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                        color: Colors.white,
                                        minHeight: 6,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Team Information Section
                      if (inTeam) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                          child: Text(
                            'TEAM',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          color: const Color(0xFF35C2C1).withOpacity(0.1),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              // Navigate to team details page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TeamDetailsScreen(
                                    teamCode: userData['teamCode'] ?? '',
                                    teamName: userData['teamName'] ?? 'Your Team',
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF35C2C1).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.groups, color: Color(0xFF35C2C1), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userData['teamName'] ?? 'Your Team',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: [
                                            const Text('Code: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            Text(
                                              userData['teamCode'] ?? '',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                          child: Text(
                            'TEAM OPTIONS',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.group_add, color: Color(0xFF35C2C1), size: 20),
                          ),
                          title: const Text('Create Team', style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: const Text('Generate a new team code', style: TextStyle(fontSize: 12)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateTeamScreen()),
                            );
                          },
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.group, color: Color(0xFF35C2C1), size: 20),
                          ),
                          title: const Text('Join Team', style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: const Text('Enter existing team code', style: TextStyle(fontSize: 12)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const JoinTeamScreen()),
                            );
                          },
                        ),
                      ],
                      
                      const Divider(height: 24),
                      
                      // Main Navigation
                      const Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          'NAVIGATION',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        onTap: () {
                          Navigator.pop(context);
                        },
                        isActive: true,
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.map,
                        title: 'Map',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
                          );
                        },
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.add_location,
                        title: 'Add Petrol Pump',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddPetrolPumpScreen()),
                          );
                        },
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.search,
                        title: 'Search Pumps',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
                          );
                        },
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.history,
                        title: 'Location History',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LocationHistoryScreen()),
                          );
                        },
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.camera_alt,
                        title: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CameraScreen()),
                          );
                        },
                      ),
                      
                      const Divider(height: 24),
                      
                      // Other Options
                      const Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          'MORE',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.chat_bubble_outline,
                        title: 'Team Chat',
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Team Chat will be available in the next update!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        hasNew: true,
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.local_offer_outlined,
                        title: 'Special Offers',
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Special Offers will be available in the next update!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.support_agent,
                        title: 'Support',
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Support features will be available in the next update!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      
                      _buildDrawerItem(
                        icon: Icons.settings,
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings will be available in the next update!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Logout Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/welcome');
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.red.withOpacity(0.3)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home/Dashboard View
          StreamBuilder<Map<String, dynamic>>(
            stream: _databaseService.getUserData(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = userSnapshot.data!;
              final completionPercentage = _calculateProfileCompletion(userData);
              final stats = userData['stats'] as Map<String, dynamic>? ?? {};

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Status Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      height: 200,
                      child: PageView(
                        physics: const BouncingScrollPhysics(),
                        pageSnapping: true,
                        padEnds: false,
                        controller: PageController(viewportFraction: 0.85),
                        children: [
                          // First Card - User Details
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.purple.withOpacity(0.7), Colors.purple.withOpacity(0.9)],
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
                                            'Last login: ${userData['lastLogin'] != null ? DateTime.fromMillisecondsSinceEpoch(userData['lastLogin'].millisecondsSinceEpoch).toString() : 'N/A'}',
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
                                      child: Column(
                                        children: [
                                          ProfileCompletionIndicator(
                                            completionPercentage: completionPercentage,
                                            size: 35,
                                            strokeWidth: 3,
                                            progressColor: Colors.white,
                                            backgroundColor: Colors.white,
                                            percentageStyle: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Profile",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
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
                                const SizedBox(height: 8),
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          shape: BoxShape.circle,
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
                            margin: const EdgeInsets.symmetric(horizontal: 10),
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
                                const Spacer(),
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          shape: BoxShape.circle,
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
                            margin: const EdgeInsets.symmetric(horizontal: 10),
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
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          Column(
                                            children: [
                                              Text(
                                                '${_todayDistance.toStringAsFixed(1)} km',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Today',
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.7),
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Icon(
                                                    Icons.directions_car,
                                                    color: Colors.white.withOpacity(0.7),
                                                    size: 8,
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                'Total: ${(stats['totalDistance'] ?? 0).toStringAsFixed(1)} km',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.5),
                                                  fontSize: 8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
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

                    // Daily Distance Summary - Commented out as requested
                    /*if (_todayDistance > 0)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
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
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.directions_car, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Today\'s Travel',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.history, size: 16),
                                  label: const Text('History'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LocationHistoryScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildDistanceStat(
                                  'Distance',
                                  '${_todayDistance.toStringAsFixed(1)} km',
                                  Icons.straighten,
                                  Colors.blue,
                                ),
                                _buildDistanceStat(
                                  'Checkpoints',
                                  '${(_todayDistance / 0.5).ceil()}',
                                  Icons.location_on,
                                  Colors.red,
                                ),
                                _buildDistanceStat(
                                  'Avg. Speed',
                                  '${(_todayDistance * 5).toStringAsFixed(1)} km/h',
                                  Icons.speed,
                                  Colors.amber,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),*/

                    // Quick Actions section - title and view all button commented out
                    /*Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              // TODO: Show all actions
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),*/
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: MediaQuery.of(context).size.width - 32,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildActionCard(
                              context,
                              'View Map',
                              Icons.map,
                              Colors.blue,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            _buildActionCard(
                              context,
                              'Search',
                              Icons.search,
                              Colors.green,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            _buildActionCard(
                              context,
                              'Add Pump',
                              Icons.add_location,
                              Colors.orange,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AddPetrolPumpScreen()),
                                );
                              },
                            ),
                            // Ensures there's space at the end for better UX
                            const SizedBox(width: 50),
                          ],
                        ),
                      ),
                    ),

                    // Today's Summary - Commented out as functionality is not working
                    /*Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Summary",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Visits',
                                  stats['visits']?.toString() ?? '0',
                                  Icons.location_on,
                                  Colors.blue,
                                  staticData['todayVisits'].isNotEmpty
                                      ? staticData['todayVisits'].map((v) => v['fuel']).join(', ')
                                      : 'No visits today',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Tasks',
                                  staticData['upcomingTasks'].length.toString(),
                                  Icons.task,
                                  Colors.orange,
                                  staticData['upcomingTasks'].isNotEmpty
                                      ? 'Next: ${staticData['upcomingTasks'][0]['time']}'
                                      : 'No tasks',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),*/

                    // Team Information Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.withOpacity(0.7), Colors.teal.withOpacity(0.9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.group, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Team Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  Icons.group,
                                  'Team Name',
                                  userData['teamName'] ?? 'No Team',
                                  isHighlighted: true,
                                ),
                                const Divider(height: 16, color: Colors.white24),
                                _buildInfoRow(
                                  Icons.tag,
                                  'Team Code',
                                  userData['teamCode'] ?? 'N/A',
                                  showCopyButton: true,
                                ),
                                const Divider(height: 16, color: Colors.white24),
                                _buildInfoRow(
                                  Icons.people,
                                  'Team Role',
                                  userData['userType']?.toString().replaceAll('UserType.', '') ?? 'N/A',
                                  showBadge: true,
                                ),
                                const Divider(height: 16, color: Colors.white24),
                                _buildInfoRow(
                                  Icons.group_work,
                                  'Team Members',
                                  '${userData['teamMembers'] ?? 0} members',
                                  showIcon: true,
                                ),
                              ],
                            ),
                          ),
                          // Team Performance section commented out
                          /*const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Team Performance',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF35C2C1),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildTeamStat(
                                      'Total Visits',
                                      (stats['teamVisits'] ?? 0).toString(),
                                      Icons.location_on,
                                    ),
                                    _buildTeamStat(
                                      'Uploads',
                                      (stats['teamUploads'] ?? 0).toString(),
                                      Icons.upload,
                                    ),
                                    _buildTeamStat(
                                      'Rating',
                                      '${(stats['teamRating'] ?? 0.0).toStringAsFixed(1)}',
                                      Icons.star,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),*/
                        ],
                      ),
                    ),

                    // Most Visited Stations
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Most Visited Stations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: staticData['frequentVisits'].length,
                            itemBuilder: (context, index) {
                              final station = staticData['frequentVisits'][index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.local_gas_station, color: Colors.blue),
                                  ),
                                  title: Text(station['name']),
                                  subtitle: Text('${station['visits']} visits • Last: ${station['lastVisit']}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        station['rating'].toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    // TODO: Show station details
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Recent Activity
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: staticData['recentActivities'].length,
                            itemBuilder: (context, index) {
                              final activity = staticData['recentActivities'][index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF35C2C1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    activity['type'] == 'visit' 
                                        ? Icons.location_on 
                                        : activity['type'] == 'upload'
                                            ? Icons.upload
                                            : Icons.chat,
                                    color: const Color(0xFF35C2C1),
                                  ),
                                ),
                                title: Text(activity['location']),
                                subtitle: Text(activity['time']),
                                trailing: activity['type'] == 'visit'
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(activity['rating'].toString()),
                                        ],
                                      )
                                    : const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  // TODO: Show activity details
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Upcoming Tasks - Commented out as functionality is not working
                    /*Container(
                      margin: const EdgeInsets.all(16),
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
                            'Upcoming Tasks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: staticData['upcomingTasks'].length,
                            itemBuilder: (context, index) {
                              final task = staticData['upcomingTasks'][index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: task['type'] == 'meeting' 
                                        ? Colors.blue.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    task['type'] == 'meeting' ? Icons.event : Icons.task,
                                    color: task['type'] == 'meeting' ? Colors.blue : Colors.orange,
                                  ),
                                ),
                                title: Text(task['title']),
                                subtitle: Text(task['time']),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  // TODO: Show task details
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),*/
                  ],
                ),
              );
            },
          ),
          // Map View with options
          _buildMapSelectionView(),
          // Empty Container for Camera (since it's a FAB)
          Container(),
          // Search View
          const SearchPetrolPumpsScreen(),
          // Profile View
          StreamBuilder<Map<String, dynamic>>(
            stream: _databaseService.getUserData(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildProfileView(snapshot.data!);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraScreen()),
          );
        },
        backgroundColor: const Color(0xFF35C2C1),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.map_outlined, 'Map'),
              const SizedBox(width: 40), // Space for FAB
              _buildNavItem(3, Icons.search, 'Search'),
              _buildNavItem(4, Icons.person_outline, 'Profile'),
            ],
          ),
        ),
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Team Information
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
                  'Team Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.group, 'Team Name', userData['teamName'] ?? 'No Team'),
                const Divider(height: 16, color: Colors.white24),
                _buildInfoRow(Icons.tag, 'Team Code', userData['teamCode'] ?? 'N/A'),
                const Divider(height: 16, color: Colors.white24),
                _buildInfoRow(Icons.people, 'Team Role', userData['userType']?.toString().replaceAll('UserType.', '') ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Statistics
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
                  'Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Visits', userData['stats']['visits'].toString(), Icons.location_on),
                    _buildStatItem('Uploads', userData['stats']['uploads'].toString(), Icons.upload),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Settings
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
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(Icons.notifications_outlined, 'Notifications', () {}),
                _buildSettingItem(Icons.lock_outline, 'Privacy', () {}),
                _buildSettingItem(Icons.language, 'Language', () {}),
                _buildSettingItem(Icons.help_outline, 'Help & Support', () {}),
                _buildSettingItem(Icons.info_outline, 'About', () {}),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/welcome');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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

  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
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
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: (MediaQuery.of(context).size.width - 70) / 2,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
}

class TeamDetailsScreen extends StatelessWidget {
  final String teamCode;
  final String teamName;

  const TeamDetailsScreen({
    Key? key,
    required this.teamCode,
    required this.teamName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DatabaseService databaseService = DatabaseService();
    final UserService userService = UserService();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(teamName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: databaseService.getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF35C2C1), const Color(0xFF35C2C1).withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.groups, color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  teamName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.tag, color: Colors.white, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            teamCode,
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        // TODO: Copy to clipboard
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Team code copied to clipboard')),
                                        );
                                      },
                                      child: const Icon(Icons.copy, color: Colors.white, size: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Team Members Section
                const Text(
                  'Team Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3, // Placeholder count
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      // Placeholder member data
                      final memberName = index == 0 
                          ? '${userData['firstName'] ?? 'You'} ${userData['lastName'] ?? ''} (You)'
                          : 'Team Member ${index + 1}';
                      final memberRole = index == 0 
                          ? 'Owner' 
                          : 'Member';
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index == 0 
                              ? const Color(0xFF35C2C1).withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          child: Icon(
                            Icons.person,
                            color: index == 0 ? const Color(0xFF35C2C1) : Colors.grey,
                          ),
                        ),
                        title: Text(memberName),
                        subtitle: Text(memberRole),
                        trailing: index == 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF35C2C1).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Color(0xFF35C2C1),
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Team Settings Section
                const Text(
                  'Team Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF35C2C1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit, color: Color(0xFF35C2C1)),
                        ),
                        title: const Text('Edit Team Profile'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: Navigate to edit team profile screen
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF35C2C1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_add, color: Color(0xFF35C2C1)),
                        ),
                        title: const Text('Invite Members'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: Navigate to invite members screen
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.logout, color: Colors.red),
                        ),
                        title: const Text('Leave Team', style: TextStyle(color: Colors.red)),
                        onTap: () async {
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Leave Team'),
                              content: const Text('Are you sure you want to leave this team? This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    // Implement leave team functionality
                                    try {
                                      final userId = FirebaseAuth.instance.currentUser?.uid;
                                      if (userId != null) {
                                        await userService.removeTeamMember(teamCode, userId);
                                        Navigator.pop(context); // Go back to previous screen
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('You have left the team'))
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: ${e.toString()}'))
                                      );
                                    }
                                  },
                                  child: const Text('Leave', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}