import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../services/custom_auth_service.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({Key? key}) : super(key: key);

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedCompanyType;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _companyTypes = [
    'Petrol Pump Owner',
    'Contractor',
    'Distributor',
    'Other'
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CustomAuthService _authService = CustomAuthService();

  Future<String> _generateUniqueTeamCode() async {
    String code;
    bool isUnique = false;
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    do {
      code = List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
      final doc = await _firestore.collection('teams').doc(code).get();
      isUnique = !doc.exists;
    } while (!isUnique);
    return code;
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) throw 'User not logged in.';
      
      final userDoc = await _firestore.collection('user_data').doc(userId).get();
      if (!userDoc.exists) throw 'User data not found.';
      
      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['teamCode'] != null && userData['teamCode'].toString().isNotEmpty) {
        throw 'You are already in a team. Leave your current team to create a new one.';
      }
      
      final teamCode = await _generateUniqueTeamCode();
      
      // Create team document
      await _firestore.collection('teams').doc(teamCode).set({
        'teamCode': teamCode,
        'teamName': _companyNameController.text.trim(),
        'companyType': _selectedCompanyType,
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'ownerId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'memberCount': 1,
        'activeMembers': 1,
        'pendingRequests': 0,
        'members': [userId], // Add the user to the members list
        'teamStats': {
          'totalVisits': 0,
          'totalUploads': 0,
          'totalDistance': 0,
          'totalFuelConsumption': 0,
        },
      });
      
      // Update user document
      await _firestore.collection('user_data').doc(userId).update({
        'teamCode': teamCode,
        'teamName': _companyNameController.text.trim(),
        'isTeamOwner': true,
        'userType': 'leader', // Use consistent userType
        'teamMemberStatus': 'active', // Set the user as an active member
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Check if user is allowed to create a team
    _checkUserPermission();
  }

  Future<void> _checkUserPermission() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You need to be logged in to create a team'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      final userDoc = await _firestore.collection('user_data').doc(userId).get();
      if (!userDoc.exists) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User data not found'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final userType = userData['userType'];
      
      // Only leader can create team
      if (userType != 'leader') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only organization accounts can create teams'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Email validation regex pattern
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Team',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading ? 
        const Center(child: CircularProgressIndicator(color: Color(0xFF35C2C1))) :
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.grey.shade100],
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.groups,
                              size: 50,
                              color: Color(0xFF35C2C1),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Team Information',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your organization team',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Form fields
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _companyNameController,
                              decoration: InputDecoration(
                                labelText: 'Company/Contractor Name',
                                hintText: 'Enter your company name',
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
                                prefixIcon: const Icon(Icons.business, color: Color(0xFF35C2C1)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter company name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            
                            DropdownButtonFormField<String>(
                              value: _selectedCompanyType,
                              decoration: InputDecoration(
                                labelText: 'Company Type',
                                hintText: 'Select your company type',
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
                                prefixIcon: const Icon(Icons.category, color: Color(0xFF35C2C1)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _companyTypes.map((String type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCompanyType = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select company type';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            
                            TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'Address',
                                hintText: 'Enter company address',
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
                                prefixIcon: const Icon(Icons.location_on, color: Color(0xFF35C2C1)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: 'Enter 10-digit phone number',
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
                                prefixIcon: const Icon(Icons.phone, color: Color(0xFF35C2C1)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter phone number';
                                }
                                if (value.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                                  return 'Please enter a valid 10-digit phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter company email',
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
                                prefixIcon: const Icon(Icons.email, color: Color(0xFF35C2C1)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter email';
                                }
                                if (!_isValidEmail(value)) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 30),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createTeam,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF35C2C1),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: const Color(0xFF35C2C1).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.group_add, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'Create Team',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
} 