import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../services/custom_auth_service.dart';
import '../widgets/profile_completion_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/openstreet_map_screen.dart';
import '../screens/search_petrol_pumps_screen.dart';
import '../screens/add_petrol_pump_screen.dart';
import '../screens/camera_screen.dart';
import '../screens/location_history_screen.dart';
import '../screens/create_team_screen.dart';
import '../screens/join_team_screen.dart';
import '../screens/login_screen.dart';
import '../screens/team_details_screen.dart';

class AppDrawer extends StatelessWidget {
  final String currentScreen;
  
  const AppDrawer({
    Key? key,
    required this.currentScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DatabaseService _databaseService = DatabaseService();
    final UserService _userService = UserService();
    final FirebaseAuth _auth = FirebaseAuth.instance;

    return StreamBuilder<Map<String, dynamic>>(
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
                                  userData: userData,
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
                          'TEAM',
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
                        'SERVICES',
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
                        if (currentScreen != 'home') {
                          Navigator.pushReplacementNamed(context, '/home');
                        }
                      },
                      isActive: currentScreen == 'home',
                    ),
                    
                    _buildDrawerItem(
                      icon: Icons.map,
                      title: 'Map',
                      onTap: () {
                        Navigator.pop(context);
                        if (currentScreen != 'map') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
                          );
                        }
                      },
                      isActive: currentScreen == 'map',
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
                        if (currentScreen != 'search') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
                          );
                        }
                      },
                      isActive: currentScreen == 'search',
                    ),
                    
                    // _buildDrawerItem(
                    //   icon: Icons.history,
                    //   title: 'Location History',
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(builder: (context) => const LocationHistoryScreen()),
                    //     );
                    //   },
                    // ),
                    
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
                        'COMING SOON',
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
                  onPressed: () async {
                    try {
                      final authService = CustomAuthService();
                      await authService.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing out: ${e.toString()}')),
                        );
                      }
                    }
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
    );
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