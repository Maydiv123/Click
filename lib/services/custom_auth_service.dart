import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection reference for user authentication data
  final CollectionReference _userDataCollection = FirebaseFirestore.instance.collection('user_data');
  
  // Keys for SharedPreferences
  static const String _userIdKey = 'userId';
  static const String _userMobileKey = 'userMobile';
  static const String _userTypeKey = 'userType';
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userFirstNameKey = 'userFirstName';
  static const String _userLastNameKey = 'userLastName';

  // Register a new user
  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String mobile,
    required String password,
    required String userType,
    String? teamCode,
    String? teamName,
    List<String>? preferredCompanies,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _userDataCollection
          .where('mobile', isEqualTo: mobile)
          .get();

      if (existingUser.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'User with this mobile number already exists'
        };
      }

      // Create a unique userId
      final userId = _firestore.collection('user_data').doc().id;

      // Create user document
      Map<String, dynamic> userData = {
        'userId': userId,
        'firstName': firstName,
        'lastName': lastName,
        'mobile': mobile,
        'password': password, // Storing password as plain text as requested
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'profileCompletion': 0,
        'preferredCompanies': preferredCompanies ?? [],
        'stats': {
          'visits': 0,
          'uploads': 0,
          'teamChats': 0,
          'totalDistance': 0,
          'fuelConsumption': 0,
        },
      };

      // Add type-specific data
      if (userType == 'Team Member' && teamCode != null) {
        userData['teamCode'] = teamCode;
        userData['teamMemberStatus'] = 'pending'; // Default status
      } else if (userType == 'Team Leader' && teamName != null) {
        userData['teamName'] = teamName;
        
        // Create a new team
        final teamId = _firestore.collection('teams').doc().id;
        await _firestore.collection('teams').doc(teamId).set({
          'teamId': teamId,
          'teamName': teamName,
          'ownerId': userId,
          'ownerName': '$firstName $lastName',
          'ownerMobile': mobile,
          'createdAt': FieldValue.serverTimestamp(),
          'members': [],
        });
        
        userData['teamId'] = teamId;
      }

      // Save user data
      await _userDataCollection.doc(userId).set(userData);
      
      // Save user session
      await _saveUserSession(
        userId: userId,
        mobile: mobile,
        userType: userType, 
        firstName: firstName,
        lastName: lastName,
      );

      return {
        'success': true,
        'message': 'Registration successful',
        'userId': userId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed: ${e.toString()}'
      };
    }
  }

  // Login user
  Future<Map<String, dynamic>> loginUser({
    required String mobile,
    required String password,
  }) async {
    try {
      // Find user by mobile number
      final userQuery = await _userDataCollection
          .where('mobile', isEqualTo: mobile)
          .get();

      if (userQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No user found with this mobile number'
        };
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;

      // Check password
      if (userData['password'] != password) {
        return {
          'success': false,
          'message': 'Incorrect password'
        };
      }

      // Update last login timestamp
      await _userDataCollection.doc(userDoc.id).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Save user session
      await _saveUserSession(
        userId: userDoc.id,
        mobile: mobile,
        userType: userData['userType'],
        firstName: userData['firstName'],
        lastName: userData['lastName'],
      );

      return {
        'success': true,
        'message': 'Login successful',
        'userId': userDoc.id,
        'userData': userData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login failed: ${e.toString()}'
      };
    }
  }

  // Save user session in SharedPreferences
  Future<void> _saveUserSession({
    required String userId,
    required String mobile,
    required String userType,
    required String firstName,
    required String lastName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userMobileKey, mobile);
    await prefs.setString(_userTypeKey, userType);
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userFirstNameKey, firstName);
    await prefs.setString(_userLastNameKey, lastName);
  }

  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Get current user ID
  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get current user data
  Future<Map<String, dynamic>> getCurrentUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    
    if (userId == null) {
      return {};
    }
    
    try {
      final userDoc = await _userDataCollection.doc(userId).get();
      if (!userDoc.exists) {
        return {};
      }
      
      return userDoc.data() as Map<String, dynamic>;
    } catch (e) {
      print('Error getting current user data: ${e.toString()}');
      return {};
    }
  }

  // Sign out user
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Update user profile
  Future<Map<String, dynamic>> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _userDataCollection.doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return {
        'success': true,
        'message': 'Profile updated successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update profile: ${e.toString()}'
      };
    }
  }

  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final userDoc = await _userDataCollection.doc(userId).get();
      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User not found'
        };
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      if (userData['password'] != currentPassword) {
        return {
          'success': false,
          'message': 'Current password is incorrect'
        };
      }
      
      await _userDataCollection.doc(userId).update({
        'password': newPassword,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return {
        'success': true,
        'message': 'Password changed successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to change password: ${e.toString()}'
      };
    }
  }

  // Reset password using OTP (would need integration with SMS service)
  Future<Map<String, dynamic>> resetPassword(String mobile) async {
    // This would normally involve sending an OTP to the user's phone
    // and then verifying it before allowing password reset
    try {
      final userQuery = await _userDataCollection
          .where('mobile', isEqualTo: mobile)
          .get();

      if (userQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No user found with this mobile number'
        };
      }
      
      // This is a stub - in a real app, you would generate an OTP
      // and send it to the user's phone
      
      return {
        'success': true,
        'message': 'Password reset initiated'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to initiate password reset: ${e.toString()}'
      };
    }
  }
  
  // Verify OTP and set new password
  Future<Map<String, dynamic>> verifyOtpAndResetPassword({
    required String mobile,
    required String otp,
    required String newPassword,
  }) async {
    // This would normally verify the OTP and then reset the password
    try {
      final userQuery = await _userDataCollection
          .where('mobile', isEqualTo: mobile)
          .get();

      if (userQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No user found with this mobile number'
        };
      }

      final userDoc = userQuery.docs.first;
      
      // In a real app, you would verify the OTP here
      
      await _userDataCollection.doc(userDoc.id).update({
        'password': newPassword,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return {
        'success': true,
        'message': 'Password reset successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reset password: ${e.toString()}'
      };
    }
  }
} 