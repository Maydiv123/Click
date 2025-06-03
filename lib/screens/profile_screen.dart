import 'package:flutter/material.dart';
import '../widgets/profile_completion_indicator.dart';

class ProfileScreen extends StatelessWidget {
  // Dummy user data
  final Map<String, dynamic> userData = {
    "firstName": "John",
    "lastName": "Doe",
    "dob": "15/05/1990",
    "address": "123 Main Street, City, State, 12345",
    "aadharNo": "123456789012",
    "mobileNo": "9876543210",
    "teamCode": "TEAM123",
    "oilCompanies": ["IOCL", "HPCL"],
    "profileImage": "https://via.placeholder.com/150",
  };

  ProfileScreen({Key? key}) : super(key: key);

  double _calculateProfileCompletion(Map<String, dynamic> userData) {
    int totalFields = 7; // Total number of fields to check
    int completedFields = 0;

    // Check each field
    if (userData['firstName']?.isNotEmpty ?? false) completedFields++;
    if (userData['lastName']?.isNotEmpty ?? false) completedFields++;
    if (userData['dob']?.isNotEmpty ?? false) completedFields++;
    if (userData['address']?.isNotEmpty ?? false) completedFields++;
    if (userData['aadharNo']?.isNotEmpty ?? false) completedFields++;
    if (userData['mobileNo']?.isNotEmpty ?? false) completedFields++;
    if (userData['teamCode']?.isNotEmpty ?? false) completedFields++;

    return (completedFields / totalFields) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final double completionPercentage = _calculateProfileCompletion(userData);

    return Scaffold(
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                children: [
                  // Profile Image
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(userData["profileImage"]),
                  ),
                  const SizedBox(height: 15),
                  // Name
                  Text(
                    "${userData["firstName"]} ${userData["lastName"]}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Team Code
                  Text(
                    "Team Code: ${userData["teamCode"]}",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
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
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Profile Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
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
                  // Personal Information Section
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInfoRow('Date of Birth', userData["dob"]),
                  _buildInfoRow('Address', userData["address"]),
                  const SizedBox(height: 20),
                  
                  // Contact Information Section
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInfoRow('Mobile No', userData["mobileNo"]),
                  _buildInfoRow('Aadhar No', userData["aadharNo"]),
                  const SizedBox(height: 20),
                  
                  // Oil Companies Section
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
                    children: (userData["oilCompanies"] as List).map((company) {
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
            const SizedBox(height: 20),
            // Edit Profile Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement edit profile functionality
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
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