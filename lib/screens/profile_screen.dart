import 'package:flutter/material.dart';
import '../widgets/profile_completion_indicator.dart';
import '../widgets/bottom_navigation_bar_widget.dart';
import '../widgets/app_drawer.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../services/custom_auth_service.dart';
import 'login_screen.dart';
import 'openstreet_map_screen.dart';
import 'search_petrol_pumps_screen.dart';
import 'nearest_petrol_pumps_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final UserService _userService = UserService();
  final CustomAuthService _authService = CustomAuthService();
  
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get user data from CustomAuthService
      final userData = await _authService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEditProfileModal(Map<String, dynamic> userData) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController firstNameController = TextEditingController(text: userData['firstName'] ?? '');
    final TextEditingController lastNameController = TextEditingController(text: userData['lastName'] ?? '');
    final TextEditingController dobController = TextEditingController(text: userData['dob'] ?? '');
    final TextEditingController addressController = TextEditingController(text: userData['address'] ?? '');
    final TextEditingController aadharController = TextEditingController(text: userData['aadharNo'] ?? '');
    final TextEditingController mobileController = TextEditingController(text: userData['mobile'] ?? '');
    
    // Convert to Set to remove duplicates, then back to List
    List<String> oilCompanies = userData['preferredCompanies'] != null 
        ? List<String>.from(Set<String>.from(userData['preferredCompanies'] as List))
        : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dobController,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          suffixIcon: Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: aadharController,
                        decoration: InputDecoration(
                          labelText: 'Aadhar No',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: mobileController,
                        decoration: InputDecoration(
                          labelText: 'Mobile No',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Preferred Oil Companies', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['IOCL', 'HPCL', 'BPCL'].map((company) {
                          final isSelected = oilCompanies.contains(company);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  oilCompanies.remove(company);
                                } else {
                                  oilCompanies.add(company);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF35C2C1) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                company,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final userId = await _authService.getCurrentUserId();
                              if (userId == null) return;
                              final data = {
                                'firstName': firstNameController.text.trim(),
                                'lastName': lastNameController.text.trim(),
                                'dob': dobController.text.trim(),
                                'address': addressController.text.trim(),
                                'aadharNo': aadharController.text.trim(),
                                'mobile': mobileController.text.trim(),
                                'preferredCompanies': oilCompanies,
                              };
                              await _authService.updateUserProfile(userId, data);
                              
                              // Refresh user data immediately
                              final updatedUserData = await _authService.getCurrentUserData();
                              if (mounted) {
                                setState(() {
                                  _userData = updatedUserData;
                                });
                              }
                              
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully!'),
                                  backgroundColor: Color(0xFF35C2C1),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF35C2C1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  double _calculateProfileCompletion(Map<String, dynamic> userData) {
    int totalFields = 6;
    int completedFields = 0;
    if (userData['firstName'] != null && userData['firstName'].toString().isNotEmpty) completedFields++;
    if (userData['lastName'] != null && userData['lastName'].toString().isNotEmpty) completedFields++;
    if (userData['mobile'] != null && userData['mobile'].toString().isNotEmpty) completedFields++;
    if (userData['dob'] != null && userData['dob'].toString().isNotEmpty) completedFields++;
    if (userData['address'] != null && userData['address'].toString().isNotEmpty) completedFields++;
    if (userData['aadharNo'] != null && userData['aadharNo'].toString().isNotEmpty) completedFields++;
    return (completedFields / totalFields) * 100;
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const AppDrawer(currentScreen: 'profile'),
      appBar: AppBar(
        title: const Text(
          'Profile',
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
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
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
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _databaseService.getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF35C2C1)));
          }
          final userData = snapshot.data!;
          final completionPercentage = _calculateProfileCompletion(userData);
          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF35C2C1), const Color(0xFF35C2C1).withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              backgroundImage: userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty
                                ? NetworkImage(userData['profileImage'])
                                : null,
                              child: (userData['profileImage'] == null || userData['profileImage'].toString().isEmpty)
                                ? const Icon(Icons.person, size: 50, color: Colors.white)
                                : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile photo upload will be available in the next update!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.camera_alt, color: Color(0xFF35C2C1), size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "${userData["firstName"] ?? ''} ${userData["lastName"] ?? ''}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        userData["mobile"] ?? 'No mobile number',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          userData['userType']?.toString().replaceAll('UserType.', '') ?? 'User',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Profile Completion',
                                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${completionPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: completionPercentage / 100,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              color: Colors.white,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showEditProfileModal(userData),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF35C2C1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Personal Information
                _buildSectionCard(
                  title: 'Personal Information',
                  icon: Icons.person,
                  children: [
                    _buildInfoItem('Date of Birth', userData["dob"] ?? 'Not provided', Icons.cake),
                    const Divider(height: 24),
                    _buildInfoItem('Address', userData["address"] ?? 'Not provided', Icons.location_on),
                    const Divider(height: 24),
                    _buildInfoItem('Aadhar No', userData["aadharNo"] ?? 'Not provided', Icons.badge),
                  ],
                ),

                // Team Information
                _buildSectionCard(
                  title: 'Team Information',
                  icon: Icons.group,
                  children: [
                    _buildInfoItem('Team Name', userData["teamName"] ?? 'Not in a team', Icons.groups),
                    if (userData["teamCode"] != null) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tag, size: 20, color: Color(0xFF35C2C1)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Team Code',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                ),
                                Text(
                                  userData["teamCode"] ?? '',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.copy, size: 20, color: Color(0xFF35C2C1)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Team code copied to clipboard!'))
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),
                    _buildInfoItem(
                      'Team Role', 
                      userData["userType"]?.toString().replaceAll('UserType.', '') ?? 'Member', 
                      Icons.badge
                    ),
                  ],
                ),

                // Preferred Oil Companies
                _buildSectionCard(
                  title: 'Preferred Oil Companies',
                  icon: Icons.local_gas_station,
                  children: [
                    if ((userData["preferredCompanies"] as List?)?.isNotEmpty == true)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (userData["preferredCompanies"] as List).map<Widget>((company) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF35C2C1).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_gas_station, size: 16, color: Color(0xFF35C2C1)),
                                const SizedBox(width: 6),
                                Text(
                                  company,
                                  style: const TextStyle(color: Color(0xFF35C2C1), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.info_outline, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No preferred companies selected',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showEditProfileModal(userData),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Companies'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF35C2C1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Account actions
                _buildSectionCard(
                  title: 'Account Actions',
                  icon: Icons.manage_accounts,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout, color: Colors.red, size: 20),
                      ),
                      title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                      onTap: _signOut,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          );
        },
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
        currentIndex: 4, // Profile index
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
              // Already on profile screen, do nothing
              break;
          }
        },
        showFloatingActionButton: true,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF35C2C1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF35C2C1), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF35C2C1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF35C2C1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 