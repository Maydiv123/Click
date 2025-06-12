import 'package:flutter/material.dart';
import '../widgets/profile_completion_indicator.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _showEditProfileModal(Map<String, dynamic> userData) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController firstNameController = TextEditingController(text: userData['firstName'] ?? '');
    final TextEditingController lastNameController = TextEditingController(text: userData['lastName'] ?? '');
    final TextEditingController dobController = TextEditingController(text: userData['dob'] ?? '');
    final TextEditingController addressController = TextEditingController(text: userData['address'] ?? '');
    final TextEditingController aadharController = TextEditingController(text: userData['aadharNo'] ?? '');
    final TextEditingController mobileController = TextEditingController(text: userData['mobile'] ?? '');
    List<String> oilCompanies = List<String>.from(userData['preferredCompanies'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                    decoration: const InputDecoration(labelText: 'First Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dobController,
                    decoration: const InputDecoration(labelText: 'Date of Birth'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: aadharController,
                    decoration: const InputDecoration(labelText: 'Aadhar No'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: mobileController,
                    decoration: const InputDecoration(labelText: 'Mobile No'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Preferred Oil Companies', style: TextStyle(fontWeight: FontWeight.w500)),
                  Wrap(
                    spacing: 8,
                    children: ['IOCL', 'HPCL', 'BPCL'].map((company) {
                      return FilterChip(
                        label: Text(company),
                        selected: oilCompanies.contains(company),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              oilCompanies.add(company);
                            } else {
                              oilCompanies.remove(company);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final uid = _auth.currentUser?.uid;
                          if (uid == null) return;
                          final data = {
                            'firstName': firstNameController.text.trim(),
                            'lastName': lastNameController.text.trim(),
                            'dob': dobController.text.trim(),
                            'address': addressController.text.trim(),
                            'aadharNo': aadharController.text.trim(),
                            'mobile': mobileController.text.trim(),
                            'preferredCompanies': oilCompanies,
                          };
                          await _userService.updateUserDocument(uid, data);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF35C2C1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _databaseService.getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty
                          ? NetworkImage(userData['profileImage'])
                          : null,
                        child: (userData['profileImage'] == null || userData['profileImage'].toString().isEmpty)
                          ? const Icon(Icons.person, size: 50, color: Colors.grey)
                          : null,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "${userData["firstName"] ?? ''} ${userData["lastName"] ?? ''}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        userData["mobile"] ?? 'No mobile number',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ProfileCompletionIndicator(
                        completionPercentage: completionPercentage,
                        size: 70,
                        strokeWidth: 6,
                        progressColor: const Color(0xFF35C2C1),
                        percentageStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF35C2C1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: completionPercentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF35C2C1)),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Profile Completion: ${completionPercentage.toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showEditProfileModal(userData),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
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
                const SizedBox(height: 16),
                // Profile Details
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInfoRow('Date of Birth', userData["dob"] ?? ''),
                      _buildInfoRow('Address', userData["address"] ?? ''),
                      const SizedBox(height: 20),
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInfoRow('Mobile No', userData["mobile"] ?? ''),
                      _buildInfoRow('Aadhar No', userData["aadharNo"] ?? ''),
                      const SizedBox(height: 20),
                      const Text(
                        'Associated Oil Companies',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 10,
                        children: (userData["preferredCompanies"] as List? ?? []).map<Widget>((company) {
                          return Chip(
                            label: Text(company),
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            labelStyle: const TextStyle(color: Colors.blue),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 